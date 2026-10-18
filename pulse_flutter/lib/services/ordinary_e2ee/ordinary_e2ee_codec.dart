import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';

typedef E2eJson = Map<String, dynamic>;
List<int> randomE2eBytes() {
  final r = Random.secure();
  return List.generate(32, (_) => r.nextInt(256));
}

List<int> decodeE2e(dynamic value, [int? size]) {
  if (value is! String || value.length > 2097152) {
    throw const FormatException('Invalid E2E packet');
  }
  final bytes = base64Decode(value);
  if (size != null && bytes.length != size) {
    throw const FormatException('Invalid E2E key');
  }
  return bytes;
}

class OrdinaryKeys {
  const OrdinaryKeys(this.userId, this.epoch, this.dhSeed, this.edSeed);
  final int userId;
  final String epoch;
  final List<int> dhSeed, edSeed;
  static OrdinaryKeys create(int userId) => OrdinaryKeys(
    userId,
    const Uuid().v4(),
    randomE2eBytes(),
    randomE2eBytes(),
  );
  Future<SimpleKeyPair> get dh => X25519().newKeyPairFromSeed(dhSeed);
  Future<SimpleKeyPair> get ed => Ed25519().newKeyPairFromSeed(edSeed);
  E2eJson secret() => {
    'user_id': userId,
    'epoch': epoch,
    'dh_seed': base64Encode(dhSeed),
    'ed_seed': base64Encode(edSeed),
  };
  static OrdinaryKeys fromJson(E2eJson data) => OrdinaryKeys(
    data['user_id'] as int,
    data['epoch'] as String,
    decodeE2e(data['dh_seed'], 32),
    decodeE2e(data['ed_seed'], 32),
  );
  Future<E2eJson> public() async => {
    'user_id': userId,
    'epoch': epoch,
    'dh': base64Encode((await (await dh).extractPublicKey()).bytes),
    'ed': base64Encode((await (await ed).extractPublicKey()).bytes),
  };
  Future<String> sign(String text) async => base64Encode(
    (await Ed25519().sign(utf8.encode(text), keyPair: await ed)).bytes,
  );
}

/// Experimental account-based E2E; standard primitives, no Signal code.
/// Static account keys permit offline device sync; this does not provide FS/PCS.
class OrdinaryCodec {
  static final _aes = AesGcm.with256bits();
  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  static Future<String> seal(List<int> clear, SecretKey key, String aad) async {
    final box = await _aes.encrypt(
      clear,
      secretKey: key,
      aad: utf8.encode(aad),
    );
    return base64Encode([...box.nonce, ...box.cipherText, ...box.mac.bytes]);
  }

  static Future<List<int>> open(
    String encoded,
    SecretKey key,
    String aad,
  ) async {
    final b = decodeE2e(encoded);
    if (b.length < 28) throw const FormatException('Truncated E2E packet');
    return _aes.decrypt(
      SecretBox(
        b.sublist(12, b.length - 16),
        nonce: b.sublist(0, 12),
        mac: Mac(b.sublist(b.length - 16)),
      ),
      secretKey: key,
      aad: utf8.encode(aad),
    );
  }

  static Future<bool> verify(
    String text,
    String signature,
    String public,
  ) async {
    try {
      return await Ed25519().verify(
        utf8.encode(text),
        signature: Signature(
          decodeE2e(signature, 64),
          publicKey: SimplePublicKey(
            decodeE2e(public, 32),
            type: KeyPairType.ed25519,
          ),
        ),
      );
    } catch (_) {
      return false;
    }
  }

  static String recoveryCode(List<int> key) =>
      base64UrlEncode(key).replaceAll('=', '');
  static List<int> recoveryBytes(String code) {
    final b = base64Url.decode(base64Url.normalize(code.trim()));
    if (b.length != 32) {
      throw const FormatException('Неверный ключ восстановления');
    }
    return b;
  }

  static E2eJson canonical(E2eJson p) => {
    'user_id': p['user_id'],
    'epoch': p['epoch'],
    'dh': p['dh'],
    'ed': p['ed'],
  };
  static Future<String> backup(OrdinaryKeys keys, List<int> secret) async =>
      seal(
        utf8.encode(jsonEncode(keys.secret())),
        SecretKey(secret),
        'niosmess-backup-v1:${jsonEncode(await keys.public())}',
      );
  static Future<OrdinaryKeys> restore(
    E2eJson identity,
    String encrypted,
    String code,
  ) async {
    final raw = await open(
      encrypted,
      SecretKey(recoveryBytes(code)),
      'niosmess-backup-v1:${jsonEncode(canonical(identity))}',
    );
    final keys = OrdinaryKeys.fromJson(jsonDecode(utf8.decode(raw)) as E2eJson);
    if (jsonEncode(await keys.public()) != jsonEncode(canonical(identity))) {
      throw const FormatException('Recovery identity mismatch');
    }
    return keys;
  }

