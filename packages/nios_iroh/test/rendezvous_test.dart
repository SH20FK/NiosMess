import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart' as crypto;
import 'package:iroh_quic/iroh_quic.dart' as iroh;
import 'package:nios_iroh/nios_iroh.dart';
import 'package:nios_sdk/link.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  setUpAll(() async => iroh.Iroh.init());

  test(
    'signed discovery supplies real native QUIC peers without a relay',
    () async {
      final fixture = await _Directory.bind();
      final aliceSecret = iroh.SecretKey.generate();
      final bobSecret = iroh.SecretKey.generate();
      final aliceLink = await crypto.Ed25519().newKeyPair();
      final bobLink = await crypto.Ed25519().newKeyPair();
      fixture.links['alice'] = await aliceLink.extractPublicKey();
      fixture.links['bob'] = await bobLink.extractPublicKey();
      final alice = await IrohLinkTransport.bind(
        deviceId: 'alice',
        identity: aliceSecret,
        onOperation: (envelope) async => _ack(envelope),
        onAcknowledgement: (_) async {},
      );
      final bob = await IrohLinkTransport.bind(
        deviceId: 'bob',
        identity: bobSecret,
        onOperation: (envelope) async => _ack(envelope),
        onAcknowledgement: (_) async {},
      );
      final a = _client(fixture.uri, 'alice');
      final b = _client(fixture.uri, 'bob');
      try {
        await _waitAddress(alice);
        await _waitAddress(bob);
        await a.publish(
          address: alice.address,
          endpointIdentity: aliceSecret,
          linkSigningKey: aliceLink,
          revision: 1,
        );
        await b.publish(
          address: bob.address,
          endpointIdentity: bobSecret,
          linkSigningKey: bobLink,
          revision: 1,
        );
        final bobPublication = await a.lookup(
          peerAccountId: 'account-bob',
          peerDeviceId: 'bob',
          pinnedEndpointId: bob.endpointId,
          pinnedLinkSigningKey: await bobLink.extractPublicKey(),
          chatId: 77,
        );
        final alicePublication = await b.lookup(
          peerAccountId: 'account-alice',
          peerDeviceId: 'alice',
          pinnedEndpointId: alice.endpointId,
          pinnedLinkSigningKey: await aliceLink.extractPublicKey(),
          chatId: 77,
        );
        alice.setPeer(bobPublication.peer);
        bob.setPeer(alicePublication.peer);
        final receipt = await alice.deliver(_operation());
        expect(receipt.acknowledgement!.context.kind, 'ack');
        expect(bobPublication.revision, 1);
        expect(bobPublication.peer.address.relayUrls, isEmpty);
        expect(fixture.verifiedPublications, 2);
      } finally {
        await a.close();
        await b.close();
        await alice.close();
        await bob.close();
        await fixture.close();
      }
    },
  );

  test(
    'lookup rejects replay, forged signatures and wrong decoded identity',
    () async {
      final fixture = await _Directory.bind();
      final identity = iroh.SecretKey.generate();
      final link = await crypto.Ed25519().newKeyPair();
      fixture.links['bob'] = await link.extractPublicKey();
      final bob = _client(fixture.uri, 'bob');
      final alice = _client(fixture.uri, 'alice');
      try {
        await bob.publish(
          address: iroh.EndpointAddr(
            identity.publicKey,
            ipAddrs: ['127.0.0.1:1234'],
          ),
          endpointIdentity: identity,
          linkSigningKey: link,
          revision: 1,
        );
        final pin = await link.extractPublicKey();
        Future<IrohAddressPublication> lookup({int minimum = 0}) =>
            alice.lookup(
              peerAccountId: 'account-bob',
              peerDeviceId: 'bob',
              pinnedEndpointId: identity.publicKey,
              pinnedLinkSigningKey: pin,
              chatId: 77,
              minimumRevision: minimum,
            );
        await expectLater(
          lookup(minimum: 2),
          throwsA(isA<LinkTransportException>()),
        );
        final original = Map<String, dynamic>.from(fixture.records['bob']!);
        fixture.records['bob']!['device_signature'] = base64Encode(
          List.filled(64, 0),
        );
        await expectLater(lookup(), throwsA(isA<LinkTransportException>()));
        fixture.records['bob'] = Map.from(original);
        fixture.records['bob']!['address'] = base64Encode(
          iroh.EndpointAddr(iroh.SecretKey.generate().publicKey).encode(),
        );
        final value = fixture.records['bob']!;
        final message = _signing('account-bob', 'bob', value);
        value['signature'] = base64Encode(identity.sign(message).toBytes());
        value['device_signature'] = base64Encode(
          (await crypto.Ed25519().sign(message, keyPair: link)).bytes,
        );
        await expectLater(lookup(), throwsA(isA<LinkTransportException>()));
        fixture.records['bob'] = Map.from(original);
        fixture.records['bob']!['expires'] = 0;
        await expectLater(lookup(), throwsA(isA<LinkTransportException>()));
        expect(
          () => IrohRendezvousClient(
            baseUri: Uri.parse('http://remote.example'),
            accountId: 'a',
            deviceId: 'a',
            bearerToken: 't',
            allowInsecureLoopback: true,
          ),
          throwsArgumentError,
        );
      } finally {
        await alice.close();
        await bob.close();
        await fixture.close();
      }
    },
  );
  test(
    'account close aborts stalled discovery and relay URLs require opt-in',
    () async {
      final received = Completer<void>();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) {
        if (!received.isCompleted) received.complete();
        // Keep this authenticated request pending until the account closes.
      });
      final client = _client(
        Uri.parse('http://127.0.0.1:${server.port}'),
        'alice',
      );
      final identity = iroh.SecretKey.generate();
      final link = await crypto.Ed25519().newKeyPair();
      try {
        await expectLater(
          client.publish(
            address: iroh.EndpointAddr(
              identity.publicKey,
              relayUrls: [iroh.RelayUrl.parse('https://relay.example')],
            ),
            endpointIdentity: identity,
            linkSigningKey: link,
            revision: 1,
          ),
          throwsA(isA<LinkTransportException>()),
        );
        final lookup = client.lookup(
          peerAccountId: 'account-bob',
          peerDeviceId: 'bob',
          pinnedEndpointId: identity.publicKey,
          pinnedLinkSigningKey: await link.extractPublicKey(),
          chatId: 77,
        );
        final failed = expectLater(lookup, throwsA(anything));
        await received.future.timeout(const Duration(seconds: 3));
        await client.close();
        await failed.timeout(const Duration(seconds: 3));
      } finally {
        await client.close();
        await server.close(force: true);
      }
    },
  );
}

