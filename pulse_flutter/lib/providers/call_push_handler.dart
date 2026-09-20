import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/services/push_notification_service.dart';
import 'package:pulse_flutter/core/utils/shared_utilities.dart';
import 'package:pulse_flutter/providers/call_incoming_provider.dart';
import 'package:pulse_flutter/providers/call_session_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/repositories/call_repository.dart';
import 'package:pulse_flutter/services/calls/call_session.dart';

class CallPushHandler extends Notifier<void> {
  StreamSubscription<dynamic>? _sub;

  @override
  void build() {
    _sub = ref.read(webSocketClientProvider).pushStream.listen(_handlePush);
    ref.onDispose(() => _sub?.cancel());
  }

  void _handlePush(dynamic event) {
    if (event is! Map) return;
    final Map<String, dynamic> msg = asStringMap(event);
    final String action = msg['action'] as String? ?? '';

    if (action == 'end_call' || action == 'call_ended' || action == 'decline_call') {
      _handleEndCall(msg);
      return;
    }

    if (action == 'call_joined') {
      _handleCallJoined(msg);
      return;
    }

    if (action != 'new_call' &&
        action != 'incoming_call' &&
        action != 'incoming_call_push' &&
        action != 'start_call') {
      return;
    }

    final Map<String, dynamic> payload = msg['payload'] is Map
        ? asStringMap(msg['payload'] as Map)
        : msg;

    final int messageId = int.tryParse(payload['message_id']?.toString() ?? '') ??
        int.tryParse(payload['call_id']?.toString() ?? '') ??
        int.tryParse(payload['id']?.toString() ?? '') ??
        0;
    final int? chatId = int.tryParse(payload['chat_id']?.toString() ?? '');
    final String? roomId = payload['room_id']?.toString();
    final int initiatorId = int.tryParse(payload['caller_id']?.toString() ?? '') ??
        int.tryParse(payload['initiator_id']?.toString() ?? '') ??
        0;
    final bool isVideo = payload['is_video'] == true ||
        payload['is_video'] == 'true' ||
        payload['is_video'] == 1 ||
        payload['is_video'] == '1';
    final String initiatorName = payload['caller_nickname']?.toString() ??
        payload['caller_name']?.toString() ??
        payload['initiator_name']?.toString() ??
        'Собеседник';

    if (chatId == null || roomId == null || roomId.trim().isEmpty) return;

    // Deduplication (Rule 8): if already connected to this call, ignore duplicate push
    final CallSessionManager? currentSession = ref.read(callSessionProvider);
    if (currentSession != null && currentSession.roomId == roomId) {
      debugPrint('[CallPushHandler] Duplicate call push for current session ignored');
      return;
    }

    final IncomingCallData? currentIncoming = ref.read(incomingCallProvider);
    if (currentIncoming != null && currentIncoming.roomId == roomId) {
      debugPrint('[CallPushHandler] Duplicate incoming call push ignored');
      return;
    }

    // Busy check: if currently in another call, reject the new incoming call
    final CallSessionState? activeState = currentSession?.state;
    if (activeState != null &&
        activeState != CallSessionState.idle &&
        activeState != CallSessionState.ended) {
      debugPrint('[CallPushHandler] User busy: declining new incoming call $roomId');
      unawaited(ref.read(callRepositoryProvider).decline(
            chatId: chatId,
            roomId: roomId,
            messageId: messageId,
          ));
      return;
    }

    final IncomingCallData incomingData = IncomingCallData(
      callId: messageId,
      roomId: roomId,
      chatId: chatId,
      isVideo: isVideo,
      initiatorId: initiatorId,
      initiatorName: initiatorName,
    );

    ref.read(incomingCallProvider.notifier).set(incomingData);

    // Show actionable system notification
    PushNotificationService.showIncomingCallNotification(
      chatId: chatId,
      callId: messageId,
      roomId: roomId,
      callerName: initiatorName,
      isVideo: isVideo,
    );
  }

  void _handleCallJoined(Map<String, dynamic> msg) {
    final Map<String, dynamic> payload = msg['payload'] is Map
        ? asStringMap(msg['payload'] as Map)
        : msg;
    final String? roomId = payload['room_id']?.toString();

    final CallSessionManager? manager = ref.read(callSessionProvider);
    if (manager != null && roomId != null && manager.roomId == roomId) {
      debugPrint('[CallPushHandler] Received call_joined for room $roomId. Connecting media...');
      unawaited(manager.onCallJoined(payload));
    }
  }

  /// The other side ended/cancelled the call: dismiss the ringing banner,
  /// cancel call notification, and tear down active session if it matches.
  void _handleEndCall(Map<String, dynamic> msg) {
    final Map<String, dynamic> payload = msg['payload'] is Map
        ? asStringMap(msg['payload'] as Map)
        : const <String, dynamic>{};
    final String? roomId = payload['room_id'] as String?;

    final IncomingCallData? incoming = ref.read(incomingCallProvider);
    if (incoming != null && (roomId == null || incoming.roomId == roomId)) {
      ref.read(incomingCallProvider.notifier).set(null);
    }

    // Cancel system call notification
    PushNotificationService.cancelCallNotification();

    final CallSessionManager? manager = ref.read(callSessionProvider);
    if (manager != null && roomId != null && manager.roomId == roomId) {
      unawaited(manager.remoteEnd(payload: payload));
    }
  }
}

final Provider<void> callPushHandlerProvider =
    Provider<void>((Ref ref) => ref.watch(callPushHandlerNotifierProvider));

final NotifierProvider<CallPushHandler, void> callPushHandlerNotifierProvider =
    NotifierProvider<CallPushHandler, void>(CallPushHandler.new);