  static String _aad(E2eJson p) => jsonEncode([
    'niosmess-message-v1',
    p['chat'],
    p['sender'],
    p['epoch'],
    p['id'],
    p['reply'],
    p['edit'],
    p['ephemeral'],
  ]);
  static Future<SecretKey> _wrap(
    SimpleKeyPair private,
    String public,
    String aad, {
    List<int>? pairingSecret,
  }) async {
    final shared = await X25519().sharedSecretKey(
      keyPair: private,
      remotePublicKey: SimplePublicKey(
        decodeE2e(public, 32),
        type: KeyPairType.x25519,
      ),
    );
    if ((await shared.extractBytes()).every((b) => b == 0)) {
      throw const FormatException('Invalid DH point');
    }
    return _hkdf.deriveKey(
      secretKey: shared,
      nonce: pairingSecret ?? utf8.encode('niosmess-ordinary-v1'),
      info: utf8.encode(aad),
    );
  }

  static E2eJson packet(String encoded) =>
      jsonDecode(utf8.decode(decodeE2e(encoded))) as E2eJson;
  static E2eJson header(String encoded) =>
      jsonDecode(packet(encoded)['body'] as String) as E2eJson;
  static bool recognises(String encoded) {
    try {
      return header(encoded)['v'] == 1;
    } catch (_) {
      return false;
    }
  }

  static Future<String> encrypt(
    OrdinaryKeys sender,
    E2eJson peer,
    int chat,
    E2eJson content, {
    int? reply,
    int? edit,
  }) async {
    final ephemeral = await X25519().newKeyPair();
    final h = <String, dynamic>{
      'v': 1,
      'chat': chat,
      'sender': sender.userId,
      'epoch': sender.epoch,
      'id': const Uuid().v4(),
      'reply': reply,
      'edit': edit,
      'ephemeral': base64Encode((await ephemeral.extractPublicKey()).bytes),
    };
    final aad = _aad(h), key = randomE2eBytes();
    final boxes = <String, dynamic>{};
    for (final p in [await sender.public(), peer]) {
      final binding = '$aad:${p['user_id']}:${p['epoch']}';
      boxes['${p['user_id']}'] = {
        'epoch': p['epoch'],
        'box': await seal(
          key,
          await _wrap(ephemeral, p['dh'] as String, binding),
          binding,
        ),
      };
    }
    final body = jsonEncode({
      ...h,
      'boxes': boxes,
      'cipher': await seal(
        utf8.encode(jsonEncode(content)),
        SecretKey(key),
        aad,
      ),
    });
    return base64Encode(
      utf8.encode(
        jsonEncode({'body': body, 'signature': await sender.sign(body)}),
      ),
    );
  }

  static Future<E2eJson> decrypt(
    OrdinaryKeys own,
    E2eJson sender,
    String encoded,
    int chat,
    int from, {
    int? reply,
    int? edit,
  }) async {
    final p = packet(encoded), h = header(encoded);
    if (h['v'] != 1 ||
        h['chat'] != chat ||
        h['sender'] != from ||
        h['epoch'] != sender['epoch'] ||
        sender['user_id'] != from ||
        h['reply'] != reply ||
        h['edit'] != edit ||
        !await verify(
          p['body'] as String,
          p['signature'] as String,
          sender['ed'] as String,
        )) {
      throw const FormatException('E2E authentication failed');
    }
    final boxes = h['boxes'] as E2eJson;
    if (boxes.length != 2 || !boxes.containsKey('$from')) {
      throw const FormatException('Invalid recipients');
    }
    final box = boxes['${own.userId}'] as E2eJson;
    if (box['epoch'] != own.epoch) {
      throw const FormatException('Key unavailable');
    }
    final aad = _aad(h), binding = '${_aad(h)}:${own.userId}:${own.epoch}';
    final key = await open(
      box['box'] as String,
      await _wrap(await own.dh, h['ephemeral'] as String, binding),
      binding,
    );
    if (key.length != 32) throw const FormatException('Invalid key size');
    return jsonDecode(
          utf8.decode(await open(h['cipher'] as String, SecretKey(key), aad)),
        )
        as E2eJson;
  }

  static Future<String> pair(
    OrdinaryKeys own,
    List<int> recovery,
    String target,
    String request,
    List<int> pairingSecret,
  ) async {
    final ephemeral = await X25519().newKeyPair();
    final aad = 'niosmess-pair-v1:${own.userId}:$request:$target';
    return base64Encode(
      utf8.encode(
        jsonEncode({
          'ephemeral': base64Encode((await ephemeral.extractPublicKey()).bytes),
          'cipher': await seal(
            utf8.encode(
              jsonEncode({
                'keys': own.secret(),
                'recovery': recoveryCode(recovery),
              }),
            ),
            await _wrap(ephemeral, target, aad, pairingSecret: pairingSecret),
            aad,
          ),
        }),
      ),
    );
  }

  static Future<E2eJson> unpair(
    SimpleKeyPair device,
    int user,
    String request,
    String encoded,
    List<int> pairingSecret,
  ) async {
    final target = base64Encode((await device.extractPublicKey()).bytes),
        p = packet(encoded);
    final aad = 'niosmess-pair-v1:$user:$request:$target';
    return jsonDecode(
          utf8.decode(
            await open(
              p['cipher'] as String,
              await _wrap(
                device,
                p['ephemeral'] as String,
                aad,
                pairingSecret: pairingSecret,
              ),
              aad,
            ),
          ),
        )
        as E2eJson;
  }
}
