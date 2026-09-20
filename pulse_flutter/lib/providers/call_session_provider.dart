import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:pulse_flutter/core/utils/shared_utilities.dart';
import 'package:pulse_flutter/models/api/call_models.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/services/calls/call_session_types.dart';
import 'package:pulse_flutter/services/calls/webrtc_call_service.dart';

/// Provider for the current active call session manager.
///
/// `null` when no call is active.
final callSessionProvider =
    NotifierProvider<CallSessionNotifier, CallSessionManager?>(
  CallSessionNotifier.new,
);

class CallSessionNotifier extends Notifier<CallSessionManager?> {
  @override
  CallSessionManager? build() => null;

  void setSession(CallSessionManager? manager) => state = manager;

  /// Trigger rebuild of widgets watching this provider
  void notify() {
    final CallSessionManager? cur = state;
    state = null;
    state = cur;
  }
}

/// Orchestrates the WebRTC 1:1 call session with Riverpod and application lifecycle.
class CallSessionManager {
  CallSessionManager({
    required this.ref,
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
    this.gatewayInfo,
  }) {
    _service = WebrtcCallService(
      sendWsAction: (String action, Map<String, dynamic> payload) async {
        final dynamic res = await ref
            .read(webSocketClientProvider)
            .request(action, payload: payload);
        // request() resolves with the full envelope
        // {action, payload, request_id, error}; the handler result the call
        // service needs (call_access_token, signal_url, ice_servers, ...)
        // lives inside `payload`.
        final Map<String, dynamic> envelope = asStringMap(res);
        final dynamic inner = envelope['payload'];
        return inner is Map ? asStringMap(inner) : envelope;
      },
    );

    _service.roomId = roomId;
    _service.chatId = chatId;
    _service.messageId = callId;
    _service.isVideo = isVideo;
    _service.peerName = peerName;

    _service.onChanged = _onServiceChanged;
    _emitCurrentData();
  }

  final dynamic ref;
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
  final ApiCallGatewayInfo? gatewayInfo;

  late final WebrtcCallService _service;
  final StreamController<CallSessionData> _stateController =
      StreamController<CallSessionData>.broadcast();

  Timer? _soloTimer;
  Timer? _tickerTimer;
  bool _ended = false;

  WebrtcCallService get service => _service;
  CallState get state => _service.state;
  int get durationSeconds => _service.durationSeconds;
  bool get isMuted => _service.isMuted;
  bool get isSpeakerOn => _service.isSpeakerOn;
  MediaStream? get localStream => _service.localStream;
  Map<int, MediaStream> get remoteStreams => _service.remoteStreams;
  Stream<CallSessionData> get stateStream => _stateController.stream;

  CallSessionData get currentData {
    CallSessionState mappedState = CallSessionState.idle;
    switch (_service.state) {
      case CallState.idle:
        mappedState = CallSessionState.idle;
        break;
      case CallState.calling:
      case CallState.incoming:
      case CallState.connecting:
        mappedState = CallSessionState.connecting;
        break;
      case CallState.connected:
        mappedState = CallSessionState.inCall;
        break;
      case CallState.ending:
        mappedState = CallSessionState.ended;
        break;
    }

    final List<RemoteParticipant> participants = <RemoteParticipant>[];
    for (final int peerId in _service.peers.keys) {
      participants.add(RemoteParticipant(
        clientId: peerId,
        nickname: _service.peerName ?? 'Собеседник',
      ));
    }

    return CallSessionData(
      state: mappedState,
      callId: callId,
      roomId: roomId,
      isVideo: _service.isVideo,
      direction: direction,
      peerName: _service.peerName ?? peerName,
      peerAvatarUrl: peerAvatarUrl,
      peerUsername: peerUsername,
      isMuted: _service.isMuted,
      isSpeakerOn: _service.isSpeakerOn,
      isSelfVideoEnabled: !_service.isMuted,
      isListener: isListener,
      durationSeconds: _service.durationSeconds,
      remoteParticipants: participants,
    );
  }

  void _emitCurrentData() {
    if (!_stateController.isClosed) {
      _stateController.add(currentData);
    }
  }

