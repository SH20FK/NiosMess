import 'dart:async';
import 'dart:convert';
import 'package:audio_session/audio_session.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:pulse_flutter/models/api/call_models.dart';
import 'package:pulse_flutter/services/audio/voice_filter_preset.dart';
import 'package:pulse_flutter/services/calls/call_capture_profile.dart';
import 'package:pulse_flutter/services/calls/call_devices.dart';
import 'package:pulse_flutter/services/calls/call_quality.dart';
import 'package:pulse_flutter/services/calls/call_sender_quality.dart';
import 'package:pulse_flutter/services/calls/call_session_types.dart';
import 'package:pulse_flutter/services/calls/webrtc_signaling_client.dart';

/// Manages a 1:1 or multi-party E2EE WebRTC call session via Nios signaling,
/// including screen sharing and automatic TURN TLS/TCP fallback over VPNs.
class WebRtcCallSession {
  WebRtcCallSession({
    required this.chatId,
    required this.callId,
    required this.roomId,
    required this.isVideo,
    required this.direction,
    required this.displayName,
    this.isGroup = false,
    this.forceRelay = false,
    this.peerName,
    this.peerAvatarUrl,
    this.peerUsername,
    this.isListener = false,
    required this.gatewayInfo,
    required this.localRenderer,
    required this.remoteRenderer,
    this.localScreenRenderer,
    this.onStateChanged,
    this.onRemoteStreamsChanged,
    this.onRefreshGateway,
    this.peerConnectionFactory,
    this.mediaStreamFactory,
    this.displayMediaFactory,
    this.devices = const CallDevices(),
  }) : _forceRelay = forceRelay,
       _gatewayInfo = gatewayInfo;

  final int chatId;
  final int callId;
  final String roomId;
  final bool isVideo;
  final bool isGroup;
  final bool forceRelay;
  final CallDirection direction;
  final String displayName;
  final String? peerName;
  final String? peerAvatarUrl;
  final String? peerUsername;
  final bool isListener;
  final ApiCallGatewayInfo gatewayInfo;
  ApiCallGatewayInfo _gatewayInfo;

  final RTCVideoRenderer localRenderer;
  final RTCVideoRenderer remoteRenderer;
  final RTCVideoRenderer? localScreenRenderer;
  final void Function(CallSessionData data)? onStateChanged;
  final VoidCallback? onRemoteStreamsChanged;
  final Future<ApiCallGatewayInfo?> Function()? onRefreshGateway;
  final Future<RTCPeerConnection> Function(Map<String, dynamic>)?
  peerConnectionFactory;
  final Future<MediaStream> Function(Map<String, dynamic>)? mediaStreamFactory;
  final Future<MediaStream> Function(Map<String, dynamic>)?
  displayMediaFactory;

  CallDevices devices;
  Future<void> _mediaChain = Future<void>.value();
  WebRtcSignalingClient? _signaling;
  StreamSubscription<Map<String, dynamic>>? _signalingSub;
  StreamSubscription<void>? _disconnectSub;

  final Map<int, RTCPeerConnection> _peerConnections = {};
  MediaStream? _localStream;
  MediaStream? _localScreenStream;
  final Map<int, RTCRtpSender> _screenSenders = {};
  MediaStream? _remoteStream;
  final Map<int, MediaStream> _remoteStreams = {};
  final Map<int, MediaStream> _remoteScreenStreams = {};
  final Map<int, Map<String, MediaStream>> _peerStreams = {};
  bool _remoteRendererBound = false;

  CallSessionState _state = CallSessionState.idle;
  int _elapsedSeconds = 0;
  Timer? _durationTimer;
  bool _ended = false;
  Future<void> _signalChain = Future<void>.value();
  Future<void>? _disposeFuture;
  Future<void>? _startFuture;
  final Map<int, List<RTCIceCandidate>> _pendingIce = {};
  final Set<int> _remoteDescriptionReady = {};

  late bool _isMuted = isListener;
  bool _isSpeakerOn = false;
  late bool _isSelfVideoEnabled = isVideo && !isListener;
  bool _isScreenSharing = false;
  bool _isHandRaised = false;
  bool _isSelfSpeaking = false;
  String? _localReaction;
  VoiceFilterPreset _voiceEffect = VoiceFilterPreset.none;
  Timer? _localReactionTimer;
  final Map<int, Timer> _peerReactionTimers = {};
  bool _forceRelay = false;
  String? _fatalError;
  bool _peerSeen = false;
  Timer? _statsTimer, _recoveryTimer, _recoveryDeadline;
  final _samplers = <int, CallQualitySampler>{};
  CallQuality _quality = const CallQuality();
  bool _sampling = false;
  int _recoveryAttempt = 0;
  bool _recovering = false;

  String? _localDtlsFingerprint;
  final Map<int, String> _remoteDtlsFingerprints = {};
  List<String> _verificationEmojis = const [];

  final List<RemoteParticipant> _remoteParticipants = [];

  final StreamController<CallSessionData> _stateController =
      StreamController<CallSessionData>.broadcast();

  Stream<CallSessionData> get stateStream => _stateController.stream;

  CallSessionData get currentData {
    int? activeScreenId;
    String? activeScreenName;
    for (final p in _remoteParticipants) {
      if (p.screenSharing || _remoteScreenStreams.containsKey(p.clientId)) {
        activeScreenId = p.clientId;
        activeScreenName = p.nickname;
        break;
      }
    }
    return CallSessionData(
      state: _state,
      callId: callId,
      roomId: roomId,
      isVideo:
          isVideo ||
          _isSelfVideoEnabled ||
          _isScreenSharing ||
          activeScreenId != null ||
          _remoteParticipants.any((p) => p.videoEnabled || p.screenSharing),
      isGroup: isGroup,
      direction: direction,
      localClientId: _signaling?.localUserId,
      peerName: peerName,
      peerAvatarUrl: peerAvatarUrl,
      peerUsername: peerUsername,
      durationSeconds: _elapsedSeconds,
      remoteParticipants: List<RemoteParticipant>.unmodifiable(
        _remoteParticipants,
      ),
      verificationEmojis: _verificationEmojis,
      isMuted: _isMuted,
      isSpeakerOn: _isSpeakerOn,
      isSelfVideoEnabled: _isSelfVideoEnabled,
      isScreenSharing: _isScreenSharing,
      isHandRaised: _isHandRaised,
      isSelfSpeaking: _isSelfSpeaking,
      localReaction: _localReaction,
      voiceEffect: _voiceEffect,
      forceRelay: _forceRelay,
      isPlus: _gatewayInfo.isPlus,
      maxVideoHeight: _gatewayInfo.maxVideoHeight,
      maxScreenHeight: _gatewayInfo.maxScreenHeight,
      maxFps: _gatewayInfo.maxFps,
      activeScreenPeerId: activeScreenId,
      activeScreenPeerName: activeScreenName,
      isListener: isListener,
      fatalError: _fatalError,
      quality: _quality,
    );
  }

