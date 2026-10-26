import 'dart:async';
import 'package:pulse_flutter/core/storage/chat_history_anchor.dart';
import 'dart:convert';
import 'dart:isolate';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pulse_flutter/core/storage/hive_bootstrap.dart';
import 'package:pulse_flutter/models/api/message_model.dart';

part 'encrypted_history_archive.dart';

class EncryptedMessageCache {
  static const String _boxName = 'enc_messages_v1';
  static const String _senderPlaintextBoxName = 'enc_sender_plaintext_v2';
  static const String _legacySenderBoxName = 'enc_sender_plaintext_v1';
  static Future<void>? _initialization;
  static const String _keyAlias = 'niosmess_msg_cache_key_v1';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static final AesGcm _aes = AesGcm.with256bits();

  static SecretKey? _cachedKey;
  static Future<SecretKey>? _keyFuture;
  static int _senderMigrationEpoch = 0;

  static const int senderPlaintextMemoryLimit = 256;
  static final _memorySenderPlaintexts = <String, String>{};
  @visibleForTesting
  static int get debugSenderPlaintextCount => _memorySenderPlaintexts.length;
  static void _rememberSender(String key, String text) {
    _memorySenderPlaintexts.remove(key);
    _memorySenderPlaintexts[key] = text;
    while (_memorySenderPlaintexts.length > senderPlaintextMemoryLimit) {
      _memorySenderPlaintexts.remove(_memorySenderPlaintexts.keys.first);
    }
  }

  static final Map<int, int> _accountGenerations = <int, int>{};
  static int _generationCounter = 0;
  static int _clearEpoch = 0;

  /// A delayed UI flush must not resurrect cache data after account erasure.
  static int accountGeneration(int userId) => _accountGenerations[userId] ?? 0;

  @visibleForTesting
  static void resetMemoryForTesting() {
    _cachedKey = null;
    _keyFuture = null;
    _memorySenderPlaintexts.clear();
  }

  static String _chatKey(int chatId, int? userId) =>
      userId != null ? '${userId}_$chatId' : '$chatId';

  static String _senderKey(int chatId, int messageId, int? userId) =>
      '${userId ?? 0}_${chatId}_$messageId';

  static Future<SecretKey> _getOrCreateKey() {
    if (_cachedKey != null) return Future.value(_cachedKey!);
    return _keyFuture ??= _loadOrCreateKey().whenComplete(
      () => _keyFuture = null,
    );
  }

  static Future<SecretKey> _loadOrCreateKey() async {
    final existing = await _secureStorage.read(key: _keyAlias);
    if (existing != null) {
      final bytes = base64Decode(existing);
      if (bytes.length != 32) throw const FormatException('CACHE_KEY_INVALID');
      return _cachedKey = SecretKey(bytes);
    }
    final key = await _aes.newSecretKey();
    await _secureStorage.write(
      key: _keyAlias,
      value: base64Encode(await key.extractBytes()),
    );
    return _cachedKey = key;
  }

  static Future<void> ensureInitialized() =>
      _initialization ??= _initialize().whenComplete(() {
        _initialization = null;
      });

  static Future<void> _initialize() async {
    await HiveBootstrap.ensureInitialized();
    await Future.wait([
      Hive.openBox<String>(_boxName),
      Hive.openBox<String>(_senderPlaintextBoxName),
    ]);
    if (Hive.isBoxOpen(_legacySenderBoxName) ||
        await Hive.boxExists(_legacySenderBoxName)) {
      final legacy = await Hive.openBox<String>(_legacySenderBoxName);
      final target = Hive.box<String>(_senderPlaintextBoxName);
      for (final entry in legacy.toMap().entries) {
        // Migration never overwrites a newer protected value or removes its
        // only readable source before the encrypted copy is verified.
        final key = '${entry.key}', original = entry.value;
        final epoch = _senderMigrationEpoch;
        try {
          if (!target.containsKey(key)) {
            final encoded = await _encodeSender(key, original);
            if (epoch != _senderMigrationEpoch) continue;
            await target.put(key, encoded);
            await target.flush();
          }
          if (await _decodeSender(key, target.get(key)!) == original) {
            await legacy.delete(entry.key);
            await legacy.flush();
          }
        } catch (_) {
          /* Preserve the source and retry the migration later. */
        }
      }
      await legacy.compact();
    }
  }

