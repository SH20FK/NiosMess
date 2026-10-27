import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart' as hashing;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pulse_flutter/core/utils/draft_storage.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_service.dart';

enum DraftMerge { unchanged, upload, download, conflict }

/// A three-way merge never silently discards concurrent edits.
DraftMerge decideDraftMerge(String base, String local, String remote) {
  if (local == remote) return DraftMerge.unchanged;
  if (local == base) return DraftMerge.download;
  if (remote == base) return DraftMerge.upload;
  return DraftMerge.conflict;
}

String _digest(String text) =>
    hashing.sha256.convert(utf8.encode(text)).toString();

class EncryptedDraftSync {
  EncryptedDraftSync({
    required this.userId,
    required this.storage,
    required this.crypto,
    FlutterSecureStorage? secure,
    Future<String?> Function(String key)? readMetadata,
    Future<void> Function(String key, String value)? writeMetadata,
  }) : secure = secure ?? const FlutterSecureStorage(),
       _readMetadata = readMetadata,
       _writeMetadata = writeMetadata {
    _instances.putIfAbsent(userId, () => {}).add(this);
  }

  static final _instances = <int, Set<EncryptedDraftSync>>{};
  static Future<void> shutdownAccount(int id) async {
    await Future.wait(
      (_instances[id]?.toList() ?? <EncryptedDraftSync>[]).map(
        (s) => s.close(),
      ),
    );
  }

  final int userId;
  final DraftStorage storage;
  final OrdinaryE2eeService crypto;
  final FlutterSecureStorage secure;
  final Future<String?> Function(String key)? _readMetadata;
  final Future<void> Function(String key, String value)? _writeMetadata;
  Timer? _poll, _debounce;
  StreamSubscription<void>? _subscription;
  Future<void>? _running;
  bool _closed = false;
  final Set<int> conflicts = {};
  final _conflictChanges = StreamController<void>.broadcast();
  Stream<void> get conflictChanges => _conflictChanges.stream;
  String get _key => 'draft.sync.v1.$userId';

  void start() {
    if (_subscription != null || _closed) return;
    _subscription = storage.changes.listen((_) => _schedule());
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _schedule());
    _schedule();
  }

  void _schedule() {
    if (_closed) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 1), () {
      unawaited(sync().catchError((Object _) {}));
    });
  }

  Future<void> sync() =>
      _running ??= _sync().whenComplete(() => _running = null);

  Future<void> _sync() async {
    if (_closed || storage.accountId != userId) return;
    final raw = await (_readMetadata?.call(_key) ?? secure.read(key: _key));
    if (_closed) return;
    final decoded = raw == null ? <String, dynamic>{} : jsonDecode(raw);
    if (decoded is! Map) throw const FormatException('Invalid draft metadata');
    final metadata = Map<String, dynamic>.from(decoded);
    final remoteRows = await crypto.encryptedDrafts();
    if (_closed) return;
    final remote = <int, Map<String, dynamic>>{};
    for (final row in remoteRows) {
      final id = row['chat_id'], revision = row['revision'];
      if (id is! int ||
          id <= 0 ||
          revision is! int ||
          revision <= 0 ||
          remote.containsKey(id)) {
        throw const FormatException('Invalid draft metadata');
      }
      remote[id] = row;
    }
    final local = await storage.asMap();
    final ids = <int>{
      ...local.keys,
      ...remote.keys,
      ...metadata.keys.map(int.tryParse).whereType<int>(),
    };
    for (final id in ids) {
      if (_closed) return;
      try {
        final saved = metadata['$id'];
        final base = saved is Map && saved['base_hash'] is String
            ? saved['base_hash'] as String
            : _digest('');
        final previous = saved is Map && saved['revision'] is int
            ? saved['revision'] as int
            : 0;
        final row = remote[id];
        // Missing or rolled-back server data cannot erase a known local draft.
        if (row == null && previous != 0) continue;
        final revision = row == null ? 0 : row['revision'] as int;
        if (revision < previous) continue;
        final text = row == null ? '' : await crypto.decryptDraft(row);
        if (_closed) return;
        if (revision == previous && revision != 0 && _digest(text) != base) {
          continue;
        }
        final current = local[id] ?? '';
        final decision = decideDraftMerge(
          base,
          _digest(current),
          _digest(text),
        );
        if (decision == DraftMerge.conflict) {
          if (conflicts.add(id)) _conflictChanges.add(null);
          continue;
        }
        if (conflicts.remove(id)) _conflictChanges.add(null);
        if (decision == DraftMerge.download) {
          if (!await storage.compareAndSet(id, current, text)) continue;
        }
        var finalRevision = revision;
        var finalBase = text;
        if (decision == DraftMerge.upload) {
          finalRevision = await crypto.putEncryptedDraft(id, revision, current);
          finalBase = current;
        }
        if (_closed) return;
        metadata['$id'] = {
          'base_hash': _digest(finalBase),
          'revision': finalRevision,
        };
        final value = jsonEncode(metadata);
        await (_writeMetadata?.call(_key, value) ??
            secure.write(key: _key, value: value));
      } catch (_) {
        // A locked identity, unavailable chat or conflicting CAS is retried later.
      }
    }
  }

  Future<({String local, String remote, int revision})> conflictVersions(
    int id,
  ) async {
    final rows = await crypto.encryptedDrafts();
    final row = rows.where((r) => r['chat_id'] == id).firstOrNull;
    if (_closed || row == null) throw StateError('Черновик недоступен');
    return (
      local: (await storage.asMap())[id] ?? '',
      remote: await crypto.decryptDraft(row),
      revision: row['revision'] as int,
    );
  }

  Future<String> resolveConflict(
    int id, {
    required String local,
    required String remote,
    required int revision,
    required bool keepLocal,
  }) async {
    await _running;
    if (_closed) throw StateError('Сеанс закрыт');
    final task = _resolveConflict(
      id,
      local: local,
      remote: remote,
      revision: revision,
      keepLocal: keepLocal,
    );
    _running = task
        .then<void>((_) {}, onError: (Object _, StackTrace _) {})
        .whenComplete(() => _running = null);
    return task;
  }

  Future<String> _resolveConflict(
    int id, {
    required String local,
    required String remote,
    required int revision,
    required bool keepLocal,
  }) async {
    if (((await storage.asMap())[id] ?? '') != local) {
      throw StateError('Черновик изменился. Откройте сравнение ещё раз.');
    }
    final text = keepLocal ? local : remote;
    var nextRevision = revision;
    if (keepLocal) {
      nextRevision = await crypto.putEncryptedDraft(id, revision, local);
    } else if (!await storage.compareAndSet(id, local, remote)) {
      throw StateError('Черновик изменился. Откройте сравнение ещё раз.');
    }
    if (_closed) throw StateError('Сеанс закрыт');
    final raw = await (_readMetadata?.call(_key) ?? secure.read(key: _key));
    final data = raw == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    data['$id'] = {'base_hash': _digest(text), 'revision': nextRevision};
    final value = jsonEncode(data);
    await (_writeMetadata?.call(_key, value) ??
        secure.write(key: _key, value: value));
    if (!_closed && conflicts.remove(id)) _conflictChanges.add(null);
    return text;
  }

  Future<void> close() async {
    if (_closed) {
      try {
        await _running;
      } catch (_) {}
      return;
    }
    _closed = true;
    _poll?.cancel();
    _debounce?.cancel();
    await _subscription?.cancel();
    try {
      await _running;
    } catch (_) {}
    _instances[userId]?.remove(this);
    await _conflictChanges.close();
  }
}