IrohRendezvousClient _client(Uri uri, String device) => IrohRendezvousClient(
  baseUri: uri,
  accountId: 'account-$device',
  deviceId: device,
  bearerToken: 'token-$device',
  allowInsecureLoopback: true,
);

List<int> _signing(String account, String device, Map<String, dynamic> body) =>
    utf8.encode(
      jsonEncode([
        'nios-iroh-address',
        1,
        account,
        device,
        body['endpoint_key'],
        body['revision'],
        body['expires'],
        body['address'],
      ]),
    );

final class _Directory {
  _Directory(this.server) {
    server.listen(_handle);
  }
  final HttpServer server;
  final records = <String, Map<String, dynamic>>{};
  final links = <String, crypto.SimplePublicKey>{};
  var verifiedPublications = 0;
  Uri get uri => Uri.parse('http://127.0.0.1:${server.port}');
  static Future<_Directory> bind() async =>
      _Directory(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));
  Future<void> _handle(HttpRequest request) async {
    final device = request.headers
        .value('authorization')
        ?.replaceFirst('Bearer token-', '');
    if (device != 'alice' && device != 'bob') {
      request.response.statusCode = 401;
    } else if (request.method == 'PUT') {
      final value =
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>;
      final signing = _signing('account-$device', device!, value);
      final endpoint = iroh.PublicKey.fromBytes(
        base64Decode(value['endpoint_key'] as String),
      );
      final valid =
          endpoint.verify(
            signing,
            iroh.Signature.fromBytes(
              base64Decode(value['signature'] as String),
            ),
          ) &&
          await crypto.Ed25519().verify(
            signing,
            signature: crypto.Signature(
              base64Decode(value['device_signature'] as String),
              publicKey: links[device]!,
            ),
          );
      if (!valid) {
        request.response.statusCode = 403;
      } else {
        verifiedPublications++;
        records[device] = {
          'account': 'account-$device',
          'device': device,
          ...value,
        };
        request.response.write(
          jsonEncode({'stored': true, 'revision': value['revision']}),
        );
      }
    } else {
      final target = request.uri.pathSegments[3];
      request.response.write(jsonEncode(records[target]));
    }
    await request.response.close();
  }

  Future<void> close() => server.close(force: true);
}

Future<void> _waitAddress(IrohLinkTransport transport) async {
  for (var i = 0; i < 500; i++) {
    if (transport.address.ipAddrs.isNotEmpty) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  throw StateError('native_iroh_address_unavailable');
}

EncryptedEnvelope _operation() => EncryptedEnvelope(
  context: const EnvelopeContext(
    senderId: 'alice',
    recipientId: 'bob',
    sessionId: 'test',
    operationId: 'one',
    sequence: 1,
  ),
  nonce: List.filled(12, 0),
  ciphertext: [1],
  mac: List.filled(16, 0),
);

EncryptedEnvelope _ack(EncryptedEnvelope operation) => EncryptedEnvelope(
  context: EnvelopeContext(
    senderId: operation.context.recipientId,
    recipientId: operation.context.senderId,
    sessionId: operation.context.sessionId,
    operationId: operation.context.operationId,
    sequence: operation.context.sequence,
    kind: 'ack',
  ),
  nonce: List.filled(12, 0),
  ciphertext: [2],
  mac: List.filled(16, 0),
);
