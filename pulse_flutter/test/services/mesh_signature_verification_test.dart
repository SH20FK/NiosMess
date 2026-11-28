import 'dart:convert';
import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_codec.dart';
import 'package:pulse_flutter/services/bluetooth_mesh/mesh_packet.dart';

String _id(String body) => base64UrlEncode(
  hashes.sha256.convert(utf8.encode(body)).bytes,
).replaceAll('=', '');

int _mine(String id) {
  for (var i = 0; ; i++) {
    final digest = hashes.sha256
        .convert(utf8.encode('niosmess-ble-work-v1:$id:$i'))
        .bytes;
    if (digest[0] == 0 && digest[1] == 0) return i;
  }
}

/// Proves the mesh path performs exactly two Ed25519 verifications per packet
/// (transport device signature + inner message signature) and that delivery
/// reuses the inner result instead of verifying it a third time.
void main() {
  final now = DateTime.utc(2026, 10, 19);
  final alice = OrdinaryKeys.create(1), bob = OrdinaryKeys.create(2);
  late MeshPacket packet;
  late List<int> deviceSeed;
  late String permit;

  setUpAll(() async {
    final envelope = await OrdinaryCodec.encrypt(
      alice,
      await bob.public(),
      11,
      {'text': 'Только получателю'},
    );
    deviceSeed = randomE2eBytes();
    final device = base64Encode(
      (await (await Ed25519().newKeyPairFromSeed(
        deviceSeed,
      )).extractPublicKey()).bytes,
    );
    final pub = await alice.public();
    permit =
        '${base64UrlEncode(utf8.encode(jsonEncode({'v': 1, 'user': 1, 'epoch': alice.epoch, 'author': pub['ed'], 'device': device, 'session': 1, 'iat': now.millisecondsSinceEpoch ~/ 1000, 'exp': now.add(const Duration(days: 3)).millisecondsSinceEpoch ~/ 1000, 'nonce': 'test'}))).replaceAll('=', '')}.${base64UrlEncode(List.filled(32, 1)).replaceAll('=', '')}';
    packet = await MeshPacket.create(
      alice,
      envelope,
      deviceSeed: deviceSeed,
      permit: permit,
      now: now,
    );
  });

  test('parse verifies twice, delivery decrypts valid signature without a third', () async {
    OrdinaryCodec.verifications = 0;
    final copy = await MeshPacket.parse(packet.wire, now: now);
    expect(OrdinaryCodec.verifications, 2);
    expect(copy.proof, isNotNull);

    // Sender's own device and the recipient open the packet with no extra
    // verification: the proof carries the result of the inner check.
    for (final own in [alice, bob]) {
      OrdinaryCodec.verifications = 0;
      final body = await OrdinaryCodec.decrypt(
        own,
        await alice.public(),
        copy.envelope,
        11,
        1,
        authenticated: copy.proof,
      );
      expect(body['text'], 'Только получателю');
      expect(OrdinaryCodec.verifications, 0);
    }

    // Same packet without the proof still verifies once, so the skip is
    // caused by the proof and not by a removed check.
    OrdinaryCodec.verifications = 0;
    expect(
      (await OrdinaryCodec.decrypt(
        bob,
        await alice.public(),
        copy.envelope,
        11,
        1,
      ))['text'],
      'Только получателю',
    );
    expect(OrdinaryCodec.verifications, 1);
  });

  test('corrupted inner signature is rejected at parse and at delivery', () async {
    String forge(String envelope) {
      final inner = OrdinaryCodec.packet(envelope);
      inner['signature'] = base64Encode(List.filled(64, 0));
      return base64Encode(utf8.encode(jsonEncode(inner)));
    }

    final valid = await MeshPacket.parse(packet.wire, now: now);

    // Re-signed transport body carrying a bad inner signature: parse must
    // refuse, because parse still runs the inner Ed25519 check.
    final value = jsonDecode(packet.body) as Map<String, dynamic>;
    value['packet'] = forge(packet.envelope);
    final body = jsonEncode(value);
    final signature = base64Encode(
      (await Ed25519().sign(
        utf8.encode('niosmess-ble-v1:$body'),
        keyPair: await Ed25519().newKeyPairFromSeed(deviceSeed),
      )).bytes,
    );
    await expectLater(
      MeshPacket.parse(
        jsonEncode({
          'v': 1,
          'body': body,
          'signature': signature,
          'work': _mine(_id(body)),
          'hops': 0,
        }),
        now: now,
      ),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          'Mismatched message author',
        ),
      ),
    );

    // A proof minted for the authentic envelope must not vouch for a tampered
    // one: the codec sees the mismatch and verifies afresh, which fails.
    OrdinaryCodec.verifications = 0;
    await expectLater(
      OrdinaryCodec.decrypt(
        bob,
        await alice.public(),
        forge(valid.envelope),
        11,
        1,
        authenticated: valid.proof,
      ),
      throwsFormatException,
    );
    expect(OrdinaryCodec.verifications, 1);
  });
}
