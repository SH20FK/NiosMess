import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Call lifecycle states per CALLS_GUIDE_20260916.md.
enum CallState {
  idle,
  calling,
  incoming,
  connecting,
  connected,
  ending,
}

/// WebRTC Call Service implementing the exact protocol from CALLS_GUIDE_20260916.md.
///
/// Handles:
/// - Main WS coordination (`start_call`, `join_call`, `decline_call`, `end_call`)
/// - Direct WebRTC signaling via `signal_url` (`ready`, `offer`, `answer`, `ice`, `heartbeat`)
/// - Deterministic offerer decision (`mySignalId < peerId`)
/// - ICE candidate buffering and ICE restart
/// - Microphones, cameras, speakerphones, and renderers
const Duration _mediaTimeout = Duration(seconds: 15);
const Duration _signalTimeout = Duration(seconds: 15);

class WebrtcCallService {
  WebrtcCallService({required this.sendWsAction});

  /// Delegate for sending requests to the main `/ws` connection.
  final Future<Map<String, dynamic>> Function(
    String action,
    Map<String, dynamic> payload,
  ) sendWsAction;

  CallState state = CallState.idle;
  String? roomId;
  int? chatId;
  int? messageId;
  bool isVideo = false;
  String? callerNickname;
  String? peerName;
  int? mySignalId;
  DateTime? startedAt;
  bool isMuted = false;
  bool isSpeakerOn = false;

  MediaStream? localStream;
  WebSocketChannel? _signal;
  StreamSubscription<dynamic>? _signalSub;
  Timer? _heartbeat;
  Future<void> _queue = Future<void>.value();
  List<Map<String, dynamic>> _iceServers = <Map<String, dynamic>>[];
  final Map<int, RTCPeerConnection> peers = <int, RTCPeerConnection>{};
  final Map<int, List<RTCIceCandidate>> _iceBuf = <int, List<RTCIceCandidate>>{};
  final Map<int, MediaStream> remoteStreams = <int, MediaStream>{};

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  bool _renderersInitialized = false;
  bool isLocalVideoEnabled = true;

  Map<String, dynamic>? _pendingStartResponse;

  /// Initialize video renderers if needed (e.g. for video call views)
  Future<void> initRenderers() async {
    if (!_renderersInitialized) {
      await localRenderer.initialize();
      await remoteRenderer.initialize();
      _renderersInitialized = true;
      if (localStream != null) {
        localRenderer.srcObject = localStream;
      }
      if (remoteStreams.isNotEmpty) {
        remoteRenderer.srcObject = remoteStreams.values.first;
      }
      onChanged?.call();
    }
  }

  /// Listeners
  void Function()? onChanged;

  int get durationSeconds {
    if (startedAt == null || state != CallState.connected) return 0;
    return DateTime.now().difference(startedAt!).inSeconds;
  }

  // ── Звонящий (Caller) ─────────────────────────────────────────────

  /// Adopts the `start_call` already issued by the caller and stays in
  /// [CallState.calling] until the server broadcasts `call_joined`.
  Future<void> adoptStart(
    Map<String, dynamic> startResponse, {
    String? peerDisplayName,
  }) async {
    if (state != CallState.idle) return;

    final dynamic error = startResponse['error'];
    if (error != null) {
      throw Exception(error.toString());
    }

    peerName = peerDisplayName ?? peerName;
    state = CallState.calling;
    isSpeakerOn = isVideo;
    isMuted = false;

    final dynamic msgIdRaw = startResponse['message_id'];
    if (msgIdRaw is num) {
      messageId = msgIdRaw.toInt();
    } else if (msgIdRaw is String) {
      messageId = int.tryParse(msgIdRaw) ?? messageId;
    }

    _pendingStartResponse = startResponse;
    onChanged?.call();
  }

  /// Event from main WS: `call_joined`
  ///
  /// Callee accepted the call. Caller now acquires media and connects to `signal_url`.
  Future<void> onCallJoined(Map<String, dynamic> payload) async {
    final String? incomingRoomId = payload['room_id']?.toString();
    if (incomingRoomId != roomId || state != CallState.calling) return;

    state = CallState.connecting;
    onChanged?.call();

    try {
      if (_pendingStartResponse != null) {
        await _connectMedia(_pendingStartResponse!);
      }
    } catch (e) {
      debugPrint('[WebrtcCallService] onCallJoined media connection failed: $e');
      await reset();
    }
  }

