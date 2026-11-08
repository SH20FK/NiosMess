import 'dart:async';

import 'package:nios_sdk/link.dart';
import 'transport.dart';

/// Policy for DERP (Designated Encrypted Relay for Packets) relay usage.
enum IrohRelayPolicy {
  /// Only attempt direct peer-to-peer connections.
  directOnly,

  /// Always use DERP relay as primary route.
  relayPreferred,

  /// Attempt direct P2P first with fallback timeout, then route via DERP relay.
  adaptive,
}

/// Abstract contract for local mesh fallback transport (Bluetooth LE, LoRa, local WiFi).
abstract interface class LinkMeshFallback {
  /// Check whether the target peer device is currently reachable over local mesh.
  Future<bool> canReach(String peerDeviceId);

  /// Deliver an encrypted envelope over local mesh link and receive the signed ACK.
  Future<EncryptedEnvelope> deliverEnvelope(EncryptedEnvelope envelope);

  /// Publish a reverse ACK over local mesh link.
  Future<void> publishAcknowledgement(EncryptedEnvelope acknowledgement);

  /// Stream of incoming envelopes received from the local mesh.
  Stream<EncryptedEnvelope> get incoming;

  /// Close and release local mesh resources.
  Future<void> close();
}

/// Active route channel identified for a peer.
enum MeshActiveRoute { quicDirect, quicRelay, bluetoothMesh, unreachable }

/// Hybrid transport that combines:
/// 1. Direct Iroh QUIC peer-to-peer streams (sub-millisecond latency when local/hole-punched).
/// 2. DERP relay fallback for symmetric/carrier-grade NATs.
/// 3. Bluetooth LE offline mesh fallback when internet and relays are unreachable.
final class HybridMeshTransport implements LinkTransport {
  final IrohLinkTransport irohTransport;
  final LinkMeshFallback? meshFallback;
  final IrohRelayPolicy relayPolicy;
  final Duration directP2pTimeout;

  final Map<String, MeshActiveRoute> _activeRoutes = {};
  final _routeTransitions = StreamController<String>.broadcast();
  StreamSubscription<EncryptedEnvelope>? _meshSubscription;
  bool _closed = false;

  HybridMeshTransport({
    required this.irohTransport,
    this.meshFallback,
    this.relayPolicy = IrohRelayPolicy.adaptive,
    this.directP2pTimeout = const Duration(milliseconds: 1200),
    Future<EncryptedEnvelope> Function(EncryptedEnvelope)? onMeshEnvelope,
  }) {
    if (meshFallback != null && onMeshEnvelope != null) {
      _meshSubscription = meshFallback!.incoming.listen((envelope) async {
        try {
          final sender = envelope.context.senderId;
          _activeRoutes[sender] = MeshActiveRoute.bluetoothMesh;
          _routeTransitions.add('rx:mesh:$sender');
          await onMeshEnvelope(envelope);
        } catch (_) {}
      });
    }
  }

  Stream<String> get routeDiagnostics => _routeTransitions.stream;

  MeshActiveRoute activeRoute(String peerDeviceId) =>
      _activeRoutes[peerDeviceId] ?? MeshActiveRoute.unreachable;

  @override
  Future<TransportReceipt> deliver(EncryptedEnvelope envelope) async {
    if (_closed) throw StateError('HybridMeshTransport is closed');

    final peerId = envelope.context.recipientId;

    // 1. If relayPolicy is relayPreferred, attempt QUIC directly
    if (relayPolicy == IrohRelayPolicy.relayPreferred) {
      try {
        final receipt = await irohTransport.deliver(envelope);
        _setRoute(peerId, MeshActiveRoute.quicRelay);
        return receipt;
      } catch (e) {
        return _fallbackDeliver(peerId, envelope, e);
      }
    }

    // 2. Adaptive or Direct: Try Direct QUIC within bounded timeout
    try {
      final receipt = await irohTransport
          .deliver(envelope)
          .timeout(directP2pTimeout);
      _setRoute(peerId, MeshActiveRoute.quicDirect);
      return receipt;
    } on TimeoutException catch (e) {
      _routeTransitions.add('timeout:direct:$peerId');
      if (relayPolicy == IrohRelayPolicy.adaptive) {
        try {
          final receipt = await irohTransport.deliver(envelope);
          _setRoute(peerId, MeshActiveRoute.quicRelay);
          return receipt;
        } catch (_) {
          return _fallbackDeliver(peerId, envelope, e);
        }
      }
      return _fallbackDeliver(peerId, envelope, e);
    } catch (e) {
      if (relayPolicy == IrohRelayPolicy.adaptive) {
        try {
          final receipt = await irohTransport.deliver(envelope);
          _setRoute(peerId, MeshActiveRoute.quicRelay);
          return receipt;
        } catch (_) {
          return _fallbackDeliver(peerId, envelope, e);
        }
      }
      return _fallbackDeliver(peerId, envelope, e);
    }
  }

  Future<TransportReceipt> _fallbackDeliver(
    String peerId,
    EncryptedEnvelope envelope,
    Object originalError,
  ) async {
    if (meshFallback != null) {
      final canMesh = await meshFallback!
          .canReach(peerId)
          .catchError((_) => false);
      if (canMesh) {
        try {
          final ack = await meshFallback!.deliverEnvelope(envelope);
          _setRoute(peerId, MeshActiveRoute.bluetoothMesh);
          return TransportReceipt(acknowledgement: ack);
        } catch (_) {}
      }
    }
    _setRoute(peerId, MeshActiveRoute.unreachable);
    throw originalError;
  }

  @override
  Future<void> publishAcknowledgement(EncryptedEnvelope acknowledgement) async {
    if (_closed) throw StateError('HybridMeshTransport is closed');
    final peerId = acknowledgement.context.recipientId;
    if (_activeRoutes[peerId] == MeshActiveRoute.bluetoothMesh &&
        meshFallback != null) {
      try {
        await meshFallback!.publishAcknowledgement(acknowledgement);
        return;
      } catch (_) {}
    }
    await irohTransport.publishAcknowledgement(acknowledgement);
  }

  @override
  Future<List<EncryptedEnvelope>> poll(String deviceId) =>
      irohTransport.poll(deviceId);

  @override
  Future<void> confirmReceived(EncryptedEnvelope envelope) =>
      irohTransport.confirmReceived(envelope);

  void _setRoute(String peerId, MeshActiveRoute route) {
    if (_activeRoutes[peerId] != route) {
      _activeRoutes[peerId] = route;
      _routeTransitions.add('route:$peerId:${route.name}');
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _meshSubscription?.cancel();
    await meshFallback?.close();
    await irohTransport.close();
    await _routeTransitions.close();
  }
}
