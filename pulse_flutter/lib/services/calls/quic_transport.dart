import 'dart:async';
import 'dart:typed_data';

import 'call_transport.dart';

class QuicCallTransport implements CallTransport {
  @override
  Stream<void> get onConnected => _connectedController.stream;
  @override
  Stream<void> get onDisconnected => _disconnectedController.stream;
  @override
  Stream<Uint8List> get onPacketReceived => _packetController.stream;

  final StreamController<void> _connectedController = StreamController<void>.broadcast();
  final StreamController<void> _disconnectedController = StreamController<void>.broadcast();
  final StreamController<Uint8List> _packetController = StreamController<Uint8List>.broadcast();

  @override
  Future<TransportConnectResult> connect({
    required String roomId,
    required String nickname,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _disconnectedController.add(null);
    return TransportConnectResult.failed;
  }

  @override
  Future<void> send(Uint8List data) async {}

  @override
  Future<void> sendDatagram(Uint8List data) async {}

  @override
  Future<void> disconnect() async {
    await _connectedController.close();
    await _disconnectedController.close();
    await _packetController.close();
  }

  @override
  bool get isConnected => false;

  @override
  bool get isUdp => true;
}
