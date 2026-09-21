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
    // This transport has no backend yet, so it must NOT report a
    // disconnect: nothing ever connected. A spurious onDisconnected made
    // CallSession spawn a second (WS) transport while the first was still
    // being awaited, which left two audio pipelines running (doubled audio,
    // reset duration timer).
    await Future<void>.delayed(const Duration(milliseconds: 100));
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
