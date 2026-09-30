import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:pulse_flutter/models/api/call_models.dart';
import 'package:pulse_flutter/services/calls/call_session_types.dart';
import 'package:pulse_flutter/services/calls/webrtc_signaling_client.dart';

/// Manages a 1:1 or multi-party WebRTC call session via Nios WebRTC signaling.
class WebRtcCallSession {
  WebRtcCallSession({
    required this.chatId,
    required this.callId,
    required this.roomId,
    required this.isVideo,
    required this.direction,
    required this.displayName,
    this.peerName,
    this.peerAvatarUrl,
    this.peerUsername,
    this.isListener = false,
    required this.gatewayInfo,
    required this.localRenderer,
    required this.remoteRenderer,
    this.onStateChanged,
  });

  final int chatId;
  final int callId;
  final String roomId;
  final bool isVideo;
  final CallDirection direction;
  final String displayName;
  final String? peerName;
  final String? peerAvatarUrl;
  final String? peerUsername;
  final bool isListener;
  final ApiCallGatewayInfo gatewayInfo;

  final RTCVideoRenderer localRenderer;
  final RTCVideoRenderer remoteRenderer;
  final void Function(CallSessionData data)? onStateChanged;

  WebRtcSignalingClient? _signaling;
  StreamSubscription<Map<String, dynamic>>? _signalingSub;
  StreamSubscription<void>? _disconnectSub;

  final Map<int, RTCPeerConnection> _peerConnections = {};
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  CallSessionState _state = CallSessionState.idle;
  int _elapsedSeconds = 0;
  Timer? _durationTimer;
  bool _ended = false;

  late bool _isMuted = isListener;
  bool _isSpeakerOn = false;
  late bool _isSelfVideoEnabled = isVideo && !isListener;
  String? _fatalError;
  bool _peerSeen = false;

  final List<RemoteParticipant> _remoteParticipants = [];

  final StreamController<CallSessionData> _stateController =
      StreamController<CallSessionData>.broadcast();

  Stream<CallSessionData> get stateStream => _stateController.stream;

  CallSessionData get currentData => CallSessionData(
        state: _state,
        callId: callId,
        roomId: roomId,
        isVideo: isVideo,
        direction: direction,
        localClientId: _signaling?.localUserId,
        peerName: peerName,
        peerAvatarUrl: peerAvatarUrl,
        peerUsername: peerUsername,
        durationSeconds: _elapsedSeconds,
        remoteParticipants: List<RemoteParticipant>.unmodifiable(_remoteParticipants),
        isMuted: _isMuted,
        isSpeakerOn: _isSpeakerOn,
        isSelfVideoEnabled: _isSelfVideoEnabled,
        isListener: isListener,
        fatalError: _fatalError,
      );

  bool get wasAnswered => _peerSeen;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  Future<void> start() async {
    _setState(CallSessionState.connecting);

    try {
      await _configureAudioSession();
      await _initLocalMedia();

      final String signalUrl = gatewayInfo.signalUrl.isNotEmpty
          ? gatewayInfo.signalUrl
          : 'wss://c.ni-os.ru/signal';

      _signaling = WebRtcSignalingClient(
        signalUrl: signalUrl,
        token: gatewayInfo.callAccessToken,
      );

      _signalingSub = _signaling!.onMessage.listen(_onSignalingMessage);
      _disconnectSub = _signaling!.onDisconnected.listen((_) {
        if (!_ended) {
          _setState(CallSessionState.reconnecting);
        }
      });

      final bool connected = await _signaling!.connect();
      if (!connected) {
        _fatalError = 'Не удалось подключиться к серверу звонков';
        _setState(CallSessionState.ended);
        return;
      }

      _setState(CallSessionState.connected);
    } catch (e) {
      debugPrint('[WebRtcCallSession] Start failed: $e');
      _fatalError = 'Ошибка запуска звонка: $e';
      _setState(CallSessionState.ended);
    }
  }

