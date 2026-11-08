import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:nios_iroh/nios_iroh.dart';
import 'package:nios_sdk/link.dart';
import 'package:test/test.dart';

final class _MockMeshFallback implements LinkMeshFallback {
  bool canReachPeer = true;
  final _incoming = StreamController<EncryptedEnvelope>.broadcast();
  bool closed = false;

  @override
  Future<bool> canReach(String peerDeviceId) async => canReachPeer;

  @override
  Future<EncryptedEnvelope> deliverEnvelope(EncryptedEnvelope envelope) async {
    return EncryptedEnvelope(
      context: EnvelopeContext(
        kind: 'ack',
        senderId: envelope.context.recipientId,
        recipientId: envelope.context.senderId,
        sessionId: envelope.context.sessionId,
        operationId: envelope.context.operationId,
        sequence: envelope.context.sequence,
      ),
      nonce: Uint8List(12),
      ciphertext: Uint8List.fromList(utf8.encode('ack-from-ble-mesh')),
      mac: Uint8List(16),
    );
  }

  @override
  Future<void> publishAcknowledgement(EncryptedEnvelope acknowledgement) async {}

  @override
  Stream<EncryptedEnvelope> get incoming => _incoming.stream;

  @override
  Future<void> close() async {
    closed = true;
    await _incoming.close();
  }
}

void main() {
  group('HybridMeshTransport (Iroh QUIC + Bluetooth LE / Relay Fallback)', () {
    test('routes to BLE mesh when direct P2P dial fails', () async {
      await Iroh.init();
      final aliceSecret = SecretKey.generate();
      final aliceEndpoint = await IrohLinkTransport.bind(
        deviceId: 'alice-dev',
        identity: aliceSecret,
        onOperation: (env) async => env,
        onAcknowledgement: (_) async {},
      );

      final mesh = _MockMeshFallback();
      final hybrid = HybridMeshTransport(
        irohTransport: aliceEndpoint,
        meshFallback: mesh,
        directP2pTimeout: const Duration(milliseconds: 100),
        relayPolicy: IrohRelayPolicy.directOnly,
      );

      final testEnvelope = EncryptedEnvelope(
        context: EnvelopeContext(
          kind: 'operation',
          senderId: 'alice-dev',
          recipientId: 'bob-unreachable-dev',
          sessionId: 'test-session',
          operationId: 'op-mesh-test-1',
          sequence: 1,
        ),
        nonce: Uint8List(12),
        ciphertext: Uint8List(16),
        mac: Uint8List(16),
      );

      // Alice doesn't know Bob's QUIC pin, so direct P2P fails and falls back to BLE mesh!
      final receipt = await hybrid.deliver(testEnvelope);
      expect(receipt.acknowledgement, isNotNull);
      final ack = receipt.acknowledgement!;
      expect(ack.context.recipientId, 'alice-dev');
      expect(utf8.decode(ack.ciphertext), 'ack-from-ble-mesh');
      expect(hybrid.activeRoute('bob-unreachable-dev'), MeshActiveRoute.bluetoothMesh);

      await hybrid.close();
      expect(mesh.closed, isTrue);
    });
  });
}
