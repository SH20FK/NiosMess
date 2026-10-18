import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' as crypto;
import 'package:iroh_quic/iroh_quic.dart' as iroh;
import 'package:nios_iroh/nios_iroh.dart';
import 'package:nios_sdk/link.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  late Directory temporary;
  setUpAll(() async => iroh.Iroh.init());
  setUp(
    () async => temporary = await Directory.systemTemp.createTemp('nios_iroh_'),
  );
  tearDown(() async {
    if (await temporary.exists()) await temporary.delete(recursive: true);
  });

  test(
    'account identity is encrypted, persistent and fails closed on wrong key',
    () async {
      final wrappingKey = await crypto.AesGcm.with256bits().newSecretKey();
      final directory = p.join(temporary.path, 'identity');
      final first = await IrohIdentityStore.loadOrCreate(
        directory: directory,
        accountId: 'alice',
        wrappingKey: wrappingKey,
      );
      final second = await IrohIdentityStore.loadOrCreate(
        directory: directory,
        accountId: 'alice',
        wrappingKey: wrappingKey,
      );
      expect(first.publicKey, second.publicKey);
      final files = await Directory(
        directory,
      ).list().where((file) => file.path.endsWith('.iroh-identity')).toList();
      final bytes = await File(files.single.path).readAsBytes();
      expect(bytes.length, 60);
      expect(bytes.sublist(12, 44), isNot(first.toBytes()));
      await expectLater(
        IrohIdentityStore.loadOrCreate(
          directory: directory,
          accountId: 'alice',
          wrappingKey: await crypto.AesGcm.with256bits().newSecretKey(),
        ),
        throwsA(isA<crypto.SecretBoxAuthenticationError>()),
      );
      final afterFailure = await IrohIdentityStore.loadOrCreate(
        directory: directory,
        accountId: 'alice',
        wrappingKey: wrappingKey,
      );
      expect(afterFailure.publicKey, first.publicKey);
    },
  );

  test(
    'concurrent identity loading keeps one pin and authenticates every wrapping key',
    () async {
      final key = await crypto.AesGcm.with256bits().newSecretKey();
      final directory = p.join(temporary.path, 'concurrent-identity');
      final identities = await Future.wait(
        List.generate(
          20,
          (_) => IrohIdentityStore.loadOrCreate(
            directory: directory,
            accountId: 'alice',
            wrappingKey: key,
          ),
        ),
      );
      expect(
        identities.map((identity) => identity.publicKey).toSet(),
        hasLength(1),
      );
      final wrongKey = await crypto.AesGcm.with256bits().newSecretKey();
      final valid = IrohIdentityStore.loadOrCreate(
        directory: directory,
        accountId: 'alice',
        wrappingKey: key,
      );
      final invalid = IrohIdentityStore.loadOrCreate(
        directory: directory,
        accountId: 'alice',
        wrappingKey: wrongKey,
      );
      final rejected = expectLater(
        invalid,
        throwsA(isA<crypto.SecretBoxAuthenticationError>()),
      );
      expect((await valid).publicKey, identities.first.publicKey);
      await rejected;
    },
  );

  test(
    'real two-endpoint QUIC transports return durable encrypted acknowledgements',
    () async {
      final key = await crypto.AesGcm.with256bits().newSecretKey();
      final aliceCipher = AesGcmEnvelopeCipher(
        deviceId: 'alice',
        keyForPeer: (_) async => key,
      );
      final bobCipher = AesGcmEnvelopeCipher(
        deviceId: 'bob',
        keyForPeer: (_) async => key,
      );
      late DurableSession aliceSession;
      late DurableSession bobSession;
      final alice = await IrohLinkTransport.bind(
        deviceId: 'alice',
        identity: iroh.SecretKey.generate(),
        onOperation: (envelope) => aliceSession.receive(envelope),
        onAcknowledgement: (envelope) =>
            aliceSession.acceptAcknowledgement(envelope),
      );
      final bob = await IrohLinkTransport.bind(
        deviceId: 'bob',
        identity: iroh.SecretKey.generate(),
        onOperation: (envelope) => bobSession.receive(envelope),
        onAcknowledgement: (envelope) =>
            bobSession.acceptAcknowledgement(envelope),
      );
      aliceSession = await DurableSession.open(
        directory: p.join(temporary.path, 'alice'),
        accountId: 'alice-account',
        deviceId: 'alice',
        journalKey: List.filled(32, 1),
        cipher: aliceCipher,
        transports: [alice],
        autoStart: false,
      );
      bobSession = await DurableSession.open(
        directory: p.join(temporary.path, 'bob'),
        accountId: 'bob-account',
        deviceId: 'bob',
        journalKey: List.filled(32, 2),
        cipher: bobCipher,
        transports: [bob],
        autoStart: false,
        reducer: (previous, operation) => {
          'count': (previous['count'] as int? ?? 0) + 1,
        },
      );
      try {
        await _pinBoth(alice, bob);
        expect(alice.address.relayUrls, isEmpty);
        expect(bob.address.relayUrls, isEmpty);
        final operation = await aliceSession.enqueue(
          peerId: 'bob',
          sessionId: 'test',
          payload: {'hello': 'real QUIC'},
        );
        await aliceSession.pump();
        expect(
          aliceSession.operation(operation.operationId)!.facts,
          contains(DeliveryFact.recipientApplied),
        );
        expect(bobSession.appliedOperations.single.payload, {
          'hello': 'real QUIC',
        });
        final duplicate = await alice.deliver(operation.envelope);
        await aliceSession.acceptAcknowledgement(duplicate.acknowledgement!);
        expect(bobSession.appliedOperations.length, 1);
        await bobSession.pump();
        expect(aliceSession.operation(operation.operationId)!.applied, isTrue);
      } finally {
        await aliceSession.close();
        await bobSession.close();
      }
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'pin changes and duplicate identity mappings require explicit removal',
    () async {
      final transport = await _simpleTransport('alice');
      try {
        final id = iroh.SecretKey.generate().publicKey;
        transport.setPeer(
          IrohPeer(
            deviceId: 'bob',
            endpointId: id,
            address: iroh.EndpointAddr(id),
          ),
        );
        final replacement = iroh.SecretKey.generate().publicKey;
        expect(
          () => transport.setPeer(
            IrohPeer(
              deviceId: 'bob',
              endpointId: replacement,
              address: iroh.EndpointAddr(replacement),
            ),
          ),
          throwsA(
            isA<LinkTransportException>().having(
              (error) => error.code,
              'code',
              'peer_identity_changed',
            ),
          ),
        );
        expect(
          () => transport.setPeer(
            IrohPeer(
              deviceId: 'charlie',
              endpointId: id,
              address: iroh.EndpointAddr(id),
            ),
          ),
          throwsA(isA<LinkTransportException>()),
        );
      } finally {
        await transport.close();
      }
    },
  );

  test('unpinned peer cannot dispatch operations to application', () async {
    var invoked = false;
    final alice = await _simpleTransport('alice');
    final bob = await _simpleTransport(
      'bob',
      onOperation: (envelope) async {
        invoked = true;
        return envelope;
      },
    );
    try {
      await _waitForAddress(bob);
      alice.setPeer(
        IrohPeer(
          deviceId: 'bob',
          endpointId: bob.endpointId,
          address: bob.address,
        ),
      );
      await expectLater(
        alice.deliver(_envelope('alice', 'bob')),
        throwsA(isA<LinkTransportException>()),
      );
      expect(invoked, isFalse);
    } finally {
      await alice.close();
      await bob.close();
    }
  });

  test(
    'malicious length header is refused before body allocation or callback',
    () async {
      var invoked = false;
      final bob = await _simpleTransport(
        'bob',
        onOperation: (envelope) async {
          invoked = true;
          return envelope;
        },
      );
      final raw = await iroh.Endpoint.bindWithAddressLookup(
        resolve: (_) => null,
        relayMode: iroh.RelayMode.disabled,
      );
      iroh.Connection? connection;
      try {
        bob.setPeer(
          IrohPeer(deviceId: 'alice', endpointId: raw.id, address: raw.addr),
        );
        await _waitForAddress(bob);
        connection = await raw.connect(
          bob.address,
          utf8.encode(IrohLinkTransport.alpn),
        );
        final (send, receive) = await connection.openBi();
        final header = ByteData(4)..setUint32(0, 0xffffffff);
        await send.writeAll(header.buffer.asUint8List());
        await send.finish();
        await expectLater(
          receive.readToEnd(100).timeout(const Duration(seconds: 5)),
          throwsA(anything),
        );
        expect(invoked, isFalse);
      } finally {
        connection?.close();
        await raw.close();
        await bob.close();
      }
    },
  );

  test(
    'local sender mismatch and unknown route fail without opening network',
    () async {
      final alice = await _simpleTransport('alice');
      try {
        await expectLater(
          alice.deliver(_envelope('mallory', 'bob')),
          throwsA(isA<LinkTransportException>()),
        );
        await expectLater(
          alice.deliver(_envelope('alice', 'bob')),
          throwsA(
            isA<LinkTransportException>().having(
              (error) => error.code,
              'code',
              'peer_not_pinned',
            ),
          ),
        );
        await expectLater(alice.poll('bob'), throwsStateError);
      } finally {
        await alice.close();
      }
      await expectLater(
        alice.deliver(_envelope('alice', 'bob')),
        throwsA(isA<LinkTransportException>()),
      );
    },
  );
}