  // ── Принимающий (Callee) ──────────────────────────────────────────

  /// Event from main WS (`new_call`) or FCM push.
  ///
  /// Deduplicated strictly by `room_id`.
  Future<void> onIncoming(Map<String, dynamic> raw) async {
    final int? incomingChatId = int.tryParse(raw['chat_id']?.toString() ?? '');
    final int? incomingMsgId = int.tryParse(raw['message_id']?.toString() ?? '');
    final String? incomingRoomId = raw['room_id']?.toString();
    final bool incomingIsVideo = raw['is_video'] == true ||
        raw['is_video'] == 'true' ||
        raw['is_video'] == 1 ||
        raw['is_video'] == '1';
    final String incomingCallerNickname =
        raw['caller_nickname']?.toString() ?? raw['caller_name']?.toString() ?? 'Собеседник';

    if (incomingChatId == null || incomingRoomId == null || incomingRoomId.isEmpty) {
      return;
    }

    // 1. Deduplication: if already processing this room, ignore duplicate
    if (incomingRoomId == roomId) {
      debugPrint('[WebrtcCallService] Duplicate incoming call event for room $roomId ignored');
      return;
    }

    // 2. Busy handling: if already in another call, reject the incoming one immediately
    if (state != CallState.idle) {
      debugPrint('[WebrtcCallService] Busy in state $state: declining incoming call $incomingRoomId');
      try {
        await sendWsAction('decline_call', <String, dynamic>{
          'chat_id': incomingChatId,
          'room_id': incomingRoomId,
        });
      } catch (_) {}
      return;
    }

    roomId = incomingRoomId;
    chatId = incomingChatId;
    messageId = incomingMsgId;
    isVideo = incomingIsVideo;
    callerNickname = incomingCallerNickname;
    peerName = incomingCallerNickname;
    isSpeakerOn = incomingIsVideo;
    isMuted = false;
    state = CallState.incoming;
    onChanged?.call();
  }

  /// Callee accepted the incoming call.
  Future<void> accept() async {
    if (state != CallState.incoming) return;

    state = CallState.connecting;
    onChanged?.call();

    try {
      final Map<String, dynamic> r = await sendWsAction('join_call', <String, dynamic>{
        'chat_id': chatId,
        'room_id': roomId,
        'message_id': messageId,
      });

      final dynamic error = r['error'];
      if (error != null) {
        throw Exception(error.toString());
      }

      await _connectMedia(r);
    } catch (e) {
      debugPrint('[WebrtcCallService] accept call failed: $e');
      await reset();
      rethrow;
    }
  }

  /// Callee declined the incoming call.
  Future<void> decline() async {
    if (state == CallState.incoming) {
      try {
        if (chatId != null && roomId != null) {
          await sendWsAction('decline_call', <String, dynamic>{
            'chat_id': chatId,
            'room_id': roomId,
          });
        }
      } catch (_) {}
    }
    await reset();
  }

  // ── Общее подключение медиа (WebRTC) ──────────────────────────────

