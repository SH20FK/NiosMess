import 'dart:typed_data';

import '../audio/voice_filter_preset.dart';
import 'call_quality.dart';

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
    this.isGroup = false,
    this.direction,
    this.localClientId,
    this.peerName,
    this.peerAvatarUrl,
    this.peerUsername,
    this.isMuted = false,
    this.isSpeakerOn = false,
    this.isSelfVideoEnabled = false,
    this.isScreenSharing = false,
    this.isHandRaised = false,
    this.isSelfSpeaking = false,
    this.localReaction,
    this.voiceEffect = VoiceFilterPreset.none,
    this.forceRelay = false,
    this.isPlus = false,
    this.maxVideoHeight = 480,
    this.maxScreenHeight = 480,
    this.maxFps = 30,
    this.activeScreenPeerId,
    this.activeScreenPeerName,
    this.isListener = false,
    required this.durationSeconds,
    this.remoteParticipants = const [],
    this.verificationEmojis = const [],
    this.fatalError,
    this.quality = const CallQuality(),
  });

  final CallQuality quality;
  final CallSessionState state;
  final int callId;
  final String? roomId;
  final bool isVideo;
  final bool isGroup;
  final CallDirection? direction;
  final int? localClientId;
  final String? peerName;
  final String? peerAvatarUrl;
  final String? peerUsername;
  final bool isMuted;
  final bool isSpeakerOn;
  final bool isSelfVideoEnabled;
  final bool isScreenSharing;
  final bool isHandRaised;
  final bool isSelfSpeaking;
  final String? localReaction;
  final VoiceFilterPreset voiceEffect;
  final bool forceRelay;
  final bool isPlus;
  final int maxVideoHeight;
  final int maxScreenHeight;
  final int maxFps;
  final int? activeScreenPeerId;
  final String? activeScreenPeerName;
  final bool isListener;
  final int durationSeconds;
  final List<RemoteParticipant> remoteParticipants;
  final List<String> verificationEmojis;

  /// Set when the session ends due to a transport failure, so the UI can
  /// show an error message rather than silently popping back.
  final String? fatalError;

  CallSessionData copyWith({
    CallQuality? quality,
    CallSessionState? state,
    int? callId,
    String? roomId,
    bool? isVideo,
    bool? isGroup,
    CallDirection? direction,
    int? localClientId,
    String? peerName,
    String? peerAvatarUrl,
    String? peerUsername,
    bool? isMuted,
    bool? isSpeakerOn,
    bool? isSelfVideoEnabled,
    bool? isScreenSharing,
    bool? isHandRaised,
    bool? isSelfSpeaking,
    String? localReaction,
    bool clearLocalReaction = false,
    VoiceFilterPreset? voiceEffect,
    bool? forceRelay,
    bool? isPlus,
    int? maxVideoHeight,
    int? maxScreenHeight,
    int? maxFps,
    int? activeScreenPeerId,
    bool clearActiveScreenPeer = false,
    String? activeScreenPeerName,
    bool? isListener,
    int? durationSeconds,
    List<RemoteParticipant>? remoteParticipants,
    List<String>? verificationEmojis,
    String? fatalError,
  }) {
    return CallSessionData(
      quality: quality ?? this.quality,
      state: state ?? this.state,
      callId: callId ?? this.callId,
      roomId: roomId ?? this.roomId,
      isVideo: isVideo ?? this.isVideo,
      isGroup: isGroup ?? this.isGroup,
      direction: direction ?? this.direction,
      localClientId: localClientId ?? this.localClientId,
      peerName: peerName ?? this.peerName,
      peerAvatarUrl: peerAvatarUrl ?? this.peerAvatarUrl,
      peerUsername: peerUsername ?? this.peerUsername,
      isMuted: isMuted ?? this.isMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      isSelfVideoEnabled: isSelfVideoEnabled ?? this.isSelfVideoEnabled,
      isScreenSharing: isScreenSharing ?? this.isScreenSharing,
      isHandRaised: isHandRaised ?? this.isHandRaised,
      isSelfSpeaking: isSelfSpeaking ?? this.isSelfSpeaking,
      localReaction: clearLocalReaction
          ? null
          : (localReaction ?? this.localReaction),
      voiceEffect: voiceEffect ?? this.voiceEffect,
      forceRelay: forceRelay ?? this.forceRelay,
      isPlus: isPlus ?? this.isPlus,
      maxVideoHeight: maxVideoHeight ?? this.maxVideoHeight,
      maxScreenHeight: maxScreenHeight ?? this.maxScreenHeight,
      maxFps: maxFps ?? this.maxFps,
      activeScreenPeerId: clearActiveScreenPeer
          ? null
          : (activeScreenPeerId ?? this.activeScreenPeerId),
      activeScreenPeerName: clearActiveScreenPeer
          ? null
          : (activeScreenPeerName ?? this.activeScreenPeerName),
      isListener: isListener ?? this.isListener,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      remoteParticipants: remoteParticipants ?? this.remoteParticipants,
      verificationEmojis: verificationEmojis ?? this.verificationEmojis,
      fatalError: fatalError ?? this.fatalError,
    );
  }
}

/// A remote participant in a call.
class RemoteParticipant {
  RemoteParticipant({
    required this.clientId,
    required this.nickname,
    DateTime? lastSeen,
    this.audioEnabled = true,
    this.videoEnabled = false,
    this.screenSharing = false,
    this.screenStreamId,
    this.handRaised = false,
    this.isSpeaking = false,
    this.reaction,
    this.voiceEffect = VoiceFilterPreset.none,
  }) : lastSeen = lastSeen ?? DateTime.now();

  final int clientId;
  final String nickname;

  /// Last heartbeat received from this participant; used to drop peers
  /// that silently disappeared.
  final DateTime lastSeen;

  /// Peer-reported mic/camera/screen state from `media_state` signaling frames.
  final bool audioEnabled;
  final bool videoEnabled;
  final bool screenSharing;
  final String? screenStreamId;
  final bool handRaised;
  final bool isSpeaking;
  final String? reaction;
  final VoiceFilterPreset voiceEffect;

  RemoteParticipant copyWith({
    String? nickname,
    DateTime? lastSeen,
    bool? audioEnabled,
    bool? videoEnabled,
    bool? screenSharing,
    String? screenStreamId,
    bool clearScreenStreamId = false,
    bool? handRaised,
    bool? isSpeaking,
    String? reaction,
    bool clearReaction = false,
    VoiceFilterPreset? voiceEffect,
  }) {
    return RemoteParticipant(
      clientId: clientId,
      nickname: nickname ?? this.nickname,
      lastSeen: lastSeen ?? this.lastSeen,
      audioEnabled: audioEnabled ?? this.audioEnabled,
      videoEnabled: videoEnabled ?? this.videoEnabled,
      screenSharing: screenSharing ?? this.screenSharing,
      screenStreamId: clearScreenStreamId
          ? null
          : (screenStreamId ?? this.screenStreamId),
      handRaised: handRaised ?? this.handRaised,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      reaction: clearReaction ? null : (reaction ?? this.reaction),
      voiceEffect: voiceEffect ?? this.voiceEffect,
    );
  }
}

/// Callback: outgoing audio frame (Opus) to send.
typedef SendAudioCallback = void Function(Uint8List opusData);

/// Callback: outgoing video frame to send.
typedef SendVideoCallback = void Function(
    Uint8List data, int frameType, double timestamp);
