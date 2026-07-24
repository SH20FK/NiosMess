import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Ed25519IdentityService {
  static const String _storageKey = 'e2ee.ed25519_private';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final Ed25519 _ed25519 = Ed25519();

  KeyPair? _cachedKeyPair;

  Future<KeyPair> getOrCreateKeyPair() async {
    if (_cachedKeyPair != null) return _cachedKeyPair!;

    final raw = await _storage.read(key: _storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final bytes = base64Decode(raw);
        _cachedKeyPair = await _ed25519.newKeyPairFromSeed(bytes);
        return _cachedKeyPair!;
      } catch (e) {
        debugPrint('[Ed25519] Failed to load key pair: $e');
      }
    }

    final keyPair = await _ed25519.newKeyPair();
    final data = await keyPair.extract();
    await _storage.write(key: _storageKey, value: base64Encode(data.bytes));
    _cachedKeyPair = keyPair;
    return keyPair;
  }

  Future<SimplePublicKey> getPublicKey() async {
    final kp = await getOrCreateKeyPair();
    final pub = await kp.extractPublicKey() as SimplePublicKey;
    return pub;
  }

  Future<String> getPublicKeyBase64() async {
    final pub = await getPublicKey();
    return base64Encode(pub.bytes);
  }

  Future<List<int>> sign(List<int> message) async {
    final kp = await getOrCreateKeyPair();
    final signature = await _ed25519.sign(message, keyPair: kp);
    return signature.bytes;
  }

  Future<bool> verify({
    required List<int> message,
    required List<int> signature,
    required List<int> publicKeyBytes,
  }) async {
    try {
      final pubKey = SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519);
      final sig = Signature(signature, publicKey: pubKey);
      return _ed25519.verify(message, signature: sig);
    } catch (e) {
      debugPrint('[Ed25519] Verify failed: $e');
      return false;
    }
  }

  /// Extract the seed bytes from the current key pair for storage/export.
  Future<List<int>> exportSeed() async {
    final kp = await getOrCreateKeyPair();
    final data = await kp.extract() as SimpleKeyPairData;
    return List<int>.from(data.bytes);
  }

  /// Delete the stored key pair.
  Future<void> deleteKeyPair() async {
    await _storage.delete(key: _storageKey);
    _cachedKeyPair = null;
  }

  /// Format a public key as a human-readable fingerprint (hex groups).
  String formatFingerprint(List<int> publicKeyBytes) {
    final hex = base64Decode(base64Encode(publicKeyBytes))
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join('');
    final chunks = <String>[];
    for (var i = 0; i < hex.length; i += 8) {
      chunks.add(hex.substring(i, (i + 8 > hex.length) ? hex.length : i + 8));
    }
    return chunks.join(' ');
  }
}
