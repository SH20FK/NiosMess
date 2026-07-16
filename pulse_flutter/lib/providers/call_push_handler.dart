import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/utils/shared_utilities.dart';
import 'package:pulse_flutter/providers/call_incoming_provider.dart';
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
    if (action != 'new_call') return;

    final Map<String, dynamic> payload = msg['payload'] is Map
        ? asStringMap(msg['payload'] as Map)
        : msg;

    final messageId = payload['message_id'] as int?;
    final chatId = payload['chat_id'] as int?;
    final roomId = payload['room_id'] as String?;
    final initiatorId = payload['caller_id'] as int?;
    final isVideo = payload['is_video'] as bool? ?? false;
    final initiatorName = payload['caller_nickname'] as String? ?? 'Someone';

    if (messageId == null || chatId == null || roomId == null || initiatorId == null) return;

    ref.read(incomingCallProvider.notifier).set(IncomingCallData(
      callId: messageId,
      roomId: roomId,
      chatId: chatId,
      isVideo: isVideo,
      initiatorId: initiatorId,
      initiatorName: initiatorName,
    );
  }
}

final Provider<void> callPushHandlerProvider =
    Provider<void>((Ref ref) => ref.watch(callPushHandlerNotifierProvider));

final NotifierProvider<CallPushHandler, void> callPushHandlerNotifierProvider =
    NotifierProvider<CallPushHandler, void>(CallPushHandler.new);
