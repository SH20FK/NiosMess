import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/services/calls/call_session_types.dart';
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
    required this.aesKeyBytes,
  });

  final WidgetRef ref;
  final int chatId;
  final int callId;
  final String roomId;
  final bool isVideo;
  final CallDirection direction;
  final String displayName;
  final Uint8List aesKeyBytes;

  CallSession? _session;

  CallSession? get session => _session;

  CallSession start() {
    _session = CallSession(
      chatId: chatId,
      callId: callId,
      roomId: roomId,
      isVideo: isVideo,
      direction: direction,
      displayName: displayName,
      aesKeyBytes: aesKeyBytes,
    );
    _session!.start();
    return _session!;
  }

  Future<void> end() async {
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
    } catch (_) {}
    await _session?.end();
    _session?.dispose();
    _session = null;
  }

  void dispose() {
    _session?.dispose();
    _session = null;
  }
}