  bool get wasAnswered => _peerSeen;
  MediaStream? get localStream => _localStream;
  MediaStream? get localScreenStream => _localScreenStream;
  MediaStream? get remoteStream => _remoteStream;
  bool get isScreenSharing => _isScreenSharing;
  bool get isForceRelay => _forceRelay;

  /// Remote camera/audio media streams keyed by peer id.
  Map<int, MediaStream> get remoteStreams =>
      Map<int, MediaStream>.unmodifiable(_remoteStreams);

  /// Remote screen-sharing media streams keyed by peer id.
  Map<int, MediaStream> get remoteScreenStreams =>
      Map<int, MediaStream>.unmodifiable(_remoteScreenStreams);

  Future<void> start() {
    if (_ended) return Future<void>.value();
    return _startFuture ??= _start();
  }

  Future<void> _start() async {
    _setState(CallSessionState.connecting);

    try {
      await _configureAudioSession();
      if (_ended) return;
      await _initLocalMedia();
      if (_ended) return;
      await setSpeakerOn(_isSpeakerOn);
      if (_ended) return;

      final String signalUrl = _gatewayInfo.signalUrl.isNotEmpty
          ? _gatewayInfo.signalUrl
          : 'wss://c.ni-os.ru/signal';

      _signaling = WebRtcSignalingClient(
        signalUrl: signalUrl,
        token: _gatewayInfo.callAccessToken,
      );

      _signalingSub = _signaling!.onMessage.listen(handleSignalingMessage);
      _disconnectSub = _signaling!.onDisconnected.listen((_) {
        if (!_ended) {
          requestRecovery();
        }
      });

      _statsTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => unawaited(_sampleQuality()),
      );
      final bool connected = await _signaling!.connect();
      if (!connected) {
        _fatalError = 'connection_failed';
        _handleEnd();
        return;
      }

      if (!_ended && _state == CallSessionState.connecting) {
        _setState(CallSessionState.connected);
      }
    } catch (e) {
      debugPrint('[WebRtcCallSession] Start failed');
      _fatalError ??= 'connection_failed';
      _handleEnd();
    }
  }

  Future<void> _configureAudioSession() async {
    if (kIsWeb) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(
        AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions: _isSpeakerOn
              ? AVAudioSessionCategoryOptions(0x4 | 0x8) // defaultToSpeaker
              : AVAudioSessionCategoryOptions(0x4),
          avAudioSessionMode: AVAudioSessionMode.voiceChat,
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.defaultPolicy,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: true,
        ),
      );
    } catch (e) {
      debugPrint('[WebRtcCallSession] AudioSession config error: $e');
    }
  }

  Future<void> _initLocalMedia() async {
    if (isListener) {
      debugPrint(
        '[WebRtcCallSession] Joining as listener only (no media capture)',
      );
      return;
    }

    try {
      final profile = CallCaptureProfile(
        _gatewayInfo.maxVideoHeight,
        maxFps: _gatewayInfo.maxFps,
      );
      final mediaConstraints = devices.constraints(
        video: isVideo,
        maxHeight: profile.height,
        maxFps: profile.maxFps,
      );

      final stream =
          await (mediaStreamFactory ?? navigator.mediaDevices.getUserMedia)(
            mediaConstraints,
          );
      if (_ended) {
        for (final track in stream.getTracks()) {
          await track.stop();
        }
        await stream.dispose();
        return;
      }
      _localStream = stream;
      if (stream.getAudioTracks().isEmpty) {
        throw StateError('Microphone track unavailable');
      }

      if (isVideo && _localStream != null) {
        localRenderer.srcObject = _localStream;
      }

      if (_isMuted) {
        for (final track in _localStream?.getAudioTracks() ?? []) {
          track.enabled = false;
        }
      }
    } catch (_) {
      debugPrint('[WebRtcCallSession] Local media capture unavailable');
      _fatalError = 'media_unavailable';
      rethrow;
    }
  }

  Map<String, dynamic> buildRtcConfiguration() {
    final List<Map<String, dynamic>> iceServers = [];

    for (final s in _gatewayInfo.iceServers) {
      final dynamic rawUrls = s['urls'];
      final List<String> urlsList = [];
      if (rawUrls is List) {
        urlsList.addAll(rawUrls.map((u) => u.toString()));
      } else if (rawUrls != null) {
        urlsList.add(rawUrls.toString());
      }

      if (urlsList.isNotEmpty) {
        final Map<String, dynamic> server = {'urls': urlsList};
        if (s.containsKey('username')) server['username'] = s['username'];
        if (s.containsKey('credential')) server['credential'] = s['credential'];
        iceServers.add(server);
      }
    }

    if (iceServers.isEmpty) {
      iceServers.add({
        'urls': ['stun:c.ni-os.ru:3478', 'stun:stun.l.google.com:19302'],
      });
    }

    return {
      'iceServers': iceServers,
      'iceTransportPolicy': _forceRelay ? 'relay' : 'all',
      'sdpSemantics': 'unified-plan',
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
      'iceCandidatePoolSize': 4,
    };
  }

  Future<RTCPeerConnection> _getOrCreatePeerConnection(
    int peerId, {
    String? peerDisplayName,
  }) async {
    if (_peerConnections.containsKey(peerId)) {
      return _peerConnections[peerId]!;
    }

    final pc = await (peerConnectionFactory ?? createPeerConnection)(
      buildRtcConfiguration(),
    );
    if (_ended) {
      await pc.close();
      await pc.dispose();
      throw StateError('Call ended during peer creation');
    }
    _peerConnections[peerId] = pc;

    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await pc.addTrack(track, _localStream!);
      }
    }
    if (_localScreenStream != null) {
      final screenTracks = _localScreenStream!.getVideoTracks();
      if (screenTracks.isNotEmpty) {
        try {
          _screenSenders[peerId] = await pc.addTrack(
            screenTracks.first,
            _localScreenStream!,
          );
        } catch (_) {}
      }
    }

    pc.onIceCandidate = (RTCIceCandidate candidate) {
      if (!_ended && candidate.candidate != null && _signaling != null) {
        _signaling!.sendIceCandidate(peerId, {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      }
    };

    pc.onTrack = (RTCTrackEvent event) {
      if (_ended) return;
      debugPrint(
        '[WebRtcCallSession] Received remote track: ${event.track.kind}',
      );
      if (event.streams.isNotEmpty) {
        final MediaStream stream = event.streams[0];
        final String streamId = _safeStreamId(stream);
        final byId = _peerStreams.putIfAbsent(peerId, () => <String, MediaStream>{});
        byId[streamId] = stream;

        final RemoteParticipant? p = _findParticipant(peerId);
        final bool explicitlyScreen =
            p != null &&
            p.screenSharing &&
            p.screenStreamId != null &&
            p.screenStreamId == streamId;
        final bool secondVideoStream =
            event.track.kind == 'video' &&
            (p?.screenSharing ?? false) &&
            _remoteStreams.containsKey(peerId) &&
            _safeStreamId(_remoteStreams[peerId]!) != streamId;

        if (explicitlyScreen || secondVideoStream) {
          _remoteScreenStreams[peerId] = stream;
        } else {
          _remoteStreams[peerId] = stream;
          // The single 1:1 renderer sticks to the first peer instead of
          // flickering to whichever peer produced the latest track.
          _remoteStream ??= stream;
          if (!_remoteRendererBound) {
            _remoteRendererBound = true;
            remoteRenderer.srcObject = stream;
            if (devices.output.isNotEmpty) {
              unawaited(devices.applyOutput(remoteRenderer).catchError((Object _) {}));
            }
          }
        }
        onRemoteStreamsChanged?.call();
        _triggerStateUpdate();
      }
    };

    pc.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('[WebRtcCallSession] PC state with $peerId: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _onRemotePeerJoined(peerId, peerDisplayName);
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        if (!_ended) {
          requestRecovery();
        }
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        requestRecovery();
      }
    };

    return pc;
  }

  RemoteParticipant? _findParticipant(int peerId) {
    for (final p in _remoteParticipants) {
      if (p.clientId == peerId) return p;
    }
    return null;
  }

  String _safeStreamId(MediaStream stream) {
    try {
      return stream.id;
    } catch (_) {
      return '${identityHashCode(stream)}';
    }
  }

  Future<void> _configureSenders(RTCPeerConnection pc) async {
    if (_ended) return;
    final int peerCount = _peerConnections.length + 1;
    final videoProfile = CallCaptureProfile(
      _gatewayInfo.maxVideoHeight,
      maxFps: _gatewayInfo.maxFps,
    );
    final screenProfile = CallCaptureProfile(
      _gatewayInfo.maxScreenHeight,
      maxFps: _gatewayInfo.maxFps,
    );
    final screenTrackIds =
        _localScreenStream?.getVideoTracks().map((t) => t.id).toSet() ?? const {};
    try {
      for (final sender in await pc.getSenders()) {
        if (_ended) return;
        final bool isScreenSender =
            sender.track?.id != null && screenTrackIds.contains(sender.track!.id);
        try {
          await configureCallSender(
            sender,
            isScreenSender ? screenProfile : videoProfile,
            peerCount: peerCount,
            isScreenShare: isScreenSender,
          );
        } catch (_) {
          // Older engines may reject optional tuning. Their negotiated defaults
          // remain usable, so this must never terminate a working call.
          debugPrint('[WebRtcCallSession] SENDER_TUNING_UNAVAILABLE');
        }
      }
    } catch (_) {
      debugPrint('[WebRtcCallSession] SENDERS_UNAVAILABLE');
    }
  }

  void _ensureParticipantEntry(int peerId, String? name, {bool video = false, bool screen = false, String? screenStreamId}) {
    final String displayName = name ?? peerName ?? 'User $peerId';
    final int idx = _remoteParticipants.indexWhere((p) => p.clientId == peerId);
    if (idx != -1) {
      _remoteParticipants[idx] = _remoteParticipants[idx].copyWith(
        nickname: name ?? _remoteParticipants[idx].nickname,
        videoEnabled: video || _remoteParticipants[idx].videoEnabled,
        screenSharing: screen || _remoteParticipants[idx].screenSharing,
        screenStreamId: screenStreamId ?? _remoteParticipants[idx].screenStreamId,
        lastSeen: DateTime.now(),
      );
    } else {
      _remoteParticipants.add(
        RemoteParticipant(
          clientId: peerId,
          nickname: displayName,
          videoEnabled: video,
          screenSharing: screen,
          screenStreamId: screenStreamId,
          lastSeen: DateTime.now(),
        ),
      );
    }
  }

  void _onRemotePeerJoined(int peerId, String? name) {
    if (_ended) return;
    _recoveryTimer?.cancel();
    _recoveryDeadline?.cancel();
    _recoveryDeadline = null;
    _recoveryTimer = null;
    _recoveryAttempt = 0;
    _setState(CallSessionState.inCall);
    if (!_peerSeen) {
      _peerSeen = true;
      _startDurationTimer();
    }
    _ensureParticipantEntry(peerId, name);
    _triggerStateUpdate();
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _elapsedSeconds = 0;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;
      _triggerStateUpdate();
    });
  }

  static final RegExp _fpRegex = RegExp(
    r'a=fingerprint:\s*sha-256\s+([0-9A-Fa-f:]+)',
  );

  void _recordFingerprintFromSdp(int? remotePeerId, String sdp) {
    final m = _fpRegex.firstMatch(sdp);
    if (m == null) return;
    final fp = m.group(1)!.toUpperCase();
    if (remotePeerId == null) {
      _localDtlsFingerprint = fp;
    } else {
      _remoteDtlsFingerprints[remotePeerId] = fp;
    }
    _recomputeVerificationEmojis();
  }

  static const List<String> _sasEmojis = <String>[
    '🔐', '🛡️', '🔑', '🦊', '🦉', '🐳', '🐙', '🦄',
    '🐝', '🐢', '🦋', '🐬', '🦁', '🐼', '🐨', '🐯',
    '🚀', '⭐', '🌙', '☀️', '⚡', '🔥', '🌊', '💎',
    '🍀', '🌵', '🍄', '🎯', '🧭', '🎈', '🎧', '🔔',
  ];

  void _recomputeVerificationEmojis() {
    final localFp = _localDtlsFingerprint;
    if (localFp == null || _remoteDtlsFingerprints.isEmpty) return;
    final fps = <String>[localFp, ..._remoteDtlsFingerprints.values]..sort();
    final digest = crypto.sha256
        .convert(utf8.encode('$roomId|${fps.join("|")}'))
        .bytes;
    _verificationEmojis = List<String>.generate(
      4,
      (i) => _sasEmojis[digest[i] % _sasEmojis.length],
      growable: false,
    );
  }

  Future<void> _onSignalingMessage(Map<String, dynamic> msg) async {
    final String? type = msg['type']?.toString();
    debugPrint('[WebRtcCallSession] Signal message received: $type');

    switch (type) {
      case WebRtcSignalType.ready:
        final int localId = (msg['user_id'] as num?)?.toInt() ?? 0;
        final dynamic rawPeers = msg['peers'];
        if (rawPeers is List) {
          for (final p in rawPeers) {
            if (p is Map) {
              final int remoteId = (p['user_id'] as num?)?.toInt() ?? 0;
              final String name = p['name']?.toString() ?? 'User';
              if (remoteId > 0 && remoteId != localId) {
                _ensureParticipantEntry(
                  remoteId,
                  name,
                  video: p['video'] == true,
                  screen: p['screen'] == true,
                  screenStreamId: p['screen_stream_id']?.toString(),
                );
                // If localId < remoteId, this client initiates the offer
                final bool makeOffer = localId < remoteId;
                await _negotiatePeer(
                  remoteId,
                  makeOffer: makeOffer,
                  peerName: name,
                );
              }
            }
          }
        }
        break;

      case WebRtcSignalType.peerJoined:
        final int remoteId = (msg['user_id'] as num?)?.toInt() ?? 0;
        final String name = msg['name']?.toString() ?? 'User';
        final int localId = _signaling?.localUserId ?? 0;
        if (remoteId > 0 && remoteId != localId) {
          _ensureParticipantEntry(
            remoteId,
            name,
            video: msg['video'] == true,
            screen: msg['screen'] == true,
            screenStreamId: msg['screen_stream_id']?.toString(),
          );
          final bool makeOffer = localId < remoteId;
          await _negotiatePeer(remoteId, makeOffer: makeOffer, peerName: name);
        }
        break;

      case WebRtcSignalType.offer:
        final int fromId = (msg['from_id'] as num?)?.toInt() ?? 0;
        final dynamic sdpData = msg['sdp'];
        if (fromId > 0 && sdpData is Map) {
          await _handleOffer(fromId, sdpData);
        }
        break;

      case WebRtcSignalType.answer:
        final int fromId = (msg['from_id'] as num?)?.toInt() ?? 0;
        final dynamic sdpData = msg['sdp'];
        if (fromId > 0 && sdpData is Map) {
          await _handleAnswer(fromId, sdpData);
        }
        break;

      case WebRtcSignalType.ice:
        final int fromId = (msg['from_id'] as num?)?.toInt() ?? 0;
        final dynamic candidateData = msg['candidate'];
        if (fromId > 0 && candidateData is Map) {
          await _handleIce(fromId, candidateData);
        }
        break;

      case WebRtcSignalType.mediaState:
        final int fromId = (msg['from_id'] as num?)?.toInt() ?? 0;
        if (fromId > 0) {
          _handleMediaState(
            fromId,
            audio: msg['audio'] == true,
            video: msg['video'] == true,
            screen: msg['screen'] == true,
            screenStreamId: msg['screen_stream_id']?.toString(),
            voiceEffect: VoiceFilterPreset.fromId(
              msg['voice_effect']?.toString(),
            ),
          );
        }
        break;

      case WebRtcSignalType.handRaise:
        final int fromId = (msg['from_id'] as num?)?.toInt() ?? 0;
        if (fromId > 0) {
          _handlePeerHandRaise(fromId, msg['raised'] == true);
        }
        break;

      case WebRtcSignalType.callReaction:
        final int fromId = (msg['from_id'] as num?)?.toInt() ?? 0;
        final String emoji = msg['emoji']?.toString() ?? '';
        if (fromId > 0 && emoji.isNotEmpty) {
          _handlePeerReaction(fromId, emoji);
        }
        break;

      case WebRtcSignalType.peerLeft:
        final int leftId = (msg['user_id'] as num?)?.toInt() ?? 0;
        _handlePeerLeft(leftId);
        break;

      case WebRtcSignalType.callEnded:
        final String reason = msg['reason']?.toString() ?? 'ended';
        debugPrint('[WebRtcCallSession] Call ended by server: $reason');
        _fatalError = reason == 'solo_timeout' || reason == 'duration_limit'
            ? reason
            : null;
        _handleEnd();
        break;
    }
  }

  /// Queues signaling frames; callers may await processing, unlike Stream.listen.
  Future<void> handleSignalingMessage(Map<String, dynamic> message) {
    _signalChain = _signalChain
        .then((_) async {
          if (!_ended) await _onSignalingMessage(message);
        })
        .catchError((Object _) {
          if (!_ended) {
            _fatalError = 'signaling_failed';
            _handleEnd();
          }
        });
    return _signalChain;
  }

  Future<bool> _isSignalingStable(RTCPeerConnection pc) async {
    var state = pc.signalingState;
    if (state == null) {
      try {
        state = await pc.getSignalingState();
      } catch (_) {}
    }
    return state == null || state == RTCSignalingState.RTCSignalingStateStable;
  }

  Future<void> _negotiatePeer(
    int remoteId, {
    required bool makeOffer,
    required String peerName,
  }) async {
    final pc = await _getOrCreatePeerConnection(
      remoteId,
      peerDisplayName: peerName,
    );

    if (makeOffer) {
      if (await _isSignalingStable(pc)) {
        final RTCSessionDescription offer = await pc.createOffer({
          'offerToReceiveAudio': 1,
          'offerToReceiveVideo': 1,
        });
        await pc.setLocalDescription(offer);
        _recordFingerprintFromSdp(null, offer.sdp ?? '');
        await _configureSenders(pc);

        _signaling?.sendOffer(remoteId, {'type': offer.type, 'sdp': offer.sdp});
        debugPrint('[WebRtcCallSession] Sent offer to peer $remoteId');
      } else {
        // A replayed ready/peer_joined (e.g. after a signaling reconnect)
        // must not stack a second offer onto an in-flight negotiation.
        debugPrint(
          '[WebRtcCallSession] Offer for $remoteId skipped: negotiation already in flight',
        );
      }
    }
    // Late joiners and renegotiated peers need our current mute/camera/screen state.
    _sendMediaState();
  }

  Future<void> _renegotiateAllPeers() async {
    if (_ended) return;
    _signalChain = _signalChain
        .then((_) async {
          if (_ended) return;
          for (final entry in _peerConnections.entries.toList()) {
            if (_ended) return;
            final peerId = entry.key;
            final pc = entry.value;
            if (await _isSignalingStable(pc)) {
              final offer = await pc.createOffer({
                'offerToReceiveAudio': 1,
                'offerToReceiveVideo': 1,
              });
              if (_ended) return;
              await pc.setLocalDescription(offer);
              _recordFingerprintFromSdp(null, offer.sdp ?? '');
              await _configureSenders(pc);
              _signaling?.sendOffer(peerId, {
                'type': offer.type,
                'sdp': offer.sdp,
              });
            }
          }
        })
        .catchError((Object _) {
          debugPrint('[WebRtcCallSession] Renegotiation skipped');
        });
    await _signalChain;
  }

  Future<void> _handleOffer(int fromId, Map sdpData) async {
    var pc = await _getOrCreatePeerConnection(fromId);
    final String sdp = sdpData['sdp']?.toString() ?? '';
    final String type = sdpData['type']?.toString() ?? 'offer';

    // Glare: both sides hold a local offer simultaneously (a replayed
    // peer_joined racing a recovery restart). Perfect-negotiation split:
    // the side that normally offers (lower user id) keeps its own offer and
    // drops this one; the answering side rebuilds the peer connection and
    // accepts the remote offer.
    if (pc.signalingState ==
        RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
      final int? localId = _signaling?.localUserId;
      if (localId != null && localId < fromId) {
        debugPrint(
          '[WebRtcCallSession] Glare: keeping local offer, dropping offer from $fromId',
        );
        return;
      }
      debugPrint(
        '[WebRtcCallSession] Glare: rebuilding peer connection for $fromId',
      );
      await _discardPeerConnection(fromId);
      pc = await _getOrCreatePeerConnection(fromId);
    }

    _recordFingerprintFromSdp(fromId, sdp);
    await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
    await _flushIce(fromId, pc);
    final RTCSessionDescription answer = await pc.createAnswer({
      'offerToReceiveAudio': 1,
      'offerToReceiveVideo': 1,
    });
    await pc.setLocalDescription(answer);
    _recordFingerprintFromSdp(null, answer.sdp ?? '');
    await _configureSenders(pc);

    _signaling?.sendAnswer(fromId, {'type': answer.type, 'sdp': answer.sdp});
    debugPrint('[WebRtcCallSession] Sent answer to peer $fromId');
    _sendMediaState();
    _triggerStateUpdate();
  }

  Future<void> _handleAnswer(int fromId, Map sdpData) async {
    final pc = _peerConnections[fromId];
    if (pc == null) return;

    final String sdp = sdpData['sdp']?.toString() ?? '';
    final String type = sdpData['type']?.toString() ?? 'answer';
    _recordFingerprintFromSdp(fromId, sdp);
    await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
    await _flushIce(fromId, pc);
    await _configureSenders(pc);
    _triggerStateUpdate();
    debugPrint('[WebRtcCallSession] Applied answer from peer $fromId');
  }

  Future<void> _handleIce(int fromId, Map candidateData) async {
    final pc = _peerConnections[fromId];
    final String? candidate = candidateData['candidate']?.toString();
    final String? sdpMid = candidateData['sdpMid']?.toString();
    final int? sdpMLineIndex = (candidateData['sdpMLineIndex'] as num?)
        ?.toInt();

    if (candidate != null) {
      final ice = RTCIceCandidate(candidate, sdpMid, sdpMLineIndex);
      if (pc == null || !_remoteDescriptionReady.contains(fromId)) {
        final pending = _pendingIce.putIfAbsent(fromId, () => []);
        if (pending.length < 256) pending.add(ice);
      } else {
        await pc.addCandidate(ice);
      }
    }
  }

  Future<void> _flushIce(int peerId, RTCPeerConnection pc) async {
    _remoteDescriptionReady.add(peerId);
    for (final candidate in _pendingIce.remove(peerId) ?? <RTCIceCandidate>[]) {
      await pc.addCandidate(candidate);
    }
  }

  void _handleMediaState(
    int peerId, {
    required bool audio,
    required bool video,
    bool screen = false,
    String? screenStreamId,
    VoiceFilterPreset voiceEffect = VoiceFilterPreset.none,
  }) {
    final int idx = _remoteParticipants.indexWhere((p) => p.clientId == peerId);
    if (idx == -1) return;
    _remoteParticipants[idx] = _remoteParticipants[idx].copyWith(
      audioEnabled: audio,
      videoEnabled: video,
      screenSharing: screen,
      screenStreamId: screen ? screenStreamId : null,
      clearScreenStreamId: !screen,
      voiceEffect: voiceEffect,
      lastSeen: DateTime.now(),
    );

    if (screen && screenStreamId != null) {
      final candidate = _peerStreams[peerId]?[screenStreamId];
      if (candidate != null) {
        _remoteScreenStreams[peerId] = candidate;
        onRemoteStreamsChanged?.call();
      }
    } else if (!screen && _remoteScreenStreams.containsKey(peerId)) {
      _remoteScreenStreams.remove(peerId);
      onRemoteStreamsChanged?.call();
    }
    _triggerStateUpdate();
  }

  void _handlePeerHandRaise(int peerId, bool raised) {
    final int idx = _remoteParticipants.indexWhere((p) => p.clientId == peerId);
    if (idx == -1) return;
    _remoteParticipants[idx] = _remoteParticipants[idx].copyWith(
      handRaised: raised,
      lastSeen: DateTime.now(),
    );
    _triggerStateUpdate();
  }

  void _handlePeerReaction(int peerId, String emoji) {
    final int idx = _remoteParticipants.indexWhere((p) => p.clientId == peerId);
    if (idx == -1) return;
    _remoteParticipants[idx] = _remoteParticipants[idx].copyWith(
      reaction: emoji,
      lastSeen: DateTime.now(),
    );
    _peerReactionTimers[peerId]?.cancel();
    _peerReactionTimers[peerId] = Timer(const Duration(seconds: 3), () {
      if (_ended) return;
      final int i = _remoteParticipants.indexWhere((p) => p.clientId == peerId);
      if (i != -1) {
        _remoteParticipants[i] = _remoteParticipants[i].copyWith(
          clearReaction: true,
        );
        _triggerStateUpdate();
      }
    });
    _triggerStateUpdate();
  }

  Future<void> _discardPeerConnection(int peerId) async {
    final pc = _peerConnections.remove(peerId);
    _screenSenders.remove(peerId);
    _samplers.remove(peerId);
    _remoteDescriptionReady.remove(peerId);
    _remoteStreams.remove(peerId);
    _remoteScreenStreams.remove(peerId);
    _peerStreams.remove(peerId);
    if (pc != null) {
      try {
        await pc.close();
      } catch (_) {}
      try {
        await pc.dispose();
      } catch (_) {}
    }
  }

  void _handlePeerLeft(int peerId) {
    final pc = _peerConnections.remove(peerId);
    _screenSenders.remove(peerId);
    _samplers.remove(peerId);
    _pendingIce.remove(peerId);
    _remoteDescriptionReady.remove(peerId);
    _remoteDtlsFingerprints.remove(peerId);
    pc?.close();
    pc?.dispose();
    _remoteParticipants.removeWhere((p) => p.clientId == peerId);
    _remoteScreenStreams.remove(peerId);
    _peerStreams.remove(peerId);
    final MediaStream? removedStream = _remoteStreams.remove(peerId);
    if (removedStream != null && identical(_remoteStream, removedStream)) {
      // Hand the 1:1 renderer over to a remaining peer, if any.
      _remoteStream = _remoteStreams.isEmpty ? null : _remoteStreams.values.first;
      _remoteRendererBound = _remoteStream != null;
      remoteRenderer.srcObject = _remoteStream;
      if (_remoteStream != null && devices.output.isNotEmpty) {
        unawaited(devices.applyOutput(remoteRenderer).catchError((Object _) {}));
      }
    }
    onRemoteStreamsChanged?.call();

    if (_remoteParticipants.isEmpty) {
      // A closed signaling socket also emits peer_left. Give it time to rejoin.
      requestRecovery();
    } else {
      _recomputeVerificationEmojis();
      _triggerStateUpdate();
    }
  }

  Future<void> _sampleQuality() async {
    if (_ended || _sampling) return;
    _sampling = true;
    try {
      CallQuality? worst;
      bool selfSpeaking = false;
      for (final entry in _peerConnections.entries.toList()) {
        try {
          final reports = await entry.value.getStats().timeout(
            const Duration(seconds: 2),
          );
          if (_ended) return;
          final rawStats = <Map<String, dynamic>>[
            for (final r in reports) {'id': r.id, 'type': r.type, ...r.values},
          ];
          final quality = _samplers
              .putIfAbsent(entry.key, CallQualitySampler.new)
              .sample(rawStats);
          if (worst == null || quality.level.index > worst.level.index) {
            worst = quality;
          }
          bool peerSpeaking = false;
          for (final stat in rawStats) {
            final String type = stat['type']?.toString() ?? '';
            final String kind =
                (stat['kind'] ?? stat['mediaType'])?.toString() ?? '';
            final num? level = stat['audioLevel'] as num?;
            if (level == null || kind != 'audio') continue;
            if (type == 'inbound-rtp' && level > 0.025) {
              peerSpeaking = true;
            } else if (type == 'media-source' && level > 0.025 && !_isMuted) {
              selfSpeaking = true;
            }
          }
          final int pIdx = _remoteParticipants.indexWhere(
            (p) => p.clientId == entry.key,
          );
          if (pIdx != -1) {
            final bool effectiveSpeaking =
                peerSpeaking && _remoteParticipants[pIdx].audioEnabled;
            if (_remoteParticipants[pIdx].isSpeaking != effectiveSpeaking) {
              _remoteParticipants[pIdx] = _remoteParticipants[pIdx].copyWith(
                isSpeaking: effectiveSpeaking,
              );
            }
          }
        } catch (_) {
          /* Missing stats never terminate media transport. */
        }
      }
      if (!_ended) {
        _isSelfSpeaking = selfSpeaking;
        _quality = worst ?? const CallQuality();
        _triggerStateUpdate();
      }
    } finally {
      _sampling = false;
    }
  }

  Future<Map<String, int>> collectLiveMediaStats() async {
    int audioBytesSent = 0;
    int audioBytesReceived = 0;
    int audioPacketsSent = 0;
    int audioPacketsReceived = 0;
    int videoBytesSent = 0;
    int videoBytesReceived = 0;
    int videoFramesSent = 0;
    int videoFramesDecoded = 0;

    int asInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

    for (final pc in _peerConnections.values.toList()) {
      final reports = await pc.getStats().timeout(const Duration(seconds: 2));
      for (final r in reports) {
        final type = r.type;
        final kind = (r.values['kind'] ?? r.values['mediaType'])?.toString() ?? '';
        if (type == 'outbound-rtp') {
          if (kind == 'audio') {
            audioBytesSent += asInt(r.values['bytesSent']);
            audioPacketsSent += asInt(r.values['packetsSent']);
          } else if (kind == 'video') {
            videoBytesSent += asInt(r.values['bytesSent']);
            videoFramesSent += asInt(r.values['framesSent']);
          }
        } else if (type == 'inbound-rtp') {
          if (kind == 'audio') {
            audioBytesReceived += asInt(r.values['bytesReceived']);
            audioPacketsReceived += asInt(r.values['packetsReceived']);
          } else if (kind == 'video') {
            videoBytesReceived += asInt(r.values['bytesReceived']);
            videoFramesDecoded += asInt(r.values['framesDecoded']);
          }
        }
      }
    }

    return {
      'audioBytesSent': audioBytesSent,
      'audioBytesReceived': audioBytesReceived,
      'audioPacketsSent': audioPacketsSent,
      'audioPacketsReceived': audioPacketsReceived,
      'videoBytesSent': videoBytesSent,
      'videoBytesReceived': videoBytesReceived,
      'videoFramesSent': videoFramesSent,
      'videoFramesDecoded': videoFramesDecoded,
    };
  }

  Future<void> setForceRelay(bool enabled) async {
    if (_ended || _forceRelay == enabled) return;
    _forceRelay = enabled;
    _triggerStateUpdate();
    await _rebuildAllPeerConnections();
  }

  Future<void> _rebuildAllPeerConnections() async {
    if (_ended) return;
    final signal = _signaling;
    final localId = signal?.localUserId;
    final peerIds = _peerConnections.keys.toList();
    for (final peerId in peerIds) {
      final name = _findParticipant(peerId)?.nickname ?? 'User $peerId';
      await _discardPeerConnection(peerId);
      if (_ended) return;
      final bool makeOffer = localId != null && localId < peerId;
      await _negotiatePeer(peerId, makeOffer: makeOffer, peerName: name);
    }
  }

  /// Reuses the authenticated room and existing offer/answer protocol.
  /// A bounded grace period covers both ICE migration and signaling reconnects,
  /// escalating to TURN TLS/TCP relay when direct UDP is blocked (e.g. VPN).
  void requestRecovery() {
    if (_ended) return;
    _setState(CallSessionState.reconnecting);
    _recoveryDeadline ??= Timer(const Duration(seconds: 40), () {
      if (_ended || _state != CallSessionState.reconnecting) return;
      _fatalError = 'connection_lost';
      _handleEnd();
    });
    if (_recoveryTimer?.isActive == true || _recovering) return;
    final delay = [1, 2, 4, 8][_recoveryAttempt.clamp(0, 3)];
    _recoveryTimer = Timer(
      Duration(seconds: delay),
      () => unawaited(_recover()),
    );
  }

  Future<void> _recover() async {
    if (_ended || _state != CallSessionState.reconnecting || _recovering) {
      return;
    }
    _recovering = true;
    _recoveryAttempt++;
    try {
      if (_recoveryAttempt >= 2 && onRefreshGateway != null) {
        try {
          final refreshed = await onRefreshGateway!();
          if (refreshed != null) {
            _gatewayInfo = refreshed;
            _signaling?.updateToken(refreshed.callAccessToken);
          }
        } catch (_) {}
      }
      final signal = _signaling;
      if (signal == null) return;
      if (!signal.isConnected && !await signal.connect()) return;
      if (_ended) return;
      if (_peerConnections.isNotEmpty &&
          _peerConnections.values.every(
            (pc) =>
                pc.connectionState ==
                RTCPeerConnectionState.RTCPeerConnectionStateConnected,
          )) {
        for (final id in _peerConnections.keys) {
          _onRemotePeerJoined(id, _findParticipant(id)?.nickname);
        }
        return;
      }

      // Escalate to strict TURN TLS/TCP relay after the first failed ICE check.
      if (!_forceRelay && _recoveryAttempt >= 1) {
        _forceRelay = true;
        _triggerStateUpdate();
        await _rebuildAllPeerConnections();
        return;
      }

      // The lower user ID offers on both clients, avoiding simultaneous restart offers.
      final localId = signal.localUserId;
      for (final entry in _peerConnections.entries.toList()) {
        if (_ended) return;
        if (localId != null && localId < entry.key) {
          await handleRecoveryOffer(entry.key, entry.value);
        }
      }
    } catch (_) {
      debugPrint('[WebRtcCallSession] RECOVERY_RETRY');
    } finally {
      _recovering = false;
      if (!_ended && _state == CallSessionState.reconnecting) {
        requestRecovery();
      }
    }
  }

  Future<void> handleRecoveryOffer(int peerId, RTCPeerConnection pc) async {
    // Serialize restarts with incoming SDP and ICE, including app resume events.
    _signalChain = _signalChain
        .then((_) async {
          if (_ended || !await _isSignalingStable(pc)) {
            return;
          }
          await pc.restartIce();
          final offer = await pc.createOffer({
            'iceRestart': true,
            'offerToReceiveAudio': 1,
            'offerToReceiveVideo': 1,
          });
          if (_ended) return;
          await pc.setLocalDescription(offer);
          _recordFingerprintFromSdp(null, offer.sdp ?? '');
          _signaling?.sendOffer(peerId, {'type': offer.type, 'sdp': offer.sdp});
        })
        .catchError((Object _) {
          /* Retry within the recovery deadline. */
        });
    await _signalChain;
  }

  void _handleEnd() {
    if (_ended) return;
    _ended = true;
    _statsTimer?.cancel();
    _recoveryTimer?.cancel();
    _recoveryDeadline?.cancel();
    _durationTimer?.cancel();
    _setState(CallSessionState.ended);
    unawaited(dispose());
  }

  Future<void> startScreenShare({String? sourceId}) async {
    if (_ended || isListener) return;
    final profile = CallCaptureProfile(
      _gatewayInfo.maxScreenHeight,
      maxFps: _gatewayInfo.maxFps,
    );
    final constraints = profile.screenShareConstraints(
      isWeb: kIsWeb,
      sourceId: sourceId,
    );
    final stream =
        await (displayMediaFactory ?? navigator.mediaDevices.getDisplayMedia)(
          constraints,
        );
    if (_ended) {
      for (final t in stream.getTracks()) {
        await t.stop();
      }
      await stream.dispose();
      return;
    }

    await _stopScreenShareLocalOnly();
    final videoTracks = stream.getVideoTracks();
    if (videoTracks.isEmpty) {
      await stream.dispose();
      throw StateError('screen_track_unavailable');
    }

    _localScreenStream = stream;
    _isScreenSharing = true;
    localScreenRenderer?.srcObject = stream;

    final track = videoTracks.first;
    track.onEnded = () => unawaited(stopScreenShare());

    for (final entry in _peerConnections.entries.toList()) {
      try {
        final sender = await entry.value.addTrack(track, stream);
        _screenSenders[entry.key] = sender;
        await _configureSenders(entry.value);
      } catch (_) {}
    }

    _sendMediaState();
    _triggerStateUpdate();
    await _renegotiateAllPeers();
  }

  Future<void> _stopScreenShareLocalOnly() async {
    final stream = _localScreenStream;
    _localScreenStream = null;
    _isScreenSharing = false;
    if (localScreenRenderer != null) {
      localScreenRenderer!.srcObject = null;
    }
    for (final entry in _screenSenders.entries.toList()) {
      final pc = _peerConnections[entry.key];
      if (pc != null) {
        try {
          await pc.removeTrack(entry.value);
        } catch (_) {}
      }
    }
    _screenSenders.clear();
    if (stream != null) {
      for (final track in stream.getTracks()) {
        try {
          await track.stop();
        } catch (_) {}
      }
      try {
        await stream.dispose();
      } catch (_) {}
    }
  }

  Future<void> stopScreenShare() async {
    if (!_isScreenSharing && _localScreenStream == null) return;
    await _stopScreenShareLocalOnly();
    if (!_ended) {
      _sendMediaState();
      _triggerStateUpdate();
      await _renegotiateAllPeers();
    }
  }

  Future<void> setDevices(CallDevices selection) {
    final operation = _mediaChain
        .catchError((Object _) {})
        .then((_) => _setDevices(selection));
    _mediaChain = operation;
    return operation;
  }

  Future<void> _setDevices(CallDevices selection) async {
    if (_ended) throw StateError('call_ended');
    final original = _localStream;
    if (original == null) {
      await selection.applyOutput(remoteRenderer);
      devices = selection;
      return;
    }
    final audioChanged = devices.microphone != selection.microphone;
    final videoChanged =
        (isVideo || _isSelfVideoEnabled) && devices.camera != selection.camera;
    MediaStream? replacement;
    final changed = <(RTCRtpSender, MediaStreamTrack?)>[];
    final captured = <MediaStreamTrack>[];
    try {
      if (audioChanged || videoChanged) {
        final constraints = selection.constraints(
          video: videoChanged,
          maxHeight: _gatewayInfo.maxVideoHeight,
          maxFps: _gatewayInfo.maxFps,
        );
        if (!audioChanged) constraints['audio'] = false;
        replacement =
            await (mediaStreamFactory ?? navigator.mediaDevices.getUserMedia)(
              constraints,
            );
        captured.addAll(replacement.getTracks());
        if (_ended) throw StateError('call_ended');
        for (final track in replacement.getTracks()) {
          track.enabled = track.kind == 'audio' ? !_isMuted : _isSelfVideoEnabled;
          for (final peer in _peerConnections.values.toList()) {
            for (final sender in await peer.getSenders()) {
              if (sender.track?.kind == track.kind &&
                  !_screenSenders.values.contains(sender)) {
                final old = sender.track;
                await sender.replaceTrack(track);
                changed.add((sender, old));
              }
            }
          }
        }
      }
      if (selection.output != devices.output) {
        await selection.applyOutput(remoteRenderer);
      }
      if (_ended) throw StateError('call_ended');
      if (replacement != null) {
        for (final track in replacement.getTracks().toList()) {
          for (final old
              in original
                  .getTracks()
                  .where((old) => old.kind == track.kind)
                  .toList()) {
            await original.removeTrack(old);
            await old.stop();
          }
          await replacement.removeTrack(track);
          await original.addTrack(track);
          if (_ended) throw StateError('call_ended');
        }
        localRenderer.srcObject = _isSelfVideoEnabled ? original : null;
      }
      devices = selection;
      for (final peer in _peerConnections.values.toList()) {
        await _configureSenders(peer);
      }
    } catch (_) {
      for (final (sender, old) in changed.reversed) {
        try {
          await sender.replaceTrack(old);
        } catch (_) {}
      }
      for (final track in captured) {
        try {
          await track.stop();
        } catch (_) {}
      }
      rethrow;
    } finally {
      await replacement?.dispose();
    }
  }

  Future<void> setMuted(bool muted) async {
    _isMuted = muted;
    if (_localStream != null) {
      for (final track in _localStream!.getAudioTracks()) {
        track.enabled = !muted;
      }
    }
    _sendMediaState();
    _triggerStateUpdate();
  }

  Future<void> setLocalVideoEnabled(bool enabled) async {
    if (_ended || isListener) return;
    _isSelfVideoEnabled = enabled;
    if (_localStream != null &&
        enabled &&
        _localStream!.getVideoTracks().isEmpty) {
      // Mid-call upgrade from voice to video: acquire camera and add track.
      try {
        final constraints = devices.constraints(
          video: true,
          maxHeight: _gatewayInfo.maxVideoHeight,
          maxFps: _gatewayInfo.maxFps,
        );
        constraints['audio'] = false;
        final camStream =
            await (mediaStreamFactory ?? navigator.mediaDevices.getUserMedia)(
              constraints,
            );
        if (_ended) {
          for (final t in camStream.getTracks()) {
            await t.stop();
          }
          await camStream.dispose();
          return;
        }
        final camTracks = camStream.getVideoTracks();
        if (camTracks.isNotEmpty) {
          final track = camTracks.first;
          await camStream.removeTrack(track);
          await _localStream!.addTrack(track);
          localRenderer.srcObject = _localStream;
          for (final pc in _peerConnections.values.toList()) {
            await pc.addTrack(track, _localStream!);
            await _configureSenders(pc);
          }
          await camStream.dispose();
          _sendMediaState();
          _triggerStateUpdate();
          await _renegotiateAllPeers();
          return;
        }
        await camStream.dispose();
      } catch (_) {
        _isSelfVideoEnabled = false;
        _triggerStateUpdate();
        return;
      }
    }
    if (_localStream != null) {
      for (final track in _localStream!.getVideoTracks()) {
        track.enabled = enabled;
      }
      if (enabled) {
        localRenderer.srcObject = _localStream;
      }
    }
    _sendMediaState();
    _triggerStateUpdate();
  }

  Future<void> switchCamera() async {
    if (_localStream == null) return;
    final videoTracks = _localStream!.getVideoTracks();
    if (videoTracks.isNotEmpty) {
      await Helper.switchCamera(videoTracks.first);
    }
  }

  void toggleHandRaise() {
    if (_ended) return;
    _isHandRaised = !_isHandRaised;
    _signaling?.sendHandRaise(_isHandRaised);
    _triggerStateUpdate();
  }

  void sendReaction(String emoji) {
    if (_ended || emoji.trim().isEmpty) return;
    final clean = emoji.trim();
    _localReaction = clean;
    _localReactionTimer?.cancel();
    _localReactionTimer = Timer(const Duration(seconds: 3), () {
      if (_ended) return;
      _localReaction = null;
      _triggerStateUpdate();
    });
    _signaling?.sendReaction(clean);
    _triggerStateUpdate();
  }

  Future<void> setVoiceEffect(VoiceFilterPreset preset) async {
    if (_ended || _voiceEffect == preset) return;
    _voiceEffect = preset;
    _sendMediaState();
    _triggerStateUpdate();
  }

  void _sendMediaState() {
    for (final peerId in _peerConnections.keys) {
      _signaling?.sendMediaState(
        targetId: peerId,
        audio: !_isMuted,
        video: _isSelfVideoEnabled,
        screen: _isScreenSharing,
        screenStreamId: _isScreenSharing ? _localScreenStream?.id : null,
        voiceEffect: _voiceEffect.id,
      );
    }
  }

  Future<void> setSpeakerOn(bool speaker) async {
    if (_ended) return;
    // audio_session.configure sets attributes, but does not select the
    // WebRTC audio device. Native AudioSwitch owns routing on Android/iOS.
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        await Helper.setSpeakerphoneOn(speaker);
      } catch (_) {
        debugPrint('[WebRtcCallSession] Audio route unavailable');
        return;
      }
    }
    if (_ended) return;
    _isSpeakerOn = speaker;
    _triggerStateUpdate();
  }

  void _setState(CallSessionState newState) {
    if (_state == newState) return;
    _state = newState;
    _triggerStateUpdate();
  }

  void _triggerStateUpdate() {
    final data = currentData;
    onStateChanged?.call(data);
    if (!_stateController.isClosed) {
      _stateController.add(data);
    }
  }

  Future<void> end() async {
    _ended = true;
    _statsTimer?.cancel();
    _recoveryTimer?.cancel();
    _recoveryDeadline?.cancel();
    _durationTimer?.cancel();

    _setState(CallSessionState.ended);
    await dispose();
  }

  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    _ended = true;
    _statsTimer?.cancel();
    _recoveryTimer?.cancel();
    _recoveryDeadline?.cancel();
    _durationTimer?.cancel();
    _durationTimer = null;
    _localReactionTimer?.cancel();
    for (final t in _peerReactionTimers.values) {
      t.cancel();
    }
    _peerReactionTimers.clear();

    await _signalingSub?.cancel();
    _signalingSub = null;
    await _disconnectSub?.cancel();
    _disconnectSub = null;
    await _signalChain;

    if (_signaling != null) {
      await _signaling!.disconnect();
      _signaling = null;
    }

    await _stopScreenShareLocalOnly();

    for (final pc in _peerConnections.values) {
      try {
        await pc.close();
        await pc.dispose();
      } catch (_) {}
    }
    _peerConnections.clear();
    _pendingIce.clear();
    _remoteDescriptionReady.clear();

    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        try {
          await track.stop();
        } catch (_) {}
      }
      try {
        await _localStream!.dispose();
      } catch (_) {}
      _localStream = null;
    }

    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
    _remoteStream = null;
    _remoteStreams.clear();
    _remoteScreenStreams.clear();
    _peerStreams.clear();
    _remoteRendererBound = false;

    if (!_stateController.isClosed) {
      await _stateController.close();
    }
  }
}
