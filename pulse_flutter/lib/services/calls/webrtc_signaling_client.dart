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
  bool _connected = false;
  bool _disposed = false;

  int? _localUserId;
  int? get localUserId => _localUserId;

  final StreamController<Map<String, dynamic>> _messagesController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onMessage => _messagesController.stream;

  final StreamController<void> _disconnectedController =
      StreamController<void>.broadcast();

  Stream<void> get onDisconnected => _disconnectedController.stream;

  bool get isConnected => _connected;

  Future<bool> connect() async {
    if (_connected || _disposed) return _connected;

    try {
      final Uri uri = Uri.parse(signalUrl);
      final String safeLogUrl = uri.replace(queryParameters: const {}).toString();

      debugPrint('[WebRtcSignaling] Connecting to $safeLogUrl...');
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready.timeout(const Duration(seconds: 10));

      _connected = true;
      if (token.isNotEmpty) {
        send(<String, dynamic>{
          'type': WebRtcSignalType.auth,
          'token': token,
        });
      }
      _startHeartbeat();

      _sub = _channel!.stream.listen(
        _onDataReceived,
        onDone: _onChannelDone,
        onError: _onChannelError,
      );

      debugPrint('[WebRtcSignaling] Connected successfully');
      return true;
    } catch (e) {
      debugPrint('[WebRtcSignaling] Connection failed: $e');
      _connected = false;
      return false;
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
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

      final String? type = decoded['type']?.toString();
      if (type == WebRtcSignalType.heartbeat) {
        // Heartbeat ACK from server, ignore
        return;
      }

      if (type == WebRtcSignalType.ready) {
        final dynamic rawId = decoded['user_id'];
        if (rawId is num) {
          _localUserId = rawId.toInt();
        }
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
    debugPrint('[WebRtcSignaling] Socket error: $error');
    _handleDisconnect();
  }

  void _handleDisconnect() {
    if (!_connected && _disposed) return;
    _connected = false;
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

  void sendMediaState({required bool audio, required bool video}) {
    send({
      'type': WebRtcSignalType.mediaState,
      'audio': audio,
      'video': video,
    });
  }

  void sendLeave() {
    send({'type': WebRtcSignalType.leave});
  }

  Future<void> disconnect() async {
    _disposed = true;
    _connected = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    try {
      sendLeave();
    } catch (_) {}

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