  Future<void> _connectMedia(Map<String, dynamic> r) async {
    final String? token = r['call_access_token']?.toString();
    final String? signalUrl = r['signal_url']?.toString();
    if (token == null || signalUrl == null) {
      throw Exception('Missing call_access_token or signal_url in response');
    }

    final dynamic rawIce = r['ice_servers'];
    if (rawIce is List) {
      _iceServers = rawIce
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } else {
      _iceServers = <Map<String, dynamic>>[];
    }

    final int maxH = (r['max_video_height'] is num)
        ? (r['max_video_height'] as num).toInt()
        : 480;

    // 1) СНАЧАЛА микрофон/камера (getUserMedia)
    try {
      localStream = await navigator.mediaDevices.getUserMedia(<String, dynamic>{
        'audio': <String, dynamic>{
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': isVideo
            ? <String, dynamic>{
                'facingMode': 'user',
                'height': <String, dynamic>{'ideal': maxH},
              }
            : false,
      }).timeout(_mediaTimeout);
    } catch (e) {
      debugPrint('[WebrtcCallService] getUserMedia failed: $e. Falling back to audio-only');
      if (isVideo) {
        isVideo = false;
        localStream = await navigator.mediaDevices.getUserMedia(<String, dynamic>{
          'audio': <String, dynamic>{
            'echoCancellation': true,
            'noiseSuppression': true,
            'autoGainControl': true,
          },
          'video': false,
        }).timeout(_mediaTimeout);
      }
    }

    // Маршрутизация звука: аудио — в разговорный динамик, видео — на громкую связь
    try {
      await Helper.setSpeakerphoneOn(isVideo);
      isSpeakerOn = isVideo;
    } catch (_) {}

    if (_renderersInitialized && localStream != null) {
      localRenderer.srcObject = localStream;
    }

    if (state == CallState.idle) {
      await _stopLocal();
      return;
    }

    // 2) ПОТОМ сигналка. Обработчик сообщений вешается ДО открытия сокета
    final Uri url = Uri.parse('$signalUrl?token=${Uri.encodeQueryComponent(token)}');
    debugPrint('[WebrtcCallService] Connecting to signal: $signalUrl');

    _signal = WebSocketChannel.connect(url);
    _signalSub = _signal!.stream.listen(
      (dynamic raw) {
        try {
          final Map<String, dynamic> msg = jsonDecode(raw.toString()) as Map<String, dynamic>;
          // Строго последовательная обработка в очереди
          _queue = _queue.then((_) => _onSignal(msg)).catchError((Object e) {
            debugPrint('[WebrtcCallService] Signal handling error: $e');
          });
        } catch (e) {
          debugPrint('[WebrtcCallService] Signal parse error: $e');
        }
      },
      onError: (Object err) {
        debugPrint('[WebrtcCallService] Signal socket error: $err');
      },
      onDone: () {
        final int? code = _signal?.closeCode;
        debugPrint('[WebrtcCallService] Signal socket closed with code: $code');
        // 4001: replaced by a newer connection from the same account; do not hang up
        if (state != CallState.idle && state != CallState.ending && code != 4001) {
          hangUp();
        }
      },
    );

    await _signal!.ready.timeout(_signalTimeout);
    _startHeartbeat();

    state = CallState.connected;
    startedAt = DateTime.now();
    onChanged?.call();
  }

  Future<void> _onSignal(Map<String, dynamic> m) async {
    final String type = m['type']?.toString() ?? '';
    debugPrint('[WebrtcCallService] Signal received: $type');

    switch (type) {
      case 'ready':
        mySignalId = int.tryParse(m['user_id']?.toString() ?? '');
        final dynamic peersList = m['peers'];
        if (peersList is List) {
          for (final dynamic p in peersList) {
            if (p is Map) {
              final int? id = int.tryParse(p['user_id']?.toString() ?? '');
              if (id != null && mySignalId != null) {
                // Rule 4: offerer is the one with smaller user_id
                await _peer(id, makeOffer: mySignalId! < id);
              }
            }
          }
        }
        return;

      case 'peer_joined':
        final int? id = int.tryParse(m['user_id']?.toString() ?? '');
        if (id != null && mySignalId != null) {
          await _peer(id, makeOffer: mySignalId! < id);
        }
        return;

      case 'peer_left':
        final int? id = int.tryParse(m['user_id']?.toString() ?? '');
        if (id != null) {
          final RTCPeerConnection? pc = peers.remove(id);
          await pc?.close();
          remoteStreams.remove(id);
          onChanged?.call();
          if (peers.isEmpty) {
            // 1:1 call: remote peer left -> hang up
            await hangUp();
          }
        }
        return;

      case 'call_ended':
        await hangUp();
        return;

      case 'offer':
        final int? from = int.tryParse(m['from_id']?.toString() ?? '');
        if (from == null) return;
        final RTCPeerConnection pc = await _peer(from, makeOffer: false);
        final Map<String, dynamic> sdpMap = Map<String, dynamic>.from(m['sdp'] as Map);
        await pc.setRemoteDescription(
          RTCSessionDescription(sdpMap['sdp']?.toString(), sdpMap['type']?.toString()),
        );
        final RTCSessionDescription answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);
        _sendSignal(<String, dynamic>{
          'type': 'answer',
          'target_id': from,
          'sdp': <String, dynamic>{
            'type': answer.type,
            'sdp': answer.sdp,
          },
        });
        await _flushIce(from, pc);
        return;

      case 'answer':
        final int? from = int.tryParse(m['from_id']?.toString() ?? '');
        if (from == null) return;
        final RTCPeerConnection pc = await _peer(from, makeOffer: false);
        final Map<String, dynamic> sdpMap = Map<String, dynamic>.from(m['sdp'] as Map);
        await pc.setRemoteDescription(
          RTCSessionDescription(sdpMap['sdp']?.toString(), sdpMap['type']?.toString()),
        );
        await _flushIce(from, pc);
        return;

      case 'ice':
        final int? from = int.tryParse(m['from_id']?.toString() ?? '');
        final dynamic candMap = m['candidate'];
        if (from == null || candMap is! Map) return;

        final RTCIceCandidate cand = RTCIceCandidate(
          candMap['candidate']?.toString(),
          candMap['sdpMid']?.toString(),
          (candMap['sdpMLineIndex'] is num) ? (candMap['sdpMLineIndex'] as num).toInt() : 0,
        );

        final RTCPeerConnection? pc = peers[from];
        if (pc != null && await pc.getRemoteDescription() != null) {
          await pc.addCandidate(cand);
        } else {
          (_iceBuf[from] ??= <RTCIceCandidate>[]).add(cand);
        }
        return;
    }
  }

