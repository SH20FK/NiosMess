import 'dart:convert';
import 'dart:math';
import 'package:asn1lib/asn1lib.dart';
import 'package:cryptography/cryptography.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';

class E2eeService {
  E2eeService();

  static const String _privateKeyStorageKey = 'e2ee.private_key';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Uint8List _uint8list(List<int> bytes) => Uint8List.fromList(bytes);

  Future<void> rotateKeyPair() async {
    debugPrint('[E2eeService] Rotating key pair');
    final pair = await generateKeyPair();
    await savePrivateKey(pair.privateKey);
  }

  Future<AsymmetricKeyPair<PublicKey, PrivateKey>> generateKeyPair() async {
    final keyGen = RSAKeyGenerator()
      ..init(ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 64),
        _secureRandom(),
      ));
    final pair = keyGen.generateKeyPair();
    return pair;
  }

  SecureRandom _secureRandom() {
    final secureRandom = FortunaRandom();
    final seed = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seed)));
    return secureRandom;
  }

  Future<String> getPublicKeyBase64() async {
    RSAPrivateKey? existingPrivate;
    try {
      existingPrivate = await loadPrivateKey();
    } catch (e) {
      debugPrint('[E2eeService] Corrupt key detected, regenerating: $e');
      await _storage.delete(key: _privateKeyStorageKey);
      existingPrivate = null;
    }

    if (existingPrivate != null) {
      try {
        final publicKey = RSAPublicKey(
            existingPrivate.modulus!, existingPrivate.publicExponent!);
        final publicKeyDer = _encodePublicKeyToDer(publicKey);
        return base64Encode(publicKeyDer);
      } catch (e) {
        debugPrint('[E2eeService] Key unusable, regenerating: $e');
        await _storage.delete(key: _privateKeyStorageKey);
        existingPrivate = null;
      }
    }

    final pair = await generateKeyPair();
    await savePrivateKey(pair.privateKey);
    final publicKey = pair.publicKey as RSAPublicKey;
    final publicKeyDer = _encodePublicKeyToDer(publicKey);
    return base64Encode(publicKeyDer);
  }

  Future<void> savePrivateKey(PrivateKey privateKey) async {
    final rsaPrivate = privateKey as RSAPrivateKey;
    final derBytes = _encodePrivateKeyToDer(rsaPrivate);
    await _storage.write(
      key: _privateKeyStorageKey,
      value: base64Encode(derBytes),
    );
  }

  Future<RSAPrivateKey?> loadPrivateKey() async {
    final String? raw = await _storage.read(key: _privateKeyStorageKey);
    if (raw == null || raw.isEmpty) return null;
    final derBytes = base64Decode(raw);
    final key = _decodePrivateKeyFromDer(derBytes);
    // Explicit validation — pointycastle uses assert() which is stripped in release
    if (key.modulus == null || key.p == null || key.q == null) {
      throw StateError('RSA key has null components');
    }
    if (key.p! * key.q! != key.modulus!) {
      throw ArgumentError('modulus inconsistent with RSA p and q');
    }
    return key;
  }

  Future<String> encryptE2EEMessage({
    required String plaintext,
    required String recipientPublicKeyBase64,
  }) async {
    final aesKeyBytes = _generateAes256Key();
    final aesGcm = crypto.AesGcm.with256bits();
    final aesSecretKey = crypto.SecretKey(aesKeyBytes);
    final iv = _generateIv();
    final plaintextBytes = utf8.encode(plaintext);

    final secretBox = await aesGcm.encrypt(
      plaintextBytes,
      secretKey: aesSecretKey,
      nonce: iv,
    );

    final recipientPublicKeyDer = base64Decode(recipientPublicKeyBase64);
    final rsaPublicKey = _decodePublicKeyFromDer(recipientPublicKeyDer);
    final encryptedAesKey = _rsaOaepEncrypt(rsaPublicKey, aesKeyBytes);

    final e2eeStructure = {
      'encrypted_key': base64Encode(encryptedAesKey),
      'ciphertext': base64Encode(secretBox.cipherText),
      'iv': base64Encode(iv),
      'tag': base64Encode(secretBox.mac.bytes),
    };

    return base64Encode(utf8.encode(jsonEncode(e2eeStructure)));
  }

  Future<String> decryptE2EEMessage({
    required String e2eeContentBase64,
    required RSAPrivateKey privateKey,
  }) async {
    final jsonStr = utf8.decode(base64Decode(e2eeContentBase64));
    final structure = jsonDecode(jsonStr) as Map<String, dynamic>;

    final encryptedAesKey = base64Decode(structure['encrypted_key'] as String);
    final ciphertext = base64Decode(structure['ciphertext'] as String);
    final iv = base64Decode(structure['iv'] as String);
    final tag = base64Decode(structure['tag'] as String);

    final aesKeyBytes = _rsaOaepDecrypt(privateKey, encryptedAesKey);

    final aesGcm = crypto.AesGcm.with256bits();
    final aesSecretKey = crypto.SecretKey(aesKeyBytes);
    final secretBox = crypto.SecretBox(ciphertext, nonce: iv, mac: crypto.Mac(tag));
    final decrypted = await aesGcm.decrypt(secretBox, secretKey: aesSecretKey);

    return utf8.decode(decrypted);
  }

  List<int> _rsaOaepEncrypt(RSAPublicKey publicKey, List<int> data) {
    final cipher = OAEPEncoding(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));
    return cipher.process(_uint8list(data)).toList();
  }

  List<int> _rsaOaepDecrypt(RSAPrivateKey privateKey, List<int> data) {
    final cipher = OAEPEncoding(RSAEngine())
      ..init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));
    return cipher.process(_uint8list(data)).toList();
  }

  Uint8List _encodePublicKeyToDer(RSAPublicKey key) {
    final algorithmSeq = ASN1Sequence()
      ..add(ASN1ObjectIdentifier.fromComponentString('1.2.840.113549.1.1.1'))
      ..add(ASN1Null());
    final publicKeySeq = ASN1Sequence()
      ..add(ASN1Integer(key.modulus!))
      ..add(ASN1Integer(key.exponent!));
    final publicKeyBitString = ASN1BitString(publicKeySeq.encodedBytes.toList());
    final topLevelSeq = ASN1Sequence()
      ..add(algorithmSeq)
      ..add(publicKeyBitString);
    return topLevelSeq.encodedBytes;
  }

  RSAPublicKey _decodePublicKeyFromDer(List<int> derBytes) {
    final parser = ASN1Parser(Uint8List.fromList(derBytes));
    final topLevel = parser.nextObject() as ASN1Sequence;
    final bitString = topLevel.elements[1] as ASN1BitString;
    final innerParser = ASN1Parser(bitString.contentBytes());
    final keySeq = innerParser.nextObject() as ASN1Sequence;
    final modulus = (keySeq.elements[0] as ASN1Integer).valueAsBigInteger;
    final exponent = (keySeq.elements[1] as ASN1Integer).valueAsBigInteger;
    return RSAPublicKey(modulus, exponent);
  }

  Uint8List _encodePrivateKeyToDer(RSAPrivateKey key) {
    final seq = ASN1Sequence()
      ..add(ASN1Integer(BigInt.zero))
      ..add(ASN1Integer(key.modulus!))
      ..add(ASN1Integer(key.publicExponent!))
      ..add(ASN1Integer(key.privateExponent!))
      ..add(ASN1Integer(key.p!))
      ..add(ASN1Integer(key.q!))
      ..add(ASN1Integer(key.privateExponent! % (key.p! - BigInt.one)))
      ..add(ASN1Integer(key.privateExponent! % (key.q! - BigInt.one)))
      ..add(ASN1Integer(key.q!.modInverse(key.p!)));
    return seq.encodedBytes;
  }

  RSAPrivateKey _decodePrivateKeyFromDer(List<int> derBytes) {
    final parser = ASN1Parser(Uint8List.fromList(derBytes));
    final seq = parser.nextObject() as ASN1Sequence;
    return RSAPrivateKey(
      (seq.elements[1] as ASN1Integer).valueAsBigInteger,
      (seq.elements[3] as ASN1Integer).valueAsBigInteger,
      (seq.elements[4] as ASN1Integer).valueAsBigInteger,
      (seq.elements[5] as ASN1Integer).valueAsBigInteger,
      (seq.elements[2] as ASN1Integer).valueAsBigInteger,
    );
  }

  List<int> _generateAes256Key() {
    final random = Random.secure();
    return List<int>.generate(32, (_) => random.nextInt(256));
  }

  List<int> _generateIv() {
    final random = Random.secure();
    return List<int>.generate(12, (_) => random.nextInt(256));
  }
}
