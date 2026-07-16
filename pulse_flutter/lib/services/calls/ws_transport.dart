import 'dart:async';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'call_transport.dart';

/// WebSocket (TCP) implementation of [CallTransport].
///
/// Connects to the NiosCalls SFU via WebSocket at wss://c.ni-os.ru/ws
class WsCallTransport implements CallTransport {
  WsCallTransport();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  bool _connected = false;

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
      final Uri uri = Uri.parse(
        'wss://c.ni-os.ru:8765/ws?room=$roomId&nick=${Uri.encodeComponent(nickname)}',
      );
      _channel = WebSocketChannel.connect(uri);

      await _channel!.ready;
      _connected = true;

      _subscription = _channel!.stream.listen(
        (dynamic data) {
          if (data is List<int>) {
            _packetController.add(Uint8List.fromList(data));
          } else if (data is ByteBuffer) {
            _packetController.add(data.asUint8List());
          }
        },
        onDone: () {
          _connected = false;
          _disconnectedController.add(null);
        },
        onError: (Object e) {
          _connected = false;
          _disconnectedController.add(null);
        },
      );

      _connectedController.add(null);
      return TransportConnectResult.connected;
    } catch (_) {
      return TransportConnectResult.failed;
    }
  }

  @override
  Future<void> send(Uint8List data) async {
    if (_channel == null || !_connected) return;
    _channel!.sink.add(data);
  }

  @override
  Future<void> sendDatagram(Uint8List data) => send(data);

  @override
  Future<void> disconnect() async {
    await _subscription?.cancel();
    await _channel?.sink.close();
    _connected = false;
    _disconnectedController.add(null);
  }

  @override
  bool get isConnected => _connected;

  @override
  bool get isUdp => false;

  void dispose() {
    _subscription?.cancel();
    _channel?.sink.close();
    _connectedController.close();
    _disconnectedController.close();
    _packetController.close();
  }
}
