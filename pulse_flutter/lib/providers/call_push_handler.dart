import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/utils/shared_utilities.dart';
import 'package:pulse_flutter/providers/call_incoming_provider.dart';
import 'package:pulse_flutter/providers/call_session_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';

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

    ref.read(incomingCallProvider.notifier).set(IncomingCallData(
      callId: messageId,
      roomId: roomId,
      chatId: chatId,
      isVideo: isVideo,
      initiatorId: initiatorId,
      initiatorName: initiatorName,
    ));
  }

  /// The other side ended/cancelled the call: dismiss the ringing banner and
  /// tear down the active session if it matches.
  void _handleEndCall(Map<String, dynamic> msg) {
    final Map<String, dynamic> payload = msg['payload'] is Map
        ? asStringMap(msg['payload'] as Map)
        : const <String, dynamic>{};
    final String? roomId = payload['room_id'] as String?;

    final IncomingCallData? incoming = ref.read(incomingCallProvider);
    if (incoming != null && (roomId == null || incoming.roomId == roomId)) {
      ref.read(incomingCallProvider.notifier).set(null);
    }

    final CallSessionManager? manager = ref.read(callSessionProvider);
    if (manager != null && roomId != null && manager.roomId == roomId) {
      unawaited(manager.remoteEnd());
    }
  }
}

final Provider<void> callPushHandlerProvider =
    Provider<void>((Ref ref) => ref.watch(callPushHandlerNotifierProvider));

final NotifierProvider<CallPushHandler, void> callPushHandlerNotifierProvider =
    NotifierProvider<CallPushHandler, void>(CallPushHandler.new);
