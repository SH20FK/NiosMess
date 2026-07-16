import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pure_dart_quic/connection/client/quic_session3.dart';

import 'call_transport.dart';

/// WebTransport (QUIC/UDP) implementation of [CallTransport].
///
/// Connects to the NiosCalls SFU via WebTransport at c.ni-os.ru:4433.
/// Falls back gracefully since QUIC/WebTransport may not be available
/// on all network paths.
///
/// Requires UDP connectivity to port 4433.
class QuicCallTransport implements CallTransport {
  QuicCallTransport();

  QuicSession? _session;
  int? _webTransportSessionId;
  bool _connected = false;
  RawDatagramSocket? _udpSocket;

  final StreamController<void> _connectedController =
      StreamController<void>.broadcast();
  final StreamController<void> _disconnectedController =
      StreamController<void>.broadcast();
  final StreamController<Uint8List> _packetController =
      StreamController<Uint8List>.broadcast();

  @override
  Stream<void> get onConnected => _connectedController.stream;
  @override
  Stream<void> get onDisconnected => _disconnectedController.stream;
  @override
  Stream<Uint8List> get onPacketReceived => _packetController.stream;

  @override
  Future<TransportConnectResult> connect({
    required String roomId,
    required String nickname,
  }) async {
    try {
      final address = (await InternetAddress.lookup('c.ni-os.ru')).first;
      _udpSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
      );
      _udpSocket!.listen(_onUdpPacket);

      final dcid = Uint8List.fromList(
        List<int>.generate(8, (_) => DateTime.now().millisecondsSinceEpoch & 0xFF),
      );
      _session = QuicSession(dcid, _udpSocket!);

      _session!.sendClientHello(
        address: address,
        port: 4433,
        authority: 'c.ni-os.ru',
      );

      _connected = true;
      _connectedController.add(null);
      return TransportConnectResult.connected;
    } catch (e) {
      debugPrint('[QuicTransport] Connect failed: $e');
      _cleanup();
      return TransportConnectResult.failed;
    }
  }

  void _onUdpPacket(RawSocketEvent event) {
    if (_udpSocket == null || _session == null) return;
    final packet = _udpSocket!.receive();
    if (packet == null) return;
    try {
      _session!.handleQuicPacket(packet.data);
    } catch (e) {
      debugPrint('[QuicTransport] Packet error: $e');
    }
  }

  @override
  Future<void> send(Uint8List data) async {
    if (_session == null || _webTransportSessionId == null) return;
    _session!.sendWebTransportDatagram(
      _webTransportSessionId!,
      data,
      port: 4433,
    );
  }

  @override
  Future<void> sendDatagram(Uint8List data) async {
    if (_session == null || _webTransportSessionId == null) return;
    _session!.sendWebTransportDatagram(
      _webTransportSessionId!,
      data,
      port: 4433,
    );
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _cleanup();
    _disconnectedController.add(null);
  }

  void _cleanup() {
    _webTransportSessionId = null;
    _session = null;
    _udpSocket?.close();
    _udpSocket = null;
  }

  @override
  bool get isConnected => _connected;

  @override
  bool get isUdp => true;

  void dispose() {
    _connected = false;
    _cleanup();
    _connectedController.close();
    _disconnectedController.close();
    _packetController.close();
  }
}
