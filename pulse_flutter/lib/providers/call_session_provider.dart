import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/models/api/call_models.dart';
import 'package:pulse_flutter/providers/call_video_provider.dart';
import 'package:pulse_flutter/services/calls/call_session.dart';
import 'package:pulse_flutter/repositories/call_repository.dart';

/// Provider for the current active call session.
///
/// null when no call is active.
final callSessionProvider = NotifierProvider<CallSessionNotifier, CallSessionManager?>(
  CallSessionNotifier.new,
);

class CallSessionNotifier extends Notifier<CallSessionManager?> {
  @override
  CallSessionManager? build() => null;

  void setSession(CallSessionManager? manager) => state = manager;
}

/// Manages call session lifecycle — start, accept, end.
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
    required this.aesKeyBytes,
    this.isListener = false,
    this.gatewayInfo,
  });

  final WidgetRef ref;
  final int chatId;
  final int callId;
  final String roomId;
  final bool isVideo;
  final CallDirection direction;
  final String displayName;
  final String? peerName;
  final Uint8List aesKeyBytes;
  final bool isListener;
  final ApiCallGatewayInfo? gatewayInfo;

  CallSession? _session;
  StreamSubscription<CallSessionData>? _stateSub;
  Timer? _soloTimer;

  CallSession? get session => _session;

  void _handleSoloCheck(CallSessionData data) {
    if (data.state == CallSessionState.ended || data.state == CallSessionState.idle) {
      _soloTimer?.cancel();
      _soloTimer = null;
      return;
    }

    if (data.remoteParticipants.isEmpty) {
      _soloTimer ??= Timer(const Duration(minutes: 3), () {
        debugPrint('[call_session_provider] Solo waiting timeout reached (3 min), ending call');
        end();
      });
    } else {
      _soloTimer?.cancel();
      _soloTimer = null;
    }
  }

  CallSession start({bool preferQuic = false}) {
    _session = CallSession(
      chatId: chatId,
      callId: callId,
      roomId: roomId,
      isVideo: isVideo,
      direction: direction,
      displayName: displayName,
      peerName: peerName,
      aesKeyBytes: aesKeyBytes,
      isListener: isListener,
      onCameraReady: isVideo
          ? (controller) {
              ref.read(localCameraControllerProvider.notifier).set(controller);
            }
          : null,
    );
    _stateSub?.cancel();
    _stateSub = _session!.stateStream.listen((data) {
      if (data.state == CallSessionState.ended) {
        _soloTimer?.cancel();
        _soloTimer = null;
        ref.read(callSessionProvider.notifier).setSession(null);
        return;
      }

      _handleSoloCheck(data);

      if (gatewayInfo?.maxDurationSeconds != null &&
          data.durationSeconds >= gatewayInfo!.maxDurationSeconds!) {
        debugPrint(
            '[call_session_provider] Max duration quota reached (${gatewayInfo!.maxDurationSeconds}s), ending call');
        end();
      }
    });

    _handleSoloCheck(_session!.currentData);
    _session!.start(preferQuic: preferQuic);
    return _session!;
  }

  Future<void> end() async {
    _soloTimer?.cancel();
    _soloTimer = null;
    final duration = _session?.currentData.durationSeconds ?? 0;
    final wasMissed = _session?.currentData.durationSeconds == 0;
    try {
      await ref.read(callRepositoryProvider).end(
        chatId: chatId,
        roomId: roomId,
        messageId: callId,
        duration: duration,
        wasMissed: wasMissed,
      );
    } catch (e) {
      debugPrint('[call_session_provider] Send call log error: $e');
    }
    _stateSub?.cancel();
    _stateSub = null;
    await _session?.end();
    _session?.dispose();
    _session = null;
    ref.read(callSessionProvider.notifier).setSession(null);
  }

  void dispose() {
    _soloTimer?.cancel();
    _soloTimer = null;
    _stateSub?.cancel();
    _stateSub = null;
    _session?.dispose();
    _session = null;
  }

  /// The remote side ended the call (end_call push): tear down locally
  /// without echoing end signaling back to the server.
  Future<void> remoteEnd() async {
    _soloTimer?.cancel();
    _soloTimer = null;
    _stateSub?.cancel();
    _stateSub = null;
    await _session?.end();
    _session?.dispose();
    _session = null;
    ref.read(callSessionProvider.notifier).setSession(null);
  }
}