  Future<RTCPeerConnection> _peer(int id, {required bool makeOffer}) async {
    final RTCPeerConnection? existing = peers[id];
    if (existing != null) return existing;

    final Map<String, dynamic> configuration = <String, dynamic>{
      'iceServers': _iceServers,
      'sdpSemantics': 'unified-plan',
    };

    final RTCPeerConnection pc = await createPeerConnection(configuration);
    peers[id] = pc;

    if (localStream != null) {
      for (final MediaStreamTrack t in localStream!.getTracks()) {
        await pc.addTrack(t, localStream!);
      }
    }

    pc.onIceCandidate = (RTCIceCandidate c) {
      if (c.candidate == null) return;
      _sendSignal(<String, dynamic>{
        'type': 'ice',
        'target_id': id,
        'candidate': <String, dynamic>{
          'candidate': c.candidate,
          'sdpMid': c.sdpMid,
          'sdpMLineIndex': c.sdpMLineIndex,
        },
      });
    };

    pc.onTrack = (RTCTrackEvent e) {
      if (e.streams.isNotEmpty) {
        remoteStreams[id] = e.streams.first;
        if (_renderersInitialized) {
          remoteRenderer.srcObject = e.streams.first;
        }
        onChanged?.call();
      }
    };

    pc.onConnectionState = (RTCPeerConnectionState s) async {
      debugPrint('[WebrtcCallService] Peer $id connection state: $s');
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed && makeOffer) {
        debugPrint('[WebrtcCallService] Connection failed. Initiating ICE restart...');
        final RTCSessionDescription o = await pc.createOffer(<String, dynamic>{'iceRestart': true});
        await pc.setLocalDescription(o);
        _sendSignal(<String, dynamic>{
          'type': 'offer',
          'target_id': id,
          'sdp': <String, dynamic>{'type': o.type, 'sdp': o.sdp},
        });
      }
      onChanged?.call();
    };

    if (makeOffer) {
      final RTCSessionDescription o = await pc.createOffer();
      await pc.setLocalDescription(o);
      _sendSignal(<String, dynamic>{
        'type': 'offer',
        'target_id': id,
        'sdp': <String, dynamic>{'type': o.type, 'sdp': o.sdp},
      });
    }