  void _onServiceChanged() {
    _emitCurrentData();
    ref.read(callSessionProvider.notifier).notify();

    if (_service.state == CallState.connected && _tickerTimer == null) {
      _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _emitCurrentData();
      });
    }

    // Handle solo timeout (Rule: max 3 minutes waiting alone in room)
    if (_service.state == CallState.connected) {
      if (_service.peers.isEmpty) {
        _soloTimer ??= Timer(const Duration(minutes: 3), () {
          debugPrint('[CallSessionManager] Solo 3-minute timeout reached. Ending call.');
          end();
        });
      } else {
        _soloTimer?.cancel();
        _soloTimer = null;
      }
    }

    // Handle max quota duration
    if (gatewayInfo?.maxDurationSeconds != null &&
        _service.durationSeconds >= gatewayInfo!.maxDurationSeconds!) {
      debugPrint(
        '[CallSessionManager] Max quota duration reached (${gatewayInfo!.maxDurationSeconds}s). Ending call.',
      );
      end();
    }

    if (_service.state == CallState.idle && !_ended) {
      _ended = true;
      _cleanup();
      ref.read(callSessionProvider.notifier).setSession(null);
    }
  }

  /// Start outgoing call flow.
  ///
  /// [startResponse] is the handler result of the `start_call` request the
  /// caller already issued: re-sending it here would open a second room and
  /// leave the first one to time out and kill the live call.
  Future<void> start({
    required Map<String, dynamic> startResponse,
    String? peerDisplayName,
  }) async {
    try {
      await _service.adoptStart(
        startResponse,
        peerDisplayName: peerDisplayName ?? peerName,
      );
    } catch (e) {
      debugPrint('[CallSessionManager] startCall error: $e');
      await end();
      rethrow;
    }
  }

  /// Called when `call_joined` push is received from WS
  Future<void> onCallJoined(Map<String, dynamic> payload) async {
    await _service.onCallJoined(payload);
  }

  /// Accept incoming call
  Future<void> accept() async {
    await _service.accept();
  }

  /// Decline incoming call
  Future<void> decline() async {
    await _service.decline();
    await end();
  }

  /// End call locally
  Future<void> end() async {
    if (_ended) return;
    _ended = true;
    _cleanup();
    await _service.hangUp();
    ref.read(callSessionProvider.notifier).setSession(null);
  }

  /// Server or remote peer ended call
  Future<void> remoteEnd({Map<String, dynamic>? payload}) async {
    if (_ended) return;
    _ended = true;
    _cleanup();
    if (payload != null) {
      await _service.onServerEndCall(payload);
    } else {
      await _service.reset();
    }
    ref.read(callSessionProvider.notifier).setSession(null);
  }

  RTCVideoRenderer get localRenderer => _service.localRenderer;
  RTCVideoRenderer get remoteRenderer => _service.remoteRenderer;
  bool get isLocalVideoEnabled => _service.isLocalVideoEnabled;
  Future<void> initRenderers() => _service.initRenderers();

  void toggleMute({bool? muted}) => _service.toggleMute(muted: muted);
  void setMuted(bool muted) => _service.toggleMute(muted: muted);
  void toggleVideo({bool? enabled}) => _service.toggleVideo(enabled: enabled);
  void setLocalVideoEnabled(bool enabled) => _service.toggleVideo(enabled: enabled);
  Future<void> toggleSpeaker({bool? speaker}) => _service.toggleSpeaker(speaker: speaker);
  Future<void> setSpeakerOn(bool speaker) => _service.toggleSpeaker(speaker: speaker);
  Future<void> switchCamera() => _service.switchCamera();

  void _cleanup() {
    _soloTimer?.cancel();
    _soloTimer = null;
    _tickerTimer?.cancel();
    _tickerTimer = null;
  }

  void dispose() {
    _cleanup();
    _service.reset();
    _stateController.close();
  }

  /// Compatibility getter returning this manager as the session object
  CallSessionManager get session => this;
}

class IsCallScreenOpenNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setOpen(bool open) => state = open;
}

final isCallScreenOpenProvider =
    NotifierProvider<IsCallScreenOpenNotifier, bool>(
  IsCallScreenOpenNotifier.new,
);
