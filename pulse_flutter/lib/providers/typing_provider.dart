import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';

class TypingState {
  const TypingState({this.typingUserIds = const <int>{}});
  final Set<int> typingUserIds;
}

class TypingNotifier extends Notifier<TypingState> {
  TypingNotifier(this._chatId);
  final int _chatId;
  Timer? _stopTimer;

  @override
  TypingState build() {
    final StreamSubscription<Map<String, dynamic>> subscription = ref
        .read(webSocketClientProvider)
        .pushStream
        .listen(_handlePush);

    ref.onDispose(() {
      subscription.cancel();
      _stopTimer?.cancel();
    });

    return const TypingState();
  }

  void _handlePush(Map<String, dynamic> event) {
    final String? action = event['action'] as String?;
    if (action != 'typing') return;

    final dynamic payload = event['payload'];
    if (payload is! Map<String, dynamic>) return;

    final int? eventChatId = payload['chat_id'] as int?;
    if (eventChatId != _chatId) return;

    final int? senderId = payload['sender_id'] as int?;
    if (senderId == null) return;

    final bool isTyping = payload['is_typing'] == true;

    final int myUserId = ref.read(authProvider).session?.userId ?? -1;
    if (senderId == myUserId) return;

    final Set<int> updated = {...state.typingUserIds};
    if (isTyping) {
      updated.add(senderId);
    } else {
      updated.remove(senderId);
    }
    state = TypingState(typingUserIds: updated);
  }

  Future<void> sendTyping() async {
    final int myUserId = ref.read(authProvider).session?.userId ?? -1;
    if (myUserId <= 0) return;

    try {
      await ref.read(webSocketClientProvider).request(
        'typing',
        payload: <String, dynamic>{
          'chat_id': _chatId,
          'is_typing': true,
        },
      );
    } catch (_) {}

    _stopTimer?.cancel();
    _stopTimer = Timer(const Duration(seconds: 3), _sendStopTyping);
  }

  Future<void> _sendStopTyping() async {
    final int myUserId = ref.read(authProvider).session?.userId ?? -1;
    if (myUserId <= 0) return;

    try {
      await ref.read(webSocketClientProvider).request(
        'typing',
        payload: <String, dynamic>{
          'chat_id': _chatId,
          'is_typing': false,
        },
      );
    } catch (_) {}
  }
}

final typingProvider =
    NotifierProvider.family<TypingNotifier, TypingState, int>(
  TypingNotifier.new,
);
