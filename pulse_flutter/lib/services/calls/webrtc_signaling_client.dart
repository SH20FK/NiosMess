import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Message types supported by Nios Calls WebRTC signaling server.
abstract class WebRtcSignalType {
  static const String auth = 'auth';
  static const String ready = 'ready';
  static const String peerJoined = 'peer_joined';
  static const String peerLeft = 'peer_left';
  static const String callEnded = 'call_ended';
  static const String offer = 'offer';
  static const String answer = 'answer';
  static const String ice = 'ice';
  static const String mediaState = 'media_state';
  static const String leave = 'leave';
  static const String heartbeat = 'heartbeat';
}

/// Information about a peer received from the signaling server.
class WebRtcPeerInfo {
  const WebRtcPeerInfo({
    required this.userId,
    required this.name,
    this.video = false,
  });

  final int userId;
  final String name;
  final bool video;

  factory WebRtcPeerInfo.fromJson(Map<String, dynamic> json) {
    return WebRtcPeerInfo(
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? 'User',
      video: json['video'] as bool? ?? false,
    );
  }
}

/// WebSocket client for Nios WebRTC signaling (c.ni-os.ru/signal).
class WebRtcSignalingClient {
  WebRtcSignalingClient({
    required this.signalUrl,
    required this.token,
  });

  final String signalUrl;
  final String token;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _heartbeatTimer;
  DateTime? _lastReceived;
  bool _connected = false;
  bool _disposed = false;
  Completer<bool>? _ready;

  int? _localUserId;
  int? get localUserId => _localUserId;

  final StreamController<Map<String, dynamic>> _messagesController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onMessage => _messagesController.stream;

  final StreamController<void> _disconnectedController =
      StreamController<void>.broadcast();

  Stream<void> get onDisconnected => _disconnectedController.stream;

  bool get isConnected => _connected;

  Future<bool>? _connecting;

  Future<bool> connect() => _connecting ??= _connect().whenComplete(() => _connecting = null);

  Future<bool> _connect() async {
    if (_connected || _disposed) return _connected;

    await _sub?.cancel();
    _sub = null;
    try { await _channel?.sink.close(); } catch (_) {}
    _channel = null;
    try {
      // The gateway authenticates the HTTP upgrade, before it accepts any
      // signaling frames. Sending an `auth` frame after connecting is too late.
      final Uri baseUri = Uri.parse(signalUrl);
      if (token.isEmpty) return false;
      final Uri uri = baseUri.replace(queryParameters: {
        ...baseUri.queryParameters,
        'token': token,
      });
      final String safeLogUrl = uri.replace(queryParameters: const {}).toString();

      debugPrint('[WebRtcSignaling] Connecting to $safeLogUrl...');
      _ready = Completer<bool>();
      _channel = WebSocketChannel.connect(uri);
      _sub = _channel!.stream.listen(
        _onDataReceived,
        onDone: _onChannelDone,
        onError: _onChannelError,
      );
      await _channel!.ready.timeout(const Duration(seconds: 10));
      if (_disposed) return false;
      if (!await _ready!.future.timeout(const Duration(seconds: 10))) {
        throw StateError('Gateway did not accept the call');
      }
      _startHeartbeat();

      debugPrint('[WebRtcSignaling] Connected successfully');
      return true;
    } catch (_) {
      // WebSocket exceptions may include the URL with its access token.
      debugPrint('[WebRtcSignaling] Connection failed');
      _connected = false;
      await _sub?.cancel();
      _sub = null;
      try {
        await _channel?.sink.close();
      } catch (_) {}
      _channel = null;
      return false;
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_connected && _lastReceived != null && DateTime.now().difference(_lastReceived!) > const Duration(seconds: 15)) {
        _handleDisconnect();
        unawaited(_channel?.sink.close());
        return;
      }
      if (_connected) {
        send({'type': WebRtcSignalType.heartbeat});
      }
    });
  }

  void _onDataReceived(dynamic raw) {
    if (raw == null) return;
    try {
      final String text = raw is String ? raw : utf8.decode(raw as List<int>);
      final dynamic decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) return;
      _lastReceived = DateTime.now();

      final String? type = decoded['type']?.toString();
      if (type == WebRtcSignalType.heartbeat) {
        // Heartbeat ACK from server, ignore
        return;
      }

      if (type == WebRtcSignalType.ready) {
        final dynamic rawId = decoded['user_id'];
        if (rawId is num) {
          _localUserId = rawId.toInt();
          _connected = !_disposed;
        }
        if (_ready != null && !_ready!.isCompleted) _ready!.complete(_connected);
      }

      if (!_messagesController.isClosed) {
        _messagesController.add(decoded);
      }
    } catch (e) {
      debugPrint('[WebRtcSignaling] Error parsing message: $e');
    }
  }

  void _onChannelDone() {
    debugPrint('[WebRtcSignaling] Socket closed');
    _handleDisconnect();
  }

  void _onChannelError(dynamic error) {
    debugPrint('[WebRtcSignaling] Socket error');
    _handleDisconnect();
  }

  void _handleDisconnect() {
    if (_disposed) return;
    _connected = false;
    if (_ready != null && !_ready!.isCompleted) _ready!.complete(false);
    _heartbeatTimer?.cancel();
    if (!_disconnectedController.isClosed) {
      _disconnectedController.add(null);
    }
  }

  void send(Map<String, dynamic> data) {
    if (!_connected || _channel == null) return;
    try {
      final String encoded = jsonEncode(data);
      _channel!.sink.add(encoded);
    } catch (e) {
      debugPrint('[WebRtcSignaling] Error sending data: $e');
    }
  }

  void sendOffer(int targetId, Map<String, dynamic> sdp) {
    send({
      'type': WebRtcSignalType.offer,
      'target_id': targetId,
      'sdp': sdp,
    });
  }

  void sendAnswer(int targetId, Map<String, dynamic> sdp) {
    send({
      'type': WebRtcSignalType.answer,
      'target_id': targetId,
      'sdp': sdp,
    });
  }

  void sendIceCandidate(int targetId, Map<String, dynamic> candidate) {
    send({
      'type': WebRtcSignalType.ice,
      'target_id': targetId,
      'candidate': candidate,
    });
  }

  void sendMediaState({required int targetId, required bool audio, required bool video}) {
    send({
      'type': WebRtcSignalType.mediaState,
      'target_id': targetId,
      'audio': audio,
      'video': video,
    });
  }

  void sendLeave() {
    send({'type': WebRtcSignalType.leave});
  }

  Future<void> disconnect() async {
    sendLeave();
    _disposed = true;
    if (_ready != null && !_ready!.isCompleted) _ready!.complete(false);
    _connected = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    await _sub?.cancel();
    _sub = null;

    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;

    if (!_messagesController.isClosed) {
      await _messagesController.close();
    }
    if (!_disconnectedController.isClosed) {
      await _disconnectedController.close();
    }
  }
}