  static Future<String> _encodeSender(String id, String plaintext) async {
    final key = await _getOrCreateKey();
    final box = await _aes.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      aad: utf8.encode('NiosMess/sender-cache/2:$id'),
    );
    return base64Encode([...box.nonce, ...box.cipherText, ...box.mac.bytes]);
  }

  static Future<String> _decodeSender(String id, String encoded) async {
    final bytes = base64Decode(encoded);
    if (bytes.length < 28) throw const FormatException('SENDER_CACHE_INVALID');
    final key = await _getOrCreateKey();
    return utf8.decode(
      await _aes.decrypt(
        SecretBox(
          bytes.sublist(12, bytes.length - 16),
          nonce: bytes.sublist(0, 12),
          mac: Mac(bytes.sublist(bytes.length - 16)),
        ),
        secretKey: key,
        aad: utf8.encode('NiosMess/sender-cache/2:$id'),
      ),
    );
  }

  static Future<T> _runCompute<T>(FutureOr<T> Function() computation) {
    if (kIsWeb) {
      return Future<T>.sync(computation);
    }
    return Isolate.run(computation);
  }

  static Future<void> saveSenderPlaintext({
    required int chatId,
    required int messageId,
    required String plaintext,
    int? userId,
  }) async {
    if (plaintext.isEmpty) return;
    final String key = _senderKey(chatId, messageId, userId);
    final owner = userId ?? 0,
        generation = accountGeneration(userId ?? 0),
        clearEpoch = _clearEpoch;
    try {
      final encoded = await _encodeSender(key, plaintext);
      if (generation != accountGeneration(owner) || clearEpoch != _clearEpoch) {
        return;
      }
      if (!Hive.isBoxOpen(_senderPlaintextBoxName)) return;
      final box = Hive.box<String>(_senderPlaintextBoxName);
      await box.put(key, encoded);
      await box.flush();
      if (generation == accountGeneration(owner) && clearEpoch == _clearEpoch) {
        _rememberSender(key, plaintext);
      }
    } catch (_) {
      debugPrint('[EncryptedMessageCache] SENDER_CACHE_WRITE_FAILED');
    }
  }

  static Future<String?> getSenderPlaintext({
    required int chatId,
    required int messageId,
    int? userId,
  }) async {
    final key = _senderKey(chatId, messageId, userId);
    final owner = userId ?? 0,
        generation = accountGeneration(userId ?? 0),
        clearEpoch = _clearEpoch;
    final cached = _memorySenderPlaintexts[key];
    if (cached != null) {
      _rememberSender(key, cached);
      return cached;
    }
    try {
      if (Hive.isBoxOpen(_senderPlaintextBoxName)) {
        final encoded = Hive.box<String>(_senderPlaintextBoxName).get(key);
        if (encoded != null) {
          final text = await _decodeSender(key, encoded);
          if (generation != accountGeneration(owner) ||
              clearEpoch != _clearEpoch) {
            return null;
          }
          _rememberSender(key, text);
          return text;
        }
      }
      // Reading retained source entries remains supported after a failed
      // migration, but account ownership is checked by the scoped key/caller.
      if (Hive.isBoxOpen(_legacySenderBoxName)) {
        return Hive.box<String>(_legacySenderBoxName).get(key);
      }
    } catch (_) {
      debugPrint('[EncryptedMessageCache] SENDER_CACHE_READ_FAILED');
    }
    return null;
  }

  static Future<void> saveMessages(
    int chatId,
    List<ApiMessage> messages, {
    int? userId,
    bool isSecretChat = false,
    int? expectedAccountGeneration,
  }) async {
    if (!Hive.isBoxOpen(_boxName)) return;
    final owner = userId ?? 0;
    final generation = expectedAccountGeneration ?? accountGeneration(owner);
    final clearEpoch = _clearEpoch;
    if (generation != accountGeneration(owner)) return;
    try {
      final SecretKey key = await _getOrCreateKey();
      final List<int> keyBytes = await key.extractBytes();
      final int maxLimit = isSecretChat ? 2000 : 100;
      final List<Map<String, dynamic>> messagesJson = messages.length > maxLimit
          ? messages
                .sublist(messages.length - maxLimit)
                .map((m) => m.toJson())
                .toList()
          : messages.map((m) => m.toJson()).toList();

      final String encoded = await _runCompute(() async {
        final AesGcm isolateAes = AesGcm.with256bits();
        final SecretKey isolateKey = SecretKey(keyBytes);
        final String json = jsonEncode(messagesJson);
        final List<int> plaintext = utf8.encode(json);
        final SecretBox box = await isolateAes.encrypt(
          plaintext,
          secretKey: isolateKey,
        );
        final List<int> combined = [
          ...box.nonce,
          ...box.cipherText,
          ...box.mac.bytes,
        ];
        return base64.encode(combined);
      });

      if (generation != accountGeneration(owner) ||
          clearEpoch != _clearEpoch ||
          !Hive.isBoxOpen(_boxName)) {
        return;
      }
      final Box<String> hiveBox = Hive.box<String>(_boxName);
      await hiveBox.put(_chatKey(chatId, userId), encoded);
    } catch (e) {
      debugPrint('[EncryptedMessageCache] Save error: $e');
    }
  }

  static Future<List<ApiMessage>> loadMessages(
    int chatId, {
    int? userId,
    int? legacyOwnerUserId,
    bool strict = false,
  }) async {
    if (!Hive.isBoxOpen(_boxName)) return [];
    try {
      final Box<String> hiveBox = Hive.box<String>(_boxName);
      String? encoded = hiveBox.get(_chatKey(chatId, userId));
      if (encoded == null && userId != null && legacyOwnerUserId == userId) {
        encoded = hiveBox.get(chatId.toString());
      }
      if (encoded == null) return [];

      final SecretKey key = await _getOrCreateKey();
      final List<int> keyBytes = await key.extractBytes();

      final List<Map<String, dynamic>>? messagesJson = await _runCompute(
        () async {
          final AesGcm isolateAes = AesGcm.with256bits();
          final SecretKey isolateKey = SecretKey(keyBytes);
          final List<int> combined = base64.decode(encoded!);

          const int nonceLen = 12;
          const int macLen = 16;
          if (combined.length < nonceLen + macLen) {
            return null;
          }
          final List<int> nonce = combined.sublist(0, nonceLen);
          final List<int> mac = combined.sublist(combined.length - macLen);
          final List<int> cipherText = combined.sublist(
            nonceLen,
            combined.length - macLen,
          );

          final SecretBox box = SecretBox(
            cipherText,
            nonce: nonce,
            mac: Mac(mac),
          );
          final List<int> decrypted = await isolateAes.decrypt(
            box,
            secretKey: isolateKey,
          );
          final String json = utf8.decode(decrypted);
          final dynamic decoded = jsonDecode(json);
          if (decoded is List) {
            return decoded.cast<Map<String, dynamic>>();
          }
          return null;
        },
      );

      if (messagesJson == null) {
        if (strict) {
          throw const FormatException('Legacy cache authentication failed');
        }
        debugPrint('[EncryptedMessageCache] Corrupt data: too short');
        return [];
      }

      return messagesJson.map((e) => ApiMessage.fromJson(e)).toList();
    } catch (e) {
      if (strict) rethrow;
      debugPrint('[EncryptedMessageCache] Load error: $e');
      return [];
    }
  }

  static Future<void> clearChat(
    int chatId, {
    int? userId,
    int? legacyOwnerUserId,
  }) async {
    try {
      final Box<String> box = Hive.box<String>(_boxName);
      await box.delete(_chatKey(chatId, userId));
      if (userId != null && legacyOwnerUserId == userId) {
        await box.delete(chatId.toString());
      }
    } catch (e) {
      debugPrint('[EncryptedMessageCache] Clear error: $e');
    }
  }

  static Future<void> clearAll() async {
    _clearEpoch++;
    _senderMigrationEpoch++;
    try {
      _memorySenderPlaintexts.clear();
      if (Hive.isBoxOpen(_boxName)) {
        await Hive.box<String>(_boxName).clear();
      }
      for (final name in [_senderPlaintextBoxName, _legacySenderBoxName]) {
        if (Hive.isBoxOpen(name)) await Hive.box<String>(name).clear();
      }
    } catch (e) {
      debugPrint('[EncryptedMessageCache] ClearAll error: $e');
    }
  }

  static Future<void> clearAccount(int userId, List<int> secretChatIds) async {
    _senderMigrationEpoch++;
    _accountGenerations[userId] = ++_generationCounter;
    await EncryptedHistoryArchive.eraseAccount(userId);
    if (Hive.isBoxOpen(_boxName)) {
      final box = Hive.box<String>(_boxName);
      await box.deleteAll(
        box.keys
            .where(
              (key) =>
                  '$key'.startsWith('${userId}_') ||
                  secretChatIds.any((id) => '$key' == '$id'),
            )
            .toList(),
      );
    }
    bool owned(String key) => key.startsWith('${userId}_');
    _memorySenderPlaintexts.removeWhere((key, _) => owned(key));
    for (final name in [_senderPlaintextBoxName, _legacySenderBoxName]) {
      if (!Hive.isBoxOpen(name)) continue;
      final box = Hive.box<String>(name);
      await box.deleteAll(box.keys.where((key) => owned('$key')).toList());
      await box.flush();
    }
  }

  static Future<void> clearMigratedSecretChat(
    int chatId, {
    required int userId,
    int? legacyOwnerUserId,
    Set<int> legacyMessageIds = const {},
  }) async {
    await clearChat(
      chatId,
      userId: userId,
      legacyOwnerUserId: legacyOwnerUserId,
    );
    bool matches(String key) =>
        key.startsWith('${userId}_${chatId}_') ||
        (legacyOwnerUserId == userId &&
            key.startsWith('0_${chatId}_') &&
            legacyMessageIds.contains(int.tryParse(key.split('_').last)));
    _memorySenderPlaintexts.removeWhere((key, _) => matches(key));
    for (final name in [_senderPlaintextBoxName, _legacySenderBoxName]) {
      if (!Hive.isBoxOpen(name)) continue;
      final box = Hive.box<String>(name);
      await box.deleteAll(box.keys.where((key) => matches('$key')).toList());
      await box.flush();
      await box.compact();
    }
  }

  static Future<Map<int, String>> senderPlaintextsForMigration(
    int chatId,
    int userId, {
    int? legacyOwnerUserId,
    Set<int> legacyMessageIds = const {},
  }) async {
    final ids = <int>{};
    for (final name in [_senderPlaintextBoxName, _legacySenderBoxName]) {
      if (!Hive.isBoxOpen(name)) continue;
      for (final raw in Hive.box<String>(name).keys) {
        final value = '$raw';
        if (value.startsWith('${userId}_${chatId}_') ||
            (legacyOwnerUserId == userId &&
                value.startsWith('0_${chatId}_') &&
                legacyMessageIds.contains(
                  int.tryParse(value.split('_').last),
                ))) {
          final id = int.tryParse(value.split('_').last);
          if (id != null) ids.add(id);
        }
      }
    }
    final result = <int, String>{};
    for (final id in ids) {
      final scoped = await getSenderPlaintext(
        chatId: chatId,
        messageId: id,
        userId: userId,
      );
      final text =
          scoped ??
          (legacyOwnerUserId == userId && legacyMessageIds.contains(id)
              ? await getSenderPlaintext(chatId: chatId, messageId: id)
              : null);
      if (text != null && text.isNotEmpty) result[id] = text;
    }
    return result;
  }
}
