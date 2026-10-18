import 'dart:async';
import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'ordinary_e2ee_codec.dart';
export 'enrollment_proof.dart';

class EnrollmentOffer {
  const EnrollmentOffer(this.keyPair, this.nonce, this.proof);
  final SimpleKeyPair keyPair;
  final String nonce, proof;
  String get requestId => nonce.split(':')[1];
}

class EnrollmentStore {
  const EnrollmentStore({this.storage = const FlutterSecureStorage()});
  final FlutterSecureStorage storage;
  static const key = 'niosmess.ordinary.auto-enrollment.v1';
  static Future<void> _pending = Future<void>.value();
  Future<T> _locked<T>(Future<T> Function() action) async {
    final previous = _pending, done = Completer<void>();
    _pending = done.future;
    await previous;
    try {
      return await action();
    } finally {
      done.complete();
    }
  }

  Future<String> prepare() async {
    final pair = await X25519().newKeyPair();
    final target = (await pair.extractPublicKey()).bytes;
    final salt = randomE2eBytes();
    final nonce =
        'nios-e2e1:${const Uuid().v4()}:'
        '${base64UrlEncode(target).replaceAll('=', '')}:${base64UrlEncode(salt).replaceAll('=', '')}';
    final private = await pair.extractPrivateKeyBytes();
    await _locked(
      () => storage.write(
        key: key,
        value: jsonEncode({
          'nonce': nonce,
          'private': base64Encode(private),
          'public': base64Encode(target),
        }),
      ),
    );
    return nonce;
  }

  Future<void> attach(String? token) async {
    if (token == null) {
      return; // An older NiosID keeps the manual recovery path.
    }
    await _locked(() async {
      final raw = await storage.read(key: key);
      if (raw == null) return;
      final saved = jsonDecode(raw) as E2eJson;
      final parts = token.split('.');
      if (parts.length != 3 || token.length > 16384) return;
      E2eJson claims;
      try {
        claims =
            jsonDecode(
                  utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
                )
                as E2eJson;
      } catch (_) {
        return;
      }
      if (claims['nonce'] != saved['nonce']) return;
      // Full signature/issuer/subject verification occurs before any key transfer.
      await storage.write(
        key: key,
        value: jsonEncode({...saved, 'proof': token}),
      );
    });
  }

  Future<EnrollmentOffer?> read() async {
    final raw = await storage.read(key: key);
    if (raw == null) return null;
    final saved = jsonDecode(raw) as E2eJson;
    if (saved['proof'] is! String) return null;
    final public = decodeE2e(saved['public'], 32),
        private = decodeE2e(saved['private'], 32);
    return EnrollmentOffer(
      SimpleKeyPairData(
        private,
        publicKey: SimplePublicKey(public, type: KeyPairType.x25519),
        type: KeyPairType.x25519,
      ),
      saved['nonce'] as String,
      saved['proof'] as String,
    );
  }

  Future<void> clear(EnrollmentOffer offer) async {
    await _locked(() async {
      final raw = await storage.read(key: key);
      if (raw != null && (jsonDecode(raw) as E2eJson)['nonce'] == offer.nonce) {
        await storage.delete(key: key);
      }
    });
  }
}
