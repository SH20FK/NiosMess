import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:pulse_flutter/core/storage/hive_bootstrap.dart';
import 'package:pulse_flutter/core/utils/e2ee_file_crypto.dart';

class NiosgramDraftFile {
  const NiosgramDraftFile({
    required this.id,
    required this.name,
    this.durationMs,
  });
  final String id;
  final String name;
  final int? durationMs;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (durationMs != null) 'duration_ms': durationMs,
  };
}

class NiosgramPostDraft {
  const NiosgramPostDraft({
    this.text = '',
    this.poll,
    this.files = const <NiosgramDraftFile>[],
  });
  final String text;
  final Map<String, dynamic>? poll;
  final List<NiosgramDraftFile> files;

  Map<String, dynamic> toJson() => {
    'text': text,
    'poll': poll,
    'files': files.map((file) => file.toJson()).toList(),
  };

  factory NiosgramPostDraft.fromJson(Map<String, dynamic> data) {
    if (data['text'] is! String ||
        data['files'] is! List ||
        (data['poll'] != null && data['poll'] is! Map)) {
      throw const FormatException('POST_DRAFT_INVALID');
    }
    final files = <NiosgramDraftFile>[];
    for (final item in data['files'] as List) {
      if (item is! Map ||
          item['id'] is! String ||
          item['name'] is! String ||
          !RegExp(r'^[0-9a-f]{32}$').hasMatch(item['id'] as String)) {
        throw const FormatException('POST_DRAFT_FILE_INVALID');
      }
      final duration = item['duration_ms'];
      if (duration != null &&
          (duration is! int || duration <= 0 || duration > 10000)) {
        throw const FormatException('POST_DRAFT_DURATION_INVALID');
      }
      files.add(
        NiosgramDraftFile(
          id: item['id'] as String,
          name: item['name'] as String,
          durationMs: duration as int?,
        ),
      );
    }
    if (files.length > 5) {
      throw const FormatException('POST_DRAFT_TOO_MANY_FILES');
    }
    return NiosgramPostDraft(
      text: data['text'] as String,
      poll: data['poll'] == null
          ? null
          : Map<String, dynamic>.from(data['poll'] as Map),
      files: files,
    );
  }
}

/// Draft metadata lives in secure storage. Each media blob is AES-GCM encrypted
/// independently in a lazy Hive box; keystrokes never rewrite media blobs.
class NiosgramDraftStore {
  NiosgramDraftStore(this.accountId)
    : _generation = _generations[accountId] ?? 0;

  final int accountId;
  final int _generation;
  static const _storage = FlutterSecureStorage();
  static const _boxName = 'niosgram_draft_media_v1';
  static final _generations = <int, int>{};
  static final _tails = <int, Future<void>>{};
  String get _metaKey => 'niosgram.draft.v1.$accountId';
  String get _cryptoKey => 'niosgram.draft.key.v1.$accountId';
  String get _prefix => '$accountId:';
  bool get _valid => _generation == (_generations[accountId] ?? 0);

  Future<T> _serial<T>(Future<T> Function() operation) {
    final previous = _tails[accountId] ?? Future<void>.value();
    final result = previous.then((_) async {
      if (!_valid) throw StateError('POST_DRAFT_ACCOUNT_CLOSED');
      final value = await operation();
      if (!_valid) throw StateError('POST_DRAFT_ACCOUNT_CLOSED');
      return value;
    });
    _tails[accountId] = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<LazyBox<Uint8List>> _box() async {
    await HiveBootstrap.ensureInitialized();
    return Hive.openLazyBox<Uint8List>(_boxName);
  }

  Future<Uint8List> _key({bool create = false}) async {
    final raw = await _storage.read(key: _cryptoKey);
    if (raw != null) {
      final bytes = base64Decode(raw);
      if (bytes.length != 32) {
        throw const FormatException('POST_DRAFT_KEY_INVALID');
      }
      return bytes;
    }
    if (!create) throw StateError('POST_DRAFT_KEY_MISSING');
    final key = E2eeFileCrypto.generateFileKey();
    if (!_valid) throw StateError('POST_DRAFT_ACCOUNT_CLOSED');
    await _storage.write(key: _cryptoKey, value: base64Encode(key));
    return key;
  }

  Future<NiosgramPostDraft?> read() => _serial(() async {
    final raw = await _storage.read(key: _metaKey);
    if (raw == null) return null;
    final data = jsonDecode(raw);
    if (data is! Map) throw const FormatException('POST_DRAFT_INVALID');
    return NiosgramPostDraft.fromJson(Map<String, dynamic>.from(data));
  });

  Future<void> write(NiosgramPostDraft draft) => _serial(() async {
    await _storage.write(key: _metaKey, value: jsonEncode(draft.toJson()));
  });

  Future<NiosgramDraftFile> saveFile(
    String name,
    Uint8List bytes, {
    int? durationMs,
  }) => _serial(() async {
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final key = await _key(create: true);
    final ciphertext = await E2eeFileCrypto.encrypt(bytes, key);
    if (!_valid) throw StateError('POST_DRAFT_ACCOUNT_CLOSED');
    final box = await _box();
    await box.put('$_prefix$id', ciphertext);
    await box.flush();
    return NiosgramDraftFile(id: id, name: name, durationMs: durationMs);
  });

  Future<Uint8List> readFile(NiosgramDraftFile file) => _serial(() async {
    final box = await _box();
    final ciphertext = await box.get('$_prefix${file.id}');
    if (ciphertext == null) throw StateError('POST_DRAFT_FILE_MISSING');
    return E2eeFileCrypto.decrypt(ciphertext, await _key());
  });

  /// Call only after publishing or explicit discard, never on navigation.
  Future<void> clear() => _serial(() async {
    await _storage.delete(key: _metaKey);
    final box = await _box();
    final keys = box.keys
        .whereType<String>()
        .where((key) => key.startsWith(_prefix))
        .toList();
    await box.deleteAll(keys);
    await box.flush();
    await _storage.delete(key: _cryptoKey);
  });

  static Future<void> eraseAccount(int accountId) async {
    _generations[accountId] = (_generations[accountId] ?? 0) + 1;
    final previous = _tails[accountId] ?? Future<void>.value();
    final operation = previous.then((_) async {
      await _storage.delete(key: 'niosgram.draft.v1.$accountId');
      await _storage.delete(key: 'niosgram.draft.key.v1.$accountId');
      await HiveBootstrap.ensureInitialized();
      if (!await Hive.boxExists(_boxName)) return;
      final box = await Hive.openLazyBox<Uint8List>(_boxName);
      final prefix = '$accountId:';
      await box.deleteAll(
        box.keys
            .whereType<String>()
            .where((key) => key.startsWith(prefix))
            .toList(),
      );
      await box.flush();
    });
    _tails[accountId] = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    await operation;
  }
}