    return pc;
  }

  Future<void> _flushIce(int id, RTCPeerConnection pc) async {
    final List<RTCIceCandidate>? pending = _iceBuf.remove(id);
    if (pending != null) {
      for (final RTCIceCandidate c in pending) {
        await pc.addCandidate(c);
      }
    }
  }

  void _sendSignal(Map<String, dynamic> msg) {
    if (_signal == null) return;
    try {
      _signal!.sink.add(jsonEncode(msg));
    } catch (e) {
      debugPrint('[WebrtcCallService] sendSignal failed: $e');
    }
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 25), (_) {
      _sendSignal(<String, dynamic>{'type': 'heartbeat'});
    });
  }

  // ── Завершение звонка ──────────────────────────────────────────────

  /// Local user hangs up
  Future<void> hangUp() async {
    if (chatId != null && roomId != null) {
      try {
        await sendWsAction('end_call', <String, dynamic>{
          'chat_id': chatId,
          'room_id': roomId,
          'message_id': messageId,
          'duration': durationSeconds,
          'was_missed': state != CallState.connected,
        });
      } catch (e) {
        debugPrint('[WebrtcCallService] end_call WS action failed: $e');
      }
    }
    await reset();
  }

  /// Server sent `end_call` or `call_ended`
  Future<void> onServerEndCall(Map<String, dynamic> payload) async {
    debugPrint('[WebrtcCallService] onServerEndCall: $payload');
    state = CallState.ending;
    onChanged?.call();
    await reset();
  }

  // ── Управление контролами ──────────────────────────────────────────

  void toggleMute({bool? muted}) {
    isMuted = muted ?? !isMuted;
    localStream?.getAudioTracks().forEach((MediaStreamTrack t) {
      t.enabled = !isMuted;
    });
    onChanged?.call();
  }

  void toggleVideo({bool? enabled}) {
    isLocalVideoEnabled = enabled ?? !isLocalVideoEnabled;
    localStream?.getVideoTracks().forEach((MediaStreamTrack t) {
      t.enabled = isLocalVideoEnabled;
    });
    onChanged?.call();
  }

  Future<void> switchCamera() async {
    final List<MediaStreamTrack>? videoTracks = localStream?.getVideoTracks();
    if (videoTracks != null && videoTracks.isNotEmpty) {
      await Helper.switchCamera(videoTracks.first);
      onChanged?.call();
    }
  }

  Future<void> toggleSpeaker({bool? speaker}) async {
    isSpeakerOn = speaker ?? !isSpeakerOn;
    try {
      await Helper.setSpeakerphoneOn(isSpeakerOn);
    } catch (_) {}
    onChanged?.call();
  }

  Future<void> reset() async {
    _heartbeat?.cancel();
    _heartbeat = null;

    _sendSignal(<String, dynamic>{'type': 'leave'});

    await _signalSub?.cancel();
    _signalSub = null;

    await _signal?.sink.close();
    _signal = null;

    for (final RTCPeerConnection pc in peers.values) {
      try {
        await pc.close();
      } catch (_) {}
    }
    peers.clear();
    _iceBuf.clear();
    remoteStreams.clear();

    if (_renderersInitialized) {
      localRenderer.srcObject = null;
      remoteRenderer.srcObject = null;
    }
    isLocalVideoEnabled = true;

    await _stopLocal();

    _queue = Future<void>.value();
    roomId = null;
    chatId = null;
    messageId = null;
    callerNickname = null;
    peerName = null;
    mySignalId = null;
    startedAt = null;
    _pendingStartResponse = null;
    isVideo = false;
    isMuted = false;
    isSpeakerOn = false;

    state = CallState.idle;
    onChanged?.call();
  }

  Future<void> dispose() async {
    await reset();
    if (_renderersInitialized) {
      await localRenderer.dispose();
      await remoteRenderer.dispose();
      _renderersInitialized = false;
    }
  }

  Future<void> _stopLocal() async {
    if (localStream != null) {
      for (final MediaStreamTrack t in localStream!.getTracks()) {
        try {
          await t.stop();
        } catch (_) {}
      }
      try {
        await localStream?.dispose();
      } catch (_) {}
      localStream = null;
    }
  }
}
