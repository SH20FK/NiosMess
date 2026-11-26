import 'package:pulse_flutter/services/calls/call_devices.dart';
import 'package:pulse_flutter/providers/connectivity_provider.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/core/utils/shared_utilities.dart';
import 'package:pulse_flutter/models/api/call_models.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/repositories/call_repository.dart';
import 'package:pulse_flutter/services/calls/call_session.dart';

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
  CallSessionManager? _ownedSession;
  @override
  CallSessionManager? build() {
    ref.listen(
      authProvider.select((s) => (s.session?.userId, s.session?.accessToken)),
      (previous, next) {
        if (previous != next && _ownedSession != null) setSession(null);
      },
    );
    ref.onDispose(() {
      final manager = _ownedSession;
      _ownedSession = null;
      manager?.dispose();
    });
    return null;
  }

  /// Stop native capture before account storage and the main socket disappear.
  /// Account exit must not wait for an unavailable remote signaling response.
  Future<void> shutdownForAccountExit() async {
    final manager = state;
    _ownedSession = null;
    state = null;
    await manager?.disposeAsync();
  }

  void setSession(CallSessionManager? manager) {
    final previous = state;
    _ownedSession = manager;
    state = manager;
    if (previous != null && !identical(previous, manager)) previous.dispose();
  }

  /// Trigger rebuild of widgets watching this provider
  void notify() {
    final CallSessionManager? cur = state;
    state = null;
    state = cur;
  }
}

/// Orchestrates a 1:1 NiosCalls WebRTC session and wires
/// it into Riverpod plus the server-side call signalling.
class CallSessionManager {
  CallSessionManager({
    required this.ref,
    required this.chatId,
    required this.callId,
    required this.roomId,
    required this.isVideo,
    this.isGroup = false,
    required this.direction,
    required this.displayName,
    this.peerName,
    this.peerAvatarUrl,
    this.peerUsername,
    this.isListener = false,
    this.gatewayInfo,
  }) : _gatewayInfo = gatewayInfo,
       _accountId = ref.read(authProvider).session?.userId,
       _accountToken = ref.read(authProvider).session?.accessToken;

  final Ref ref;
  final int? _accountId;
  final String? _accountToken;
  final int chatId;
  final int callId;
  final String roomId;
  final bool isVideo;
  final bool isGroup;
  final CallDirection direction;
  final String displayName;
  String? peerName;
  final String? peerAvatarUrl;
  final String? peerUsername;
  final bool isListener;
  final ApiCallGatewayInfo? gatewayInfo;
  ApiCallGatewayInfo? _gatewayInfo;

  ProviderSubscription<AsyncValue<NetworkType>>? _networkSub;
  WebRtcCallSession? _session;
  StreamSubscription<CallSessionData>? _sessionSub;
  final StreamController<CallSessionData> _stateController =
      StreamController<CallSessionData>.broadcast();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _localScreenRenderer = RTCVideoRenderer();
  final Map<int, RTCVideoRenderer> _remoteRenderers = {};
  final Map<int, RTCVideoRenderer> _remoteScreenRenderers = {};

  Timer? _soloTimer;
  bool _ended = false;

  /// Set once the peer is in the room, so the ringback loop and the
  /// "connected" cue fire exactly once per call.
  bool _answerHandled = false;
  bool _localRendererReady = false,
      _remoteRendererReady = false,
      _localScreenRendererReady = false;
  Future<void>? _rendererInit;
  Future<void>? _resourceDisposal;
  Future<WebRtcCallSession>? _sessionInit;
  Future<void>? _connection;
  bool _disposed = false;
  SoundService? _callSound;

  void _releaseCallSound() {
    _callSound?.resumeAfterCall();
    _callSound = null;
  }

  Stream<CallSessionData> get stateStream => _stateController.stream;

