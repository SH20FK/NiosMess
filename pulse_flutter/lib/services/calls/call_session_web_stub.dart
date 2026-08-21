import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import 'call_session_types.dart';
import 'call_transport.dart';
import 'video_output_pipeline.dart';
import 'ws_transport.dart';

class CallSession {
  CallSession({
    required this.chatId,
    required this.callId,
    required this.roomId,
    required this.isVideo,
    required this.direction,
    required this.displayName,
    this.peerName,
    required this.aesKeyBytes,
    this.onCameraReady,
  });

  final int chatId;
  final int callId;
  final String roomId;
  final bool isVideo;
  final CallDirection direction;
  final String displayName;
  final String? peerName;
  final Uint8List aesKeyBytes;
  final void Function(CameraController?)? onCameraReady;

  final WsCallTransport _transport = WsCallTransport();
  final StreamController<CallSessionData> _stateController =
      StreamController<CallSessionData>.broadcast();

  CallSessionState _state = CallSessionState.idle;
  int _durationSeconds = 0;
  Timer? _durationTimer;
  StreamSubscription<void>? _connSub;
  StreamSubscription<void>? _disconnSub;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isSelfVideoEnabled = false;

  VideoOutputPipeline? get videoOutput => null;
  bool get isSelfVideoEnabled => _isSelfVideoEnabled;

  CallSessionData get currentData => CallSessionData(
        state: _state,
        callId: callId,
        roomId: roomId,
        isVideo: isVideo,
        direction: direction,
        peerName: peerName,
        isMuted: _isMuted,
        isSpeakerOn: _isSpeakerOn,
        isSelfVideoEnabled: _isSelfVideoEnabled,
        durationSeconds: _durationSeconds,
      );

  Stream<CallSessionData> get stateStream => _stateController.stream;

  void _emitState() {
    if (!_stateController.isClosed) {
      _stateController.add(currentData);
    }
  }

  Future<void> start({bool preferQuic = false}) async {
    _state = CallSessionState.connecting;
    _emitState();

    _connSub = _transport.onConnected.listen((_) {
      _state = CallSessionState.inCall;
      _durationTimer?.cancel();
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _durationSeconds++;
        _emitState();
      });
      _emitState();
    });

    _disconnSub = _transport.onDisconnected.listen((_) {
      _durationTimer?.cancel();
      _state = CallSessionState.ended;
      _emitState();
    });

    final result = await _transport.connect(
      roomId: roomId,
      nickname: displayName,
    );

    if (result == TransportConnectResult.failed) {
      _state = CallSessionState.ended;
      _emitState();
    }
  }

  void setMuted(bool muted) {
    _isMuted = muted;
    _emitState();
  }

  void setSpeakerOn(bool on) {
    _isSpeakerOn = on;
    _emitState();
  }

  Future<void> setLocalVideoEnabled(bool enabled) async {
    _isSelfVideoEnabled = enabled;
    _emitState();
  }

  Future<void> switchCamera() async {}

  Future<void> end() async {
    _durationTimer?.cancel();
    _state = CallSessionState.ended;
    _emitState();
    await _transport.disconnect();
  }

  void dispose() {
    _durationTimer?.cancel();
    _connSub?.cancel();
    _disconnSub?.cancel();
    _transport.dispose();
    if (!_stateController.isClosed) {
      _stateController.close();
    }
  }
}
