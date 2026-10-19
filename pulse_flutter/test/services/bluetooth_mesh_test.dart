import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_codec.dart';
import 'package:pulse_flutter/services/bluetooth_mesh/mesh_packet.dart';
import 'package:pulse_flutter/services/bluetooth_mesh/mesh_router.dart';

void main() {
  final now = DateTime.utc(2026, 10, 19);
  final alice = OrdinaryKeys.create(1), bob = OrdinaryKeys.create(2);
  late MeshPacket packet;
  setUpAll(() async {
    final envelope = await OrdinaryCodec.encrypt(
      alice,
      await bob.public(),
      11,
      {'text': 'Только получателю'},
    );
    final seed = randomE2eBytes();
    final device = base64Encode(
      (await (await Ed25519().newKeyPairFromSeed(
        seed,
      )).extractPublicKey()).bytes,
    );
    final pub = await alice.public();
    final permit =
        '${base64UrlEncode(utf8.encode(jsonEncode({'v': 1, 'user': 1, 'epoch': alice.epoch, 'author': pub['ed'], 'device': device, 'session': 1, 'iat': now.millisecondsSinceEpoch ~/ 1000, 'exp': now.add(const Duration(days: 3)).millisecondsSinceEpoch ~/ 1000, 'nonce': 'test'}))).replaceAll('=', '')}.${base64UrlEncode(List.filled(32, 1)).replaceAll('=', '')}';
    packet = await MeshPacket.create(
      alice,
      envelope,
      deviceSeed: seed,
      permit: permit,
      now: now,
    );
  });
  test(
    'relays retain authenticated E2E only; recipient and own second device decrypt',
    () async {
      final copy = await MeshPacket.parse(packet.wire, now: now);
      expect(copy.wire.contains('Только получателю'), isFalse);
      for (final own in [alice, bob]) {
        expect(
          (await OrdinaryCodec.decrypt(
            own,
            await alice.public(),
            copy.envelope,
            11,
            1,
          ))['text'],
          'Только получателю',
        );
      }
      await expectLater(
        OrdinaryCodec.decrypt(
          OrdinaryKeys.create(3),
          await alice.public(),
          copy.envelope,
          11,
          1,
        ),
        throwsA(anything),
      );
      expect(copy.id, packet.id);
    },
  );
  test(
    'forgery, renewed expiry, invalid hops and expired packets cannot enter relay',
    () async {
      final signature = jsonDecode(packet.wire) as Map<String, dynamic>;
      signature['signature'] = base64Encode(List.filled(64, 0));
      await expectLater(
        MeshPacket.parse(jsonEncode(signature), now: now),
        throwsFormatException,
      );
      final hops = jsonDecode(packet.wire) as Map<String, dynamic>;
      hops['hops'] = 9;
      await expectLater(
        MeshPacket.parse(jsonEncode(hops), now: now),
        throwsFormatException,
      );
      final value = jsonDecode(packet.body) as Map<String, dynamic>;
      value['expires'] = now
          .add(const Duration(days: 5))
          .millisecondsSinceEpoch;
      final modified = jsonDecode(packet.wire) as Map<String, dynamic>;
      modified['body'] = jsonEncode(value);
      await expectLater(
        MeshPacket.parse(jsonEncode(modified), now: now),
        throwsFormatException,
      );
      await expectLater(
        MeshPacket.parse(packet.wire, now: now.add(const Duration(days: 4))),
        throwsFormatException,
      );
      await expectLater(
        MeshPacket.parse('x' * 25000, now: now),
        throwsFormatException,
      );
    },
  );
  test(
    'three hops, loops, durable relay restart and later second recipient device',
    () async {
      final routers = <String, MeshRouter>{}, stored = <String, String>{};
      final deliveries = <String, List<String>>{};
      final frames = <(String, String, String)>[];
      MeshRouter make(String name) => MeshRouter(
        now: () => now,
        send: (peer, frame) async {
          frames.add((name, peer, frame));
        },
        persist: (state) async {
          stored[name] = state;
        },
        deliver: (p) async {
          deliveries.putIfAbsent(name, () => []).add(p.id);
        },
      );
      Future<void> link(String a, String b) async {
        await routers[a]!.connected(b);
        await routers[b]!.connected(a);
      }

      Future<void> drain() async {
        var count = 0;
        while (frames.isNotEmpty) {
          if (++count > 200) fail('Unbounded forwarding loop');
          final (a, b, frame) = frames.removeAt(0);
          await routers[b]!.receive(a, frame);
        }
      }

      for (final name in ['A', 'B', 'C', 'D']) {
        routers[name] = make(name);
      }
      await routers['A']!.enqueue(packet);
      await link('A', 'B');
      await drain();
      expect(deliveries['B'], [packet.id]);
      routers['B']!.close();
      routers['B'] = make('B');
      await routers['B']!.restore(stored['B']);
      await link('B', 'C');
      await link('C', 'D');
      await link('A', 'C');
      await drain();
      expect(deliveries['D'], [packet.id]);
      expect(deliveries['A'], [packet.id]);
      routers['D2'] = make('D2');
      await link('C', 'D2');
      await drain();
      expect(deliveries['D2'], [packet.id]);
      expect(routers['C']!.packets.length, 1);
      expect(
        stored.values.any((s) => s.contains('Только получателю')),
        isFalse,
      );
      for (final router in routers.values) {
        router.close();
      }
    },
  );
  test(
    'expired queues are purged; peer receive budgets bound repeated work',
    () async {
      var clock = now;
      String? saved;
      var sends = 0;
      final router = MeshRouter(
        now: () => clock,
        send: (_, _) async {
          sends++;
        },
        persist: (s) async {
          saved = s;
        },
        deliver: (_) async {},
      );
      await router.enqueue(packet);
      await router.connected('peer');
      final inventory = jsonEncode({
        'v': 1,
        'type': 'inventory',
        'ids': ['a' * 43],
      });
      for (var i = 0; i < 400; i++) {
        await router.receive('peer', inventory);
      }
      expect(sends, lessThanOrEqualTo(257));
      clock = now.add(const Duration(days: 4));
      await router.restore(saved);
      expect(router.packets, isEmpty);
      router.close();
    },
  );
}