  Future<void> _configureAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: _isSpeakerOn
            ? AVAudioSessionCategoryOptions(0x4 | 0x8) // defaultToSpeaker
            : AVAudioSessionCategoryOptions(0x4),
        avAudioSessionMode: AVAudioSessionMode.voiceChat,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: _isSpeakerOn ? AndroidAudioUsage.media : AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ));
    } catch (e) {
      debugPrint('[WebRtcCallSession] AudioSession config error: $e');
    }
  }

  Future<void> _initLocalMedia() async {
    if (isListener) {
      debugPrint('[WebRtcCallSession] Joining as listener only (no media capture)');
      return;
    }

    try {
      final int maxHeight = gatewayInfo.maxVideoHeight > 0 ? gatewayInfo.maxVideoHeight : 480;
      final int idealWidth = (maxHeight * 16 ~/ 9);

      final Map<String, dynamic> mediaConstraints = {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
          'highpassFilter': true,
        },
        'video': isVideo
            ? {
                'mandatory': {
                  'minWidth': '320',
                  'idealWidth': '$idealWidth',
                  'maxWidth': '$idealWidth',
                  'minHeight': '240',
                  'idealHeight': '$maxHeight',
                  'maxHeight': '$maxHeight',
                  'minFrameRate': '15',
                  'idealFrameRate': '30',
                },
                'facingMode': 'user',
                'optional': [],
              }
            : false,
      };

      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);

      if (isVideo && _localStream != null) {
        localRenderer.srcObject = _localStream;
      }

      if (_isMuted) {
        for (final track in _localStream?.getAudioTracks() ?? []) {
          track.enabled = false;
        }
      }
    } catch (e) {
      debugPrint('[WebRtcCallSession] Local media init failed: $e');
      // If mic/camera failed, continue as listener
    }
  }

  Map<String, dynamic> _buildRtcConfiguration() {
    final List<Map<String, dynamic>> iceServers = [];

    for (final s in gatewayInfo.iceServers) {
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
      iceServers.add({'urls': ['stun:c.ni-os.ru:3478', 'stun:stun.l.google.com:19302']});
    }

    return {
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
      'bundlePolicy': 'balanced',
    };
  }

  Future<RTCPeerConnection> _getOrCreatePeerConnection(int peerId, {String? peerDisplayName}) async {
    if (_peerConnections.containsKey(peerId)) {
      return _peerConnections[peerId]!;
    }

    final pc = await createPeerConnection(_buildRtcConfiguration());
    _peerConnections[peerId] = pc;

    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await pc.addTrack(track, _localStream!);
      }
    }

    pc.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null && _signaling != null) {
        _signaling!.sendIceCandidate(peerId, {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      }
    };

    pc.onTrack = (RTCTrackEvent event) {
      debugPrint('[WebRtcCallSession] Received remote track: ${event.track.kind}');
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        remoteRenderer.srcObject = _remoteStream;
        _onRemotePeerJoined(peerId, peerDisplayName);
      }
    };

    pc.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('[WebRtcCallSession] PC state with $peerId: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _onRemotePeerJoined(peerId, peerDisplayName);
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        debugPrint('[WebRtcCallSession] PC failed with $peerId');
      }
    };

    return pc;
  }

  void _onRemotePeerJoined(int peerId, String? name) {
    if (!_peerSeen) {
      _peerSeen = true;
      _startDurationTimer();
      _setState(CallSessionState.inCall);
    }

    final String displayName = name ?? peerName ?? 'User $peerId';
    final int idx = _remoteParticipants.indexWhere((p) => p.clientId == peerId);
    final participant = RemoteParticipant(
      clientId: peerId,
      nickname: displayName,
      lastSeen: DateTime.now(),
    );

    if (idx != -1) {
      _remoteParticipants[idx] = participant;
    } else {
      _remoteParticipants.add(participant);
    }

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
                // If localId < remoteId, this client initiates the offer
                final bool makeOffer = localId < remoteId;
                await _negotiatePeer(remoteId, makeOffer: makeOffer, peerName: name);
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

      case WebRtcSignalType.peerLeft:
        final int leftId = (msg['user_id'] as num?)?.toInt() ?? 0;
        _handlePeerLeft(leftId);
        break;

      case WebRtcSignalType.callEnded:
        final String reason = msg['reason']?.toString() ?? 'ended';
        debugPrint('[WebRtcCallSession] Call ended by server: $reason');
        _fatalError = reason == 'solo_timeout'
            ? 'Звонок завершён: на линии никого нет'
            : reason == 'duration_limit'
                ? 'Достигнут лимит длительности звонка'
                : 'Звонок завершён';
        _handleEnd();
        break;
    }
  }

  Future<void> _negotiatePeer(int remoteId, {required bool makeOffer, required String peerName}) async {
    final pc = await _getOrCreatePeerConnection(remoteId, peerDisplayName: peerName);

    if (makeOffer) {
      final RTCSessionDescription offer = await pc.createOffer({
        'offerToReceiveAudio': 1,
        'offerToReceiveVideo': isVideo ? 1 : 0,
      });
      await pc.setLocalDescription(offer);

      _signaling?.sendOffer(remoteId, {
        'type': offer.type,
        'sdp': offer.sdp,
      });
      debugPrint('[WebRtcCallSession] Sent offer to peer $remoteId');
    }
  }

  Future<void> _handleOffer(int fromId, Map sdpData) async {
    final pc = await _getOrCreatePeerConnection(fromId);
    final String sdp = sdpData['sdp']?.toString() ?? '';
    final String type = sdpData['type']?.toString() ?? 'offer';

    await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
    final RTCSessionDescription answer = await pc.createAnswer({
      'offerToReceiveAudio': 1,
      'offerToReceiveVideo': isVideo ? 1 : 0,
    });
    await pc.setLocalDescription(answer);

    _signaling?.sendAnswer(fromId, {
      'type': answer.type,
      'sdp': answer.sdp,
    });
    debugPrint('[WebRtcCallSession] Sent answer to peer $fromId');
  }

  Future<void> _handleAnswer(int fromId, Map sdpData) async {
    final pc = _peerConnections[fromId];
    if (pc == null) return;

    final String sdp = sdpData['sdp']?.toString() ?? '';
    final String type = sdpData['type']?.toString() ?? 'answer';
    await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
    debugPrint('[WebRtcCallSession] Applied answer from peer $fromId');
  }

  Future<void> _handleIce(int fromId, Map candidateData) async {
    final pc = _peerConnections[fromId];
    if (pc == null) return;

    final String? candidate = candidateData['candidate']?.toString();
    final String? sdpMid = candidateData['sdpMid']?.toString();
    final int? sdpMLineIndex = (candidateData['sdpMLineIndex'] as num?)?.toInt();

    if (candidate != null) {
      await pc.addCandidate(RTCIceCandidate(candidate, sdpMid, sdpMLineIndex));
    }
  }

  void _handlePeerLeft(int peerId) {
    final pc = _peerConnections.remove(peerId);
    pc?.close();
    pc?.dispose();
    _remoteParticipants.removeWhere((p) => p.clientId == peerId);

    if (_remoteParticipants.isEmpty) {
      // Last remote peer left
      _handleEnd();
    } else {
      _triggerStateUpdate();
    }
  }

  void _handleEnd() {
    if (_ended) return;
    _ended = true;
    _durationTimer?.cancel();
    _setState(CallSessionState.ended);
  }

  Future<void> setMuted(bool muted) async {
    _isMuted = muted;
    if (_localStream != null) {
      for (final track in _localStream!.getAudioTracks()) {
        track.enabled = !muted;
      }
    }
    _signaling?.sendMediaState(audio: !muted, video: _isSelfVideoEnabled);
    _triggerStateUpdate();
  }

  Future<void> setLocalVideoEnabled(bool enabled) async {
    _isSelfVideoEnabled = enabled;
    if (_localStream != null) {
      for (final track in _localStream!.getVideoTracks()) {
        track.enabled = enabled;
      }
    }
    _signaling?.sendMediaState(audio: !_isMuted, video: enabled);
    _triggerStateUpdate();
  }

  Future<void> switchCamera() async {
    if (_localStream == null) return;
    final videoTracks = _localStream!.getVideoTracks();
    if (videoTracks.isNotEmpty) {
      await Helper.switchCamera(videoTracks.first);
    }
  }

  Future<void> setSpeakerOn(bool speaker) async {
    _isSpeakerOn = speaker;
    await _configureAudioSession();
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
    if (_ended) return;
    _ended = true;
    _durationTimer?.cancel();

    _setState(CallSessionState.ended);
    await dispose();
  }

  Future<void> dispose() async {
    _ended = true;
    _durationTimer?.cancel();
    _durationTimer = null;

    await _signalingSub?.cancel();
    _signalingSub = null;
    await _disconnectSub?.cancel();
    _disconnectSub = null;

    if (_signaling != null) {
      await _signaling!.disconnect();
      _signaling = null;
    }

    for (final pc in _peerConnections.values) {
      try {
        await pc.close();
        await pc.dispose();
      } catch (_) {}
    }
    _peerConnections.clear();

    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        try {
          track.stop();
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

    if (!_stateController.isClosed) {
      await _stateController.close();
    }
  }
}
