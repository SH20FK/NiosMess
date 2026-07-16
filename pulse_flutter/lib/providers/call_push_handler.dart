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
    if (action != 'call_initiated') return;

    final Map<String, dynamic> data = msg['data'] is Map
        ? asStringMap(msg['data'] as Map)
        : msg;

    final callId = data['call_id'] as int?;
    final chatId = data['chat_id'] as int?;
    final initiatorId = data['initiator_id'] as int?;
    final isVideo = data['is_video'] as bool? ?? false;
    final initiatorName = data['initiator_name'] as String? ?? 'Someone';

    if (callId == null || chatId == null || initiatorId == null) return;

    ref.read(incomingCallProvider.notifier).state = IncomingCallData(
      callId: callId,
      roomId: 'call_$callId',
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