  CallSessionData get currentData {
    final WebRtcCallSession? session = _session;
    if (session == null) {
      final info = _gatewayInfo ?? gatewayInfo;
      return CallSessionData(
        state: CallSessionState.connecting,
        callId: callId,
        roomId: roomId,
        isVideo: isVideo,
        isGroup: info?.isGroup ?? isGroup,
        direction: direction,
        peerName: peerName,
        peerAvatarUrl: peerAvatarUrl,
        peerUsername: peerUsername,
        isPlus: info?.isPlus ?? false,
        maxVideoHeight: info?.maxVideoHeight ?? 480,
        maxScreenHeight: info?.maxScreenHeight ?? 480,
        maxFps: info?.maxFps ?? 30,
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
    if (!ref.mounted) {
      throw StateError('call_account_unavailable');
    }
    final auth = ref.read(authProvider);
    if (auth.session?.userId != _accountId ||
        auth.session?.accessToken != _accountToken) {
      throw StateError('call_account_changed');
    }
    final dynamic res = await ref
        .read(webSocketClientProvider)
        .request(action, payload: payload);
    return asStringMap(res);
  }

  Future<WebRtcCallSession> _ensureSession() =>
      _sessionInit ??= _createSession();

  Future<WebRtcCallSession> _createSession() async {
    final WebRtcCallSession? existing = _session;
    if (existing != null) return existing;

    await initRenderers();
    if (_disposed || _ended) throw StateError('Call has ended');

    final profile = ref.read(authProvider).profile;
    final ApiCallGatewayInfo resolvedGateway =
        _gatewayInfo ??
        gatewayInfo ??
        ApiCallGatewayInfo.defaultFor(
          isCallsTester: profile?.isCallsTester ?? false,
          isNiosPlus: profile?.isNiosPlus ?? false,
          isGroup: isGroup,
        );
    final WebRtcCallSession session = WebRtcCallSession(
      chatId: chatId,
      callId: callId,
      roomId: roomId,
      isVideo: isVideo,
      isGroup: resolvedGateway.isGroup || isGroup,
      direction: direction,
      displayName: displayName,
      peerName: peerName,
      peerAvatarUrl: peerAvatarUrl,
      peerUsername: peerUsername,
      isListener: isListener,
      gatewayInfo: resolvedGateway,
      devices: ref.read(callDevicesProvider),
      localRenderer: _localRenderer,
      remoteRenderer: _remoteRenderer,
      localScreenRenderer: _localScreenRenderer,
      onStateChanged: _onSessionData,
      onRemoteStreamsChanged: () => unawaited(_syncRemoteRenderers()),
      onRefreshGateway: () async {
        final refreshed = await ref
            .read(callRepositoryProvider)
            .refreshCallToken(chatId: chatId, roomId: roomId);
        if (refreshed == null) return null;
        final curProfile = ref.read(authProvider).profile;
        final updated = ApiCallGatewayInfo.fromJson(
          refreshed,
          isCallsTester: curProfile?.isCallsTester ?? false,
          isNiosPlus: curProfile?.isNiosPlus ?? false,
          isGroup: isGroup,
        );
        _gatewayInfo = updated;
        return updated;
      },
    );
    _session = session;
    _sessionSub = session.stateStream.listen(_onSessionData);
    return session;
  }

  Future<void> _syncRemoteRenderers() async {
    final session = _session;
    if (session == null || _disposed || _ended) return;

    Future<void> syncMap(
      Map<int, MediaStream> streams,
      Map<int, RTCVideoRenderer> renderers,
    ) async {
      final staleIds =
          renderers.keys.where((k) => !streams.containsKey(k)).toList();
      for (final id in staleIds) {
        final r = renderers.remove(id);
        if (r != null) {
          r.srcObject = null;
          try {
            await r.dispose();
          } catch (_) {}
        }
      }
      for (final entry in streams.entries) {
        var r = renderers[entry.key];
        if (r == null) {
          r = RTCVideoRenderer();
          await r.initialize();
          if (_disposed || _ended) {
            try {
              await r.dispose();
            } catch (_) {}
            return;
          }
          renderers[entry.key] = r;
        }
        r.srcObject = entry.value;
      }
    }

    await syncMap(session.remoteStreams, _remoteRenderers);
    await syncMap(session.remoteScreenStreams, _remoteScreenRenderers);
    if (!_disposed && ref.mounted) {
      ref.read(callSessionProvider.notifier).notify();
    }
  }

  void _onSessionData(CallSessionData data) {
    if (_disposed) return;
    if (!_stateController.isClosed) {
      _stateController.add(currentData);
    }
    ref.read(callSessionProvider.notifier).notify();

    // Ringback ends the moment the other side is actually in the room.
    if (!_answerHandled && (_session?.wasAnswered ?? false)) {
      _answerHandled = true;
      unawaited(ref.read(appSoundProvider).stopLoop());
    }

    if (data.remoteParticipants.isNotEmpty) {
      _soloTimer?.cancel();
      _soloTimer = null;
    } else if (data.state == CallSessionState.connected && !_answerHandled) {
      _soloTimer ??= Timer(const Duration(minutes: 3), () {
        debugPrint('[CallSessionManager] Solo timeout reached, ending call.');
        end();
      });
    }

    final int? maxDuration = gatewayInfo?.maxDurationSeconds;
    if (maxDuration != null && data.durationSeconds >= maxDuration) {
      debugPrint('[CallSessionManager] Max call duration reached.');
      end();
    }

    if (data.state == CallSessionState.ended && !_ended) {
      unawaited(end());
    }
  }

  Future<void> _connect() => _connection ??= _connectOnce();

  Future<void> _connectOnce() async {
    if (_disposed || _ended) return;
    final sound = ref.read(appSoundProvider);
    _callSound = sound;
    await sound.suspendForCall();
    if (_disposed || _ended) {
      _releaseCallSound();
      return;
    }
    final WebRtcCallSession session = await _ensureSession();
    _networkSub ??= ref.listen<AsyncValue<NetworkType>>(networkTypeProvider, (
      previous,
      next,
    ) {
      final before = previous?.asData?.value, after = next.asData?.value;
      if (before != null && after != null && before != after && !_ended) {
        session.requestRecovery();
      }
    });
    await session.start();
  }

  /// Starts the media session for an outgoing call. The server-side
  /// `start_call` has already been performed by the call starter.
  Future<void> start({
    required Map<String, dynamic> startResponse,
    String? peerDisplayName,
  }) async {
    // The WS `start_call` response is accepted as proof the call exists; the
    // peer display name it carries wins over a missing constructor value.
    if ((peerName == null || peerName!.isEmpty) &&
        (peerDisplayName?.isNotEmpty ?? false)) {
      peerName = peerDisplayName;
    }
    // WebRTC owns audio from capture until teardown; media tones must not
    // request a competing focus or reset the communication route.
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
      final Map<String, dynamic> response = await _sendWsAction(
        'join_call',
        <String, dynamic>{
          'chat_id': chatId,
          'room_id': roomId,
          'message_id': callId,
        },
      );
      final dynamic error = response['error'];
      if (error != null) {
        throw Exception(error.toString());
      }
      final Map<String, dynamic> payload = response['payload'] is Map
          ? response['payload'] as Map<String, dynamic>
          : response;
      if (payload.containsKey('call_access_token')) {
        final profile = ref.read(authProvider).profile;
        final bool isCallsTester = profile?.isCallsTester ?? false;
        final bool isNiosPlus = profile?.isNiosPlus ?? false;
        _gatewayInfo = ApiCallGatewayInfo.fromJson(
          payload,
          isCallsTester: isCallsTester,
          isNiosPlus: isNiosPlus,
          isGroup: isGroup,
        );
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
    _cleanup();
    await _session?.end();
    _releaseCallSound();
    if (identical(ref.read(callSessionProvider), this)) {
      ref.read(callSessionProvider.notifier).setSession(null);
    }
    try {
      await _sendWsAction('end_call', <String, dynamic>{
        'chat_id': chatId,
        'room_id': roomId,
        'message_id': callId,
        'duration': data.durationSeconds,
        // Answered = a peer really joined the room (see WebRtcCallSession.wasAnswered),
        // not merely "the transport connected".
        'was_missed': !(_session?.wasAnswered ?? false),
      });
    } catch (e) {
      debugPrint('[CallSessionManager] end_call failed: $e');
    }
  }

  Future<void> remoteEnd({Map<String, dynamic>? payload}) async {
    if (_ended) return;
    _ended = true;
    _cleanup();
    await _session?.end();
    _releaseCallSound();
    if (identical(ref.read(callSessionProvider), this)) {
      ref.read(callSessionProvider.notifier).setSession(null);
    }
  }

  RTCVideoRenderer get localRenderer => _localRenderer;
  RTCVideoRenderer get remoteRenderer => _remoteRenderer;
  RTCVideoRenderer get localScreenRenderer => _localScreenRenderer;
  Map<int, RTCVideoRenderer> get remoteRenderers =>
      Map<int, RTCVideoRenderer>.unmodifiable(_remoteRenderers);
  Map<int, RTCVideoRenderer> get remoteScreenRenderers =>
      Map<int, RTCVideoRenderer>.unmodifiable(_remoteScreenRenderers);
  bool get isLocalVideoEnabled =>
      _session?.currentData.isSelfVideoEnabled ?? false;
  bool get isScreenSharing => _session?.isScreenSharing ?? false;
  MediaStream? get localStream => _session?.localStream;
  Map<int, MediaStream> get remoteStreams =>
      _session?.remoteStreams ?? const <int, MediaStream>{};
  Map<int, MediaStream> get remoteScreenStreams =>
      _session?.remoteScreenStreams ?? const <int, MediaStream>{};

  Future<void> initRenderers() {
    if (_disposed || _ended) return Future<void>.value();
    return _rendererInit ??= _initRenderers();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    _localRendererReady = true;
    if (_disposed || _ended) return;
    await _remoteRenderer.initialize();
    _remoteRendererReady = true;
    if (_disposed || _ended) return;
    await _localScreenRenderer.initialize();
    _localScreenRendererReady = true;
  }

  Future<void> startScreenShare({String? sourceId}) async {
    await _session?.startScreenShare(sourceId: sourceId);
  }

  Future<void> stopScreenShare() async {
    await _session?.stopScreenShare();
  }

  Future<void> setForceRelay(bool enabled) async {
    await _session?.setForceRelay(enabled);
  }

  void toggleMute({bool? muted}) => setMuted(muted ?? !isMuted);

  void setMuted(bool muted) {
    unawaited(_session?.setMuted(muted));
  }

  void toggleVideo({bool? enabled}) {
    final bool next = enabled ?? !isLocalVideoEnabled;
    setLocalVideoEnabled(next);
  }

  void setLocalVideoEnabled(bool enabled) {
    unawaited(_session?.setLocalVideoEnabled(enabled));
  }

  Future<void> switchCamera() async {
    await _session?.switchCamera();
  }

  Future<void> toggleSpeaker({bool? speaker}) async {
    await _session?.setSpeakerOn(speaker ?? !isSpeakerOn);
  }

  Future<void> setSpeakerOn(bool speaker) => toggleSpeaker(speaker: speaker);

  Future<void> setDevices(CallDevices devices) async {
    await _session?.setDevices(devices);
    ref.read(callDevicesProvider.notifier).select(devices);
  }

  void _cleanup() {
    _networkSub?.close();
    _networkSub = null;
    _soloTimer?.cancel();
    _soloTimer = null;
    unawaited(_callSound?.stopLoop());
  }

  Future<void> disposeAsync() {
    dispose();
    return _resourceDisposal!;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _ended = true;
    _cleanup();
    unawaited(_sessionSub?.cancel());
    _sessionSub = null;
    _resourceDisposal = _disposeResources();
    unawaited(_resourceDisposal);
  }

  Future<void> _disposeResources() async {
    await _session?.dispose();
    _releaseCallSound();
    if (_rendererInit != null) {
      try {
        await _rendererInit;
      } catch (_) {}
    }
    if (_localRendererReady) await _localRenderer.dispose();
    if (_remoteRendererReady) await _remoteRenderer.dispose();
    if (_localScreenRendererReady) await _localScreenRenderer.dispose();
    for (final r in _remoteRenderers.values) {
      r.srcObject = null;
      try {
        await r.dispose();
      } catch (_) {}
    }
    _remoteRenderers.clear();
    for (final r in _remoteScreenRenderers.values) {
      r.srcObject = null;
      try {
        await r.dispose();
      } catch (_) {}
    }
    _remoteScreenRenderers.clear();
    await _stateController.close();
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
