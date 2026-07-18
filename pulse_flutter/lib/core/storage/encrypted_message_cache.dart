import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pulse_flutter/models/api/message_model.dart';

class EncryptedMessageCache {
  static const String _boxName = 'enc_messages_v1';
  static const String _keyAlias = 'niosmess_msg_cache_key_v1';
  static const FlutterSecureStorage _secureStorage =
    FlutterSecureStorage();

  static final AesGcm _aes = AesGcm.with256bits();

  static SecretKey? _cachedKey;
  static Completer<SecretKey>? _keyCompleter;

  static Future<SecretKey> _getOrCreateKey() async {
    if (_cachedKey != null) return _cachedKey!;

    if (_keyCompleter != null) return _keyCompleter!.future;

    _keyCompleter = Completer<SecretKey>();
    try {
      final String? existing = await _secureStorage.read(key: _keyAlias);
      if (existing != null) {
        final List<int> bytes = base64.decode(existing);
        _cachedKey = SecretKey(bytes);
        _keyCompleter!.complete(_cachedKey!);
        return _cachedKey!;
      }

      final SecretKey newKey = await _aes.newSecretKey();
      final List<int> keyBytes = await newKey.extractBytes();
      await _secureStorage.write(
        key: _keyAlias,
        value: base64.encode(keyBytes),
      );
      _cachedKey = newKey;
      _keyCompleter!.complete(_cachedKey!);
      return _cachedKey!;
    } catch (e) {
      _keyCompleter!.completeError(e);
      rethrow;
    } finally {
      _keyCompleter = null;
    }
  }

  static Future<void> ensureInitialized() async {
    try {
      await Hive.openBox<String>(_boxName);
    } catch (e) {
      debugPrint('[EncryptedMessageCache] Init error: $e');
    }
  }

  static Future<void> saveMessages(
    int chatId,
    List<ApiMessage> messages,
  ) async {
    try {
      final SecretKey key = await _getOrCreateKey();
      final List<int> keyBytes = await key.extractBytes();
      final List<Map<String, dynamic>> messagesJson = messages.length > 100
          ? messages.sublist(messages.length - 100).map((m) => m.toJson()).toList()
          : messages.map((m) => m.toJson()).toList();

      final String encoded = await Isolate.run(() async {
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

      final Box<String> hiveBox = Hive.box<String>(_boxName);
      await hiveBox.put(chatId.toString(), encoded);
    } catch (e) {
      debugPrint('[EncryptedMessageCache] Save error: $e');
    }
  }

  static Future<List<ApiMessage>> loadMessages(int chatId) async {
    try {
      final Box<String> hiveBox = Hive.box<String>(_boxName);
      final String? encoded = hiveBox.get(chatId.toString());
      if (encoded == null) return [];

      final SecretKey key = await _getOrCreateKey();
      final List<int> keyBytes = await key.extractBytes();

      final List<Map<String, dynamic>>? messagesJson = await Isolate.run(() async {
        final AesGcm isolateAes = AesGcm.with256bits();
        final SecretKey isolateKey = SecretKey(keyBytes);
        final List<int> combined = base64.decode(encoded);

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
        final List<int> plaintext = await isolateAes.decrypt(
          box,
          secretKey: isolateKey,
        );
        final String json = utf8.decode(plaintext);
        final List<dynamic> list = jsonDecode(json) as List<dynamic>;
        return list.whereType<Map<String, dynamic>>().toList();
      });

      if (messagesJson == null) {
        debugPrint('[EncryptedMessageCache] Corrupt data: too short');
        return [];
      }

      return messagesJson.map((e) => ApiMessage.fromJson(e)).toList();
    } catch (e) {
      debugPrint('[EncryptedMessageCache] Load error: $e');
      return [];
    }
  }

  static Future<void> clearChat(int chatId) async {
    try {
      await Hive.box<String>(_boxName).delete(chatId.toString());
    } catch (e) {
      debugPrint('[EncryptedMessageCache] Clear error: $e');
    }
  }

  static Future<void> clearAll() async {
    try {
      await Hive.box<String>(_boxName).clear();
    } catch (e) {
      debugPrint('[EncryptedMessageCache] ClearAll error: $e');
    }
  }
}
