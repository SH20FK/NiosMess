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
    required this.isMuted,
    required this.isSpeakerOn,
    required this.isSelfVideoEnabled,
    required this.isVideo,
    required this.durationSeconds,
    this.remoteParticipants = const [],
  });

  final CallSessionState state;
  final bool isMuted;
  final bool isSpeakerOn;
  final bool isSelfVideoEnabled;
  final bool isVideo;
  final int durationSeconds;
  final List<RemoteParticipant> remoteParticipants;

  CallSessionData copyWith({
    CallSessionState? state,
    bool? isMuted,
    bool? isSpeakerOn,
    bool? isSelfVideoEnabled,
    bool? isVideo,
    int? durationSeconds,
    List<RemoteParticipant>? remoteParticipants,
  }) {
    return CallSessionData(
      state: state ?? this.state,
      isMuted: isMuted ?? this.isMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      isSelfVideoEnabled: isSelfVideoEnabled ?? this.isSelfVideoEnabled,
      isVideo: isVideo ?? this.isVideo,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      remoteParticipants: remoteParticipants ?? this.remoteParticipants,
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
