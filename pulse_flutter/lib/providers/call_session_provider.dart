import 'dart:async';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:pulse_flutter/core/utils/shared_utilities.dart';
import 'package:pulse_flutter/models/api/call_models.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/services/calls/call_session.dart';
import 'package:pulse_flutter/services/e2ee_service.dart';

/// Provider for the current active call session manager.
///
/// `null` when no call is active.
final callSessionProvider =
    NotifierProvider<CallSessionNotifier, CallSessionManager?>(
  CallSessionNotifier.new,
);

/// Long-lived [Ref] for call sessions, which outlive the widget that started them.
final callRefProvider = Provider<Ref>((Ref ref) => ref);

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

/// Orchestrates a 1:1 NiosCalls session (own protocol over the SFU) and wires
/// it into Riverpod plus the server-side call signalling.
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
  });

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

  CallSession? _session;
  StreamSubscription<CallSessionData>? _sessionSub;
  final StreamController<CallSessionData> _stateController =
      StreamController<CallSessionData>.broadcast();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  Timer? _soloTimer;
  bool _ended = false;
  bool _renderersReady = false;

  Stream<CallSessionData> get stateStream => _stateController.stream;

  CallSessionData get currentData {
    final CallSession? session = _session;
    if (session == null) {
      return CallSessionData(
        state: CallSessionState.connecting,
        callId: callId,
        roomId: roomId,
        isVideo: isVideo,
        direction: direction,
        peerName: peerName,
        peerAvatarUrl: peerAvatarUrl,
        peerUsername: peerUsername,
        isListener: isListener,
        durationSeconds: 0,
      );
    }
    final CallSessionData data = session.currentData;
    return data.copyWith(
      peerName: data.peerName ?? peerName,
      peerAvatarUrl: peerAvatarUrl,
      peerUsername: peerUsername,
      direction: direction,
    );
  }

  CallSessionState get state => currentData.state;

  bool get isActive =>
      state != CallSessionState.idle && state != CallSessionState.ended;
  int get durationSeconds => currentData.durationSeconds;
  bool get isMuted => currentData.isMuted;
  bool get isSpeakerOn => currentData.isSpeakerOn;

  Future<Map<String, dynamic>> _sendWsAction(
    String action,
    Map<String, dynamic> payload,
  ) async {
    final dynamic res = await ref
        .read(webSocketClientProvider)
        .request(action, payload: payload);
    return asStringMap(res);
  }

  Future<Uint8List> _deriveMediaKey() async {
    try {
      final String? partnerKey =
          ref.read(chatByIdProvider(chatId))?.partnerPublicKey as String?;
      if (partnerKey != null && partnerKey.isNotEmpty) {
        final SecretKey key = await ref
            .read(e2eeServiceProvider)
            .deriveCallKey(callId, theirPublicKeyBase64: partnerKey);
        return Uint8List.fromList(await key.extractBytes());
      }
    } catch (e) {
      debugPrint('[CallSessionManager] media key derivation failed: $e');
    }
    final SecretKey fallback = await AesGcm.with256bits().newSecretKey();
    return Uint8List.fromList(await fallback.extractBytes());
  }

  Future<CallSession> _ensureSession() async {
    final CallSession? existing = _session;
    if (existing != null) return existing;

    final CallSession session = CallSession(
      chatId: chatId,
      callId: callId,
      roomId: roomId,
      isVideo: false,
      direction: direction,
      displayName: displayName,
      peerName: peerName,
      aesKeyBytes: await _deriveMediaKey(),
      isListener: isListener,
    );
    _session = session;
    _sessionSub = session.stateStream.listen(_onSessionData);
    return session;
  }

  void _onSessionData(CallSessionData data) {
    if (!_stateController.isClosed) {
      _stateController.add(currentData);
    }
    ref.read(callSessionProvider.notifier).notify();

    if (data.state == CallSessionState.connected) {
      if (data.remoteParticipants.isEmpty) {
        _soloTimer ??= Timer(const Duration(minutes: 3), () {
          debugPrint('[CallSessionManager] Solo timeout reached, ending call.');
          end();
        });
      } else {
        _soloTimer?.cancel();
        _soloTimer = null;
      }
    }

    final int? maxDuration = gatewayInfo?.maxDurationSeconds;
    if (maxDuration != null && data.durationSeconds >= maxDuration) {
      debugPrint('[CallSessionManager] Max call duration reached.');
      end();
    }

    if (data.state == CallSessionState.ended && !_ended) {
      _ended = true;
      _cleanup();
      ref.read(callSessionProvider.notifier).setSession(null);
    }
  }

  Future<void> _connect() async {
    final CallSession session = await _ensureSession();
    await session.start(preferQuic: true);
  }

  /// Starts the media session for an outgoing call. The server-side
  /// `start_call` has already been performed by the call starter.
  Future<void> start({
    required Map<String, dynamic> startResponse,
    String? peerDisplayName,
  }) async {
    try {
      await _connect();
    } catch (e) {
      debugPrint('[CallSessionManager] start failed: $e');
      await end();
      rethrow;
    }
  }

  /// The SFU tracks participants itself, so `call_joined` needs no action.
  Future<void> onCallJoined(Map<String, dynamic> payload) async {}

  Future<void> accept() async {
    try {
      final Map<String, dynamic> response =
          await _sendWsAction('join_call', <String, dynamic>{
        'chat_id': chatId,
        'room_id': roomId,
        'message_id': callId,
      });
      final dynamic error = response['error'];
      if (error != null) {
        throw Exception(error.toString());
      }
      await _connect();
    } catch (e) {
      debugPrint('[CallSessionManager] accept failed: $e');
      await end();
      rethrow;
    }
  }

  Future<void> decline() async {
    try {
      await _sendWsAction('decline_call', <String, dynamic>{
        'chat_id': chatId,
        'room_id': roomId,
      });
    } catch (_) {}
    await end();
  }

  Future<void> end() async {
    if (_ended) return;
    _ended = true;
    final CallSessionData data = currentData;
    try {
      await _sendWsAction('end_call', <String, dynamic>{
        'chat_id': chatId,
        'room_id': roomId,
        'message_id': callId,
        'duration': data.durationSeconds,
        'was_missed': data.state != CallSessionState.connected,
      });
    } catch (e) {
      debugPrint('[CallSessionManager] end_call failed: $e');
    }
    _cleanup();
    await _session?.end();
    ref.read(callSessionProvider.notifier).setSession(null);
  }

  Future<void> remoteEnd({Map<String, dynamic>? payload}) async {
    if (_ended) return;
    _ended = true;
    _cleanup();
    await _session?.end();
    ref.read(callSessionProvider.notifier).setSession(null);
  }

  RTCVideoRenderer get localRenderer => _localRenderer;
  RTCVideoRenderer get remoteRenderer => _remoteRenderer;
  bool get isLocalVideoEnabled => false;
  MediaStream? get localStream => null;
  Map<int, MediaStream> get remoteStreams => const <int, MediaStream>{};

  Future<void> initRenderers() async {
    if (_renderersReady) return;
    _renderersReady = true;
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  void toggleMute({bool? muted}) => setMuted(muted ?? !isMuted);

  void setMuted(bool muted) {
    unawaited(_session?.setMuted(muted));
  }

  void toggleVideo({bool? enabled}) {}

  void setLocalVideoEnabled(bool enabled) {}

  Future<void> switchCamera() async {}

  Future<void> toggleSpeaker({bool? speaker}) async {
    await _session?.setSpeakerOn(speaker ?? !isSpeakerOn);
  }

  Future<void> setSpeakerOn(bool speaker) => toggleSpeaker(speaker: speaker);

  void _cleanup() {
    _soloTimer?.cancel();
    _soloTimer = null;
  }

  void dispose() {
    _cleanup();
    unawaited(_sessionSub?.cancel());
    _sessionSub = null;
    _session?.dispose();
    if (_renderersReady) {
      _localRenderer.dispose();
      _remoteRenderer.dispose();
    }
    _stateController.close();
  }

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
