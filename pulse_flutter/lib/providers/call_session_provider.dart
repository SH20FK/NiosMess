import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/services/calls/call_session.dart';

/// Provider for the current active call session.
///
/// null when no call is active.
final StateProvider<CallSessionManager?> callSessionProvider =
    StateProvider<CallSessionManager?>((_) => null);

/// Manages call session lifecycle — start, accept, end.
class CallSessionManager {
  CallSessionManager({
    required this.callId,
    required this.roomId,
    required this.isVideo,
    required this.direction,
    required this.displayName,
    required this.aesKey,
  });

  final int callId;
  final String roomId;
  final bool isVideo;
  final CallDirection direction;
  final String displayName;
  final SecretKey aesKey;

  CallSession? _session;

  CallSession? get session => _session;

  CallSession start() {
    _session = CallSession(
      callId: callId,
      roomId: roomId,
      isVideo: isVideo,
      direction: direction,
      displayName: displayName,
      aesKey: aesKey,
    );
    _session!.start();
    return _session!;
  }

  Future<void> end() async {
    await _session?.end();
    _session?.dispose();
    _session = null;
  }

  void dispose() {
    _session?.dispose();
    _session = null;
  }
}
