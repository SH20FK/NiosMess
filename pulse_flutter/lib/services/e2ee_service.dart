import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class E2eeService {
  E2eeService();

  static const String _privateKeyStorageKey = 'e2ee.private_key';
  static const String _publicKeyStorageKey = 'e2ee.public_key';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final X25519 _x25519 = X25519();

  static final Map<int, SecretKey> _sharedSecrets = {};

  Future<KeyPair> generateKeyPair() async {
    return _x25519.newKeyPair();
  }

  Future<String> getPublicKeyBase64() async {
    String? existing = await _storage.read(key: _publicKeyStorageKey);
    if (existing != null && existing.isNotEmpty) {
      try {
        base64Decode(existing);
        return existing;
      } catch (_) {}
    }

    final keyPair = await generateKeyPair();
    await saveKeyPair(keyPair);
    final publicKey = await keyPair.extractPublicKey() as SimplePublicKey;
    final b64 = base64Encode(publicKey.bytes);
    await _storage.write(key: _publicKeyStorageKey, value: b64);
    return b64;
  }

  Future<KeyPair?> loadKeyPair() async {
    final raw = await _storage.read(key: _privateKeyStorageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final bytes = base64Decode(raw);
      return _x25519.newKeyPairFromSeed(bytes);
    } catch (e) {
      debugPrint('[E2eeService] Failed to load key pair: $e');
      return null;
    }
  }

  Future<void> saveKeyPair(KeyPair keyPair) async {
    final keyPairData = await keyPair.extract() as SimpleKeyPairData;
    await _storage.write(
      key: _privateKeyStorageKey,
      value: base64Encode(keyPairData.bytes),
    );
    await _storage.write(
      key: _publicKeyStorageKey,
      value: base64Encode(keyPairData.publicKey.bytes),
    );
  }

  Future<void> deleteKeyPair() async {
    await _storage.delete(key: _privateKeyStorageKey);
    await _storage.delete(key: _publicKeyStorageKey);
    _sharedSecrets.clear();
  }

  Future<SecretKey> computeSharedSecret({
    required String theirPublicKeyBase64,
    KeyPair? ourKeyPair,
  }) async {
    final pair = ourKeyPair ?? await loadKeyPair();
    if (pair == null) {
      throw StateError('No E2EE key pair available on this device');
    }
    final theirBytes = base64Decode(theirPublicKeyBase64);
    final theirPublicKey = SimplePublicKey(theirBytes, type: KeyPairType.x25519);
    return _x25519.sharedSecretKey(
      keyPair: pair,
      remotePublicKey: theirPublicKey,
    );
  }

  Future<SecretKey> getOrComputeSharedSecret({
    required int chatId,
    required String theirPublicKeyBase64,
    KeyPair? ourKeyPair,
  }) async {
    if (_sharedSecrets.containsKey(chatId)) {
      return _sharedSecrets[chatId]!;
    }
    final secret = await computeSharedSecret(
      theirPublicKeyBase64: theirPublicKeyBase64,
      ourKeyPair: ourKeyPair,
    );
    _sharedSecrets[chatId] = secret;
    return secret;
  }

  Future<String> encryptE2EEMessage({
    required String plaintext,
    required int chatId,
    required String theirPublicKeyBase64,
    KeyPair? ourKeyPair,
  }) async {
    final sharedSecret = await getOrComputeSharedSecret(
      chatId: chatId,
      theirPublicKeyBase64: theirPublicKeyBase64,
      ourKeyPair: ourKeyPair,
    );

    final aesGcm = AesGcm.with256bits();
    final plaintextBytes = utf8.encode(plaintext);
    final secretBox = await aesGcm.encrypt(
      plaintextBytes,
      secretKey: sharedSecret,
    );

    final result = {
      'ciphertext': base64Encode(secretBox.cipherText),
      'iv': base64Encode(secretBox.nonce),
      'tag': base64Encode(secretBox.mac.bytes),
    };

    return base64Encode(utf8.encode(jsonEncode(result)));
  }

  Future<String> decryptE2EEMessage({
    required String e2eeContentBase64,
    required int chatId,
    required String theirPublicKeyBase64,
    KeyPair? ourKeyPair,
  }) async {
    final sharedSecret = await getOrComputeSharedSecret(
      chatId: chatId,
      theirPublicKeyBase64: theirPublicKeyBase64,
      ourKeyPair: ourKeyPair,
    );

    final jsonStr = utf8.decode(base64Decode(e2eeContentBase64));
    final structure = jsonDecode(jsonStr) as Map<String, dynamic>;

    final ciphertext = base64Decode(structure['ciphertext'] as String);
    final iv = base64Decode(structure['iv'] as String);
    final tag = base64Decode(structure['tag'] as String);

    final aesGcm = AesGcm.with256bits();
    final secretBox = SecretBox(ciphertext, nonce: iv, mac: Mac(tag));
    final decrypted = await aesGcm.decrypt(secretBox, secretKey: sharedSecret);

    return utf8.decode(decrypted);
  }

  Future<SecretKey> deriveCallKey(int callId) async {
    final hkdf = Hkdf(hashAlgorithm: Sha256());
    final info = utf8.encode('nios-call-key-$callId');
    final keyPair = await loadKeyPair();
    if (keyPair == null) {
      return AesGcm.with256bits().newSecretKey();
    }
    final publicKey = await keyPair.extractPublicKey() as SimplePublicKey;
    final derived = await hkdf.deriveKey(
      secretKey: SecretKey(publicKey.bytes),
      nonce: info,
      info: info,
      length: 32,
    );
    return derived;
  }

  Future<bool> hasKeyPair() async {
    final raw = await _storage.read(key: _privateKeyStorageKey);
    return raw != null && raw.isNotEmpty;
  }
}

final Provider<E2eeService> e2eeServiceProvider =
    Provider<E2eeService>((Ref ref) => E2eeService());