Future<IrohLinkTransport> _simpleTransport(
  String deviceId, {
  Future<EncryptedEnvelope> Function(EncryptedEnvelope)? onOperation,
}) => IrohLinkTransport.bind(
  deviceId: deviceId,
  identity: iroh.SecretKey.generate(),
  timeout: const Duration(seconds: 5),
  onOperation: onOperation ?? (envelope) async => envelope,
  onAcknowledgement: (_) async {},
);

Future<void> _pinBoth(IrohLinkTransport alice, IrohLinkTransport bob) async {
  await _waitForAddress(alice);
  await _waitForAddress(bob);
  alice.setPeer(
    IrohPeer(
      deviceId: bob.deviceId,
      endpointId: bob.endpointId,
      address: bob.address,
    ),
  );
  bob.setPeer(
    IrohPeer(
      deviceId: alice.deviceId,
      endpointId: alice.endpointId,
      address: alice.address,
    ),
  );
}

Future<void> _waitForAddress(IrohLinkTransport transport) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (transport.address.ipAddrs.isEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('No local QUIC socket address');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

EncryptedEnvelope _envelope(String sender, String recipient) =>
    EncryptedEnvelope(
      context: EnvelopeContext(
        senderId: sender,
        recipientId: recipient,
        sessionId: 'test',
        operationId: 'one',
        sequence: 1,
      ),
      nonce: List.filled(12, 0),
      ciphertext: [1],
      mac: List.filled(16, 0),
    );
