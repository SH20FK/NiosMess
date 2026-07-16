import 'dart:typed_data';

/// Direction of the call relative to the local user.
enum CallDirection { incoming, outgoing }

/// Current state in the call lifecycle.
enum CallSessionState {
  idle,
  connecting,
  connected,
  inCall,
  reconnecting,
  ended,
}

/// Snapshot of call state emitted via [stateStream].
class CallSessionData {
  const CallSessionData({
    required this.state,
    required this.callId,
    this.roomId,
    required this.isVideo,
    this.direction,
    this.localClientId,
    this.isMuted = false,
    this.isSpeakerOn = false,
    this.isSelfVideoEnabled = false,
    required this.durationSeconds,
    this.remoteParticipants = const [],
    this.verificationEmojis = const [],
  });

  final CallSessionState state;
  final int callId;
  final String? roomId;
  final bool isVideo;
  final CallDirection? direction;
  final int? localClientId;
  final bool isMuted;
  final bool isSpeakerOn;
  final bool isSelfVideoEnabled;
  final int durationSeconds;
  final List<RemoteParticipant> remoteParticipants;
  final List<String> verificationEmojis;

  CallSessionData copyWith({
    CallSessionState? state,
    int? callId,
    String? roomId,
    bool? isVideo,
    CallDirection? direction,
    int? localClientId,
    bool? isMuted,
    bool? isSpeakerOn,
    bool? isSelfVideoEnabled,
    int? durationSeconds,
    List<RemoteParticipant>? remoteParticipants,
    List<String>? verificationEmojis,
  }) {
    return CallSessionData(
      state: state ?? this.state,
      callId: callId ?? this.callId,
      roomId: roomId ?? this.roomId,
      isVideo: isVideo ?? this.isVideo,
      direction: direction ?? this.direction,
      localClientId: localClientId ?? this.localClientId,
      isMuted: isMuted ?? this.isMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      isSelfVideoEnabled: isSelfVideoEnabled ?? this.isSelfVideoEnabled,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      remoteParticipants: remoteParticipants ?? this.remoteParticipants,
      verificationEmojis: verificationEmojis ?? this.verificationEmojis,
    );
  }
}

/// A remote participant in the call.
class RemoteParticipant {
  const RemoteParticipant({
    required this.clientId,
    required this.nickname,
  });

  final int clientId;
  final String nickname;
}

/// Callback: outgoing audio frame (Opus) to send.
typedef SendAudioCallback = void Function(Uint8List opusData);

/// Callback: outgoing video frame to send.
typedef SendVideoCallback = void Function(
    Uint8List data, int frameType, double timestamp);

// AbstractCallSession intentionally omitted.
// CallSession is a concrete class defined in the platform-specific
// implementation files (call_session_io.dart / call_session_web_stub.dart).
// Both expose the same public API.
