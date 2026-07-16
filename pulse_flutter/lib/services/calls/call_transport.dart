import 'dart:async';
import 'dart:typed_data';

/// Result of a transport connection attempt.
enum TransportConnectResult { connected, fallback, failed }

/// Abstract transport layer for NiosCalls.
///
/// Hides the difference between WebTransport (UDP) and WebSocket (TCP)
/// from the business logic.
abstract class CallTransport {
  Stream<void> get onConnected;
  Stream<void> get onDisconnected;
  Stream<Uint8List> get onPacketReceived;

  /// Connect to the NiosCalls SFU.
  Future<TransportConnectResult> connect({
    required String roomId,
    required String nickname,
  });

  /// Send a binary packet.
  Future<void> send(Uint8List data);

  /// Send a packet via WebTransport Datagram (small packets only).
  /// Falls back to send() if not using WebTransport.
  Future<void> sendDatagram(Uint8List data);

  /// Disconnect and release resources.
  Future<void> disconnect();

  /// Whether this transport is currently connected.
  bool get isConnected;

  /// Whether this transport uses UDP (WebTransport) or TCP (WebSocket).
  bool get isUdp;
}
