import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;
import 'package:nios_mls/nios_mls.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  final python = Platform.environment['NIOS_PROTOCOL_TEST_PYTHON'];
  final backend = Platform.environment['NIOS_PROTOCOL_BACKEND_PATH'];
  test(
    'real HTTP SQLite MLS reservation, server/client restart, Welcome and removal',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'nios-mls-python-',
      );
      final key = List.generate(32, (i) => i + 1);
      final group = Uint8List.fromList(utf8.encode('real-http-mls-group'));
      final trusted = <String, Uint8List>{};
      final clients = <NiosMlsClient>[];
      final apis = <HttpMlsDeliveryApi>[];
      final bridges = <NiosMlsDeliveryCoordinator>[];
      Process? server;
      Future<Uri> start() async {
        final process = await Process.start(python!, [
          File('test/support/serve_backend.py').absolute.path,
          '--backend',
          backend!,
          '--directory',
          '${directory.path}/server',
        ]);
        server = process;
        final ready = Completer<Uri>();
        process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((line) {
              if (line.startsWith('{"port":')) {
                final data = jsonDecode(line) as Map;
                if (!ready.isCompleted) {
                  ready.complete(Uri.parse('http://127.0.0.1:${data['port']}'));
                }
              }
            });
        // Keep output drained without logging any wire bodies or credentials.
        process.stderr.drain<void>();
        unawaited(
          process.exitCode.then((code) {
            if (!ready.isCompleted) {
              ready.completeError(StateError('test_server_exit_$code'));
            }
          }),
        );
        return ready.future.timeout(const Duration(seconds: 20));
      }

      Future<void> stop() async {
        final process = server;
        server = null;
        if (process == null) return;
        process.kill(ProcessSignal.sigkill);
        await process.exitCode.timeout(const Duration(seconds: 10));
      }

      Future<NiosMlsClient> open(String device) async {
        final client = await NiosMlsClient.open(
          path: '${directory.path}/native/$device',
          storageKey: key,
          accountId: device,
          deviceId: device,
          authorizeDevice: (account, deviceId, signingKey) async =>
              base64Encode(trusted[deviceId] ?? []) == base64Encode(signingKey),
        );
        trusted[device] = client.signingPublicKey;
        clients.add(client);
        return client;
      }

      final deliveries = <String, MlsApplicationDelivery>{};
      HttpMlsDeliveryApi api(Uri origin, String device) {
        final result = HttpMlsDeliveryApi(
          baseUri: origin,
          deviceId: device,
          bearerToken: 'test-only-$device',
          allowInsecureLoopback: true,
          enqueueApplication: (delivery) async {
            final old = deliveries[delivery.deliveryId];
            if (old != null &&
                base64Encode(old.ciphertext) !=
                    base64Encode(delivery.ciphertext)) {
              throw StateError('delivery_id_conflict');
            }
            deliveries[delivery.deliveryId] = delivery;
          },
        );
        apis.add(result);
        return result;
      }

      NiosMlsDeliveryCoordinator attach(
        NiosMlsClient client,
        HttpMlsDeliveryApi deliveryApi,
      ) {
        final bridge = NiosMlsDeliveryCoordinator.attach(
          client: client,
          api: deliveryApi,
        );
        bridges.add(bridge);
        return bridge;
      }

      try {
        var origin = await start();
        var alice = await open('alice');
        final bob = await open('bob');
        final linkPairs = <String, SimpleKeyPair>{};
        for (final client in [alice, bob]) {
          final pair = await Ed25519().newKeyPair();
          linkPairs[client.deviceId] = pair;
          final response = await http.post(
            origin.resolve('/test/enroll'),
            headers: {
              'Authorization': 'Bearer test-only-${client.deviceId}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'link_key': base64Encode((await pair.extractPublicKey()).bytes),
              'mls_key': base64Encode(client.signingPublicKey),
            }),
          );
          expect(response.statusCode, 200);
        }
        var aliceApi = api(origin, 'alice');
        var bobApi = api(origin, 'bob');
        await alice.createGroup(groupId: group);
        await aliceApi.createGroup(groupId: group, chatId: 'test-chat');
        await bobApi.publishKeyPackage(
          keyPackage: await bob.createKeyPackage(),
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          signPublication: (bytes) async => Uint8List.fromList(
            (await Ed25519().sign(bytes, keyPair: linkPairs['bob']!)).bytes,
          ),
        );
        var bridge = attach(alice, aliceApi);
        await bridge.enqueueAdd(
          operationId: 'invite-bob',
          groupId: group,
          deviceIds: ['bob'],
        );
        expect(
          (await http.post(
            origin.resolve('/test/fail-next-commit-reply'),
            headers: {'Authorization': 'Bearer test-only-alice'},
          )).statusCode,
          200,
        );
        await expectLater(bridge.pump(), throwsA(isA<NiosMlsException>()));
        final prepared = alice.outboundOperation('invite-bob')!.message;
        expect(await alice.epoch(group), BigInt.one);
        // Kill the actual backend after its DB commit and reopen both processes'
        // state. Recovery must finish the old reservation, not create a new epoch.
        await bridge.close();
        await alice.close();
        await stop();
        await aliceApi.close();
        await bobApi.close();
        origin = await start();
        alice = await open('alice');
        aliceApi = api(origin, 'alice');
        bobApi = api(origin, 'bob');
        bridge = attach(alice, aliceApi);
        await bridge.pump();
        expect(bridge.intents.single.complete, isTrue);
        expect(alice.outboundOperation('invite-bob')!.message, prepared);
        final bobBridge = attach(bob, bobApi);
        expect(await bobApi.synchronizeControls(bobBridge), 1);
        expect(await bobApi.synchronizeControls(bobBridge), 0);
        expect(await bob.epoch(group), BigInt.one);
        await bridge.enqueueApplication(
          operationId: 'hello',
          groupId: group,
          plaintext: utf8.encode('real server-controlled MLS group'),
        );
        await bridge.pump();
        final delivery = deliveries.values.single;
        expect(delivery.linkSessionId, 'mls:${mlsServerGroupId(group)}:1');
        expect(
          utf8.decode(
            (await bob.receive(
              groupId: group,
              message: delivery.ciphertext,
            )).plaintext!,
          ),
          'real server-controlled MLS group',
        );
        await bridge.enqueueRemove(
          operationId: 'remove-bob',
          groupId: group,
          deviceIds: ['bob'],
        );
        await bridge.pump();
        expect(await alice.epoch(group), BigInt.two);
        expect(await bobApi.synchronizeControls(bobBridge), 1);
        expect(await bob.isActive(group), isFalse);
        await expectLater(
          aliceApi.ensureApplicationDeliveryAllowed(
            groupId: group,
            epoch: BigInt.one,
            recipientDeviceIds: ['bob'],
          ),
          throwsA(isA<NiosMlsException>()),
        );
        await expectLater(
          bobApi.ensureApplicationDeliveryAllowed(
            groupId: group,
            epoch: BigInt.two,
            recipientDeviceIds: ['alice'],
          ),
          throwsA(isA<NiosMlsException>()),
        );
      } finally {
        for (final bridge in bridges) {
          await bridge.close();
        }
        for (final api in apis) {
          await api.close();
        }
        for (final client in clients) {
          await client.close();
        }
        await stop();
        await directory.delete(recursive: true);
      }
    },
    skip: python == null || backend == null
        ? 'Set NIOS_PROTOCOL_TEST_PYTHON and NIOS_PROTOCOL_BACKEND_PATH for real Python server tests.'
        : false,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
