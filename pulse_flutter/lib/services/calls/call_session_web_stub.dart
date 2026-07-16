import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'call_session_types.dart';
import 'call_transport.dart';
import 'video_output_pipeline.dart';

// ignore: use_key_in_widget_constructors
class CallSession {
  CallSession({
    required this.chatId,
    required this.callId,
    required this.roomId,
    required this.isVideo,
    required this.direction,
    required this.displayName,
    required this.aesKeyBytes,
  });

  final int chatId;
  final int callId;
  final String roomId;
  final bool isVideo;
  final CallDirection direction;
  final String displayName;
  final Uint8List aesKeyBytes;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  final bool isSelfVideoEnabled = false;

  VideoOutputPipeline? get videoOutput => null;

  CallSessionData get currentData => CallSessionData(
    state: CallSessionState.idle,
    callId: callId,
    isVideo: isVideo,
    durationSeconds: 0,
    isMuted: _isMuted,
    isSpeakerOn: _isSpeakerOn,
  );

  Stream<CallSessionData> get stateStream => const Stream.empty();

  Future<void> start({bool preferQuic = false}) async {
    debugPrint('[CallSession] Web stub — calls not supported');
  }

  void setMuted(bool muted) {
    _isMuted = muted;
  }
  void setSpeakerOn(bool on) {
    _isSpeakerOn = on;
  }
  Future<void> switchCamera() async {}
  Future<void> end() async {}
  void dispose() {}
}
