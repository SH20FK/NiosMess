import 'dart:async';

import 'package:flutter/foundation.dart';
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
  final Map<int, Timer> _userExpiryTimers = {};
  bool _disposed = false;

  @override
  TypingState build() {
    _disposed = false;
    final StreamSubscription<Map<String, dynamic>> subscription = ref
        .read(webSocketClientProvider)
        .pushStream
        .listen(_handlePush);

    ref.onDispose(() {
      _disposed = true;
      subscription.cancel();
      for (final Timer t in _userExpiryTimers.values) {
        t.cancel();
      }
      _userExpiryTimers.clear();
    });

    return const TypingState();
  }

  void _handlePush(Map<String, dynamic> event) {
    if (_disposed) return;
    final String? action = event['action'] as String?;
    if (action != 'typing' && action != 'who_writing') return;

    final dynamic payload = event['payload'];
    if (payload is! Map<String, dynamic>) return;

    final int? eventChatId = payload['chat_id'] is int
        ? payload['chat_id'] as int
        : int.tryParse(payload['chat_id']?.toString() ?? '');
    if (eventChatId != _chatId) return;

    final dynamic rawUserId = payload['user_id'] ?? payload['sender_id'];
    final int? senderId = rawUserId is int
        ? rawUserId
        : int.tryParse(rawUserId?.toString() ?? '');
    if (senderId == null) return;

    final int myUserId = ref.read(authProvider).session?.userId ?? -1;
    if (senderId == myUserId) return;

    final bool isStop = action == 'typing' && payload['is_typing'] == false;

    final Set<int> updated = {...state.typingUserIds};
    if (isStop) {
      updated.remove(senderId);
      _userExpiryTimers[senderId]?.cancel();
      _userExpiryTimers.remove(senderId);
    } else {
      updated.add(senderId);
      // Auto-clear typing indicator after 4.5 seconds of silence
      _userExpiryTimers[senderId]?.cancel();
      _userExpiryTimers[senderId] = Timer(const Duration(milliseconds: 4500), () {
        if (_disposed) return;
        final Set<int> next = {...state.typingUserIds}..remove(senderId);
        state = TypingState(typingUserIds: next);
        _userExpiryTimers.remove(senderId);
      });
    }
    state = TypingState(typingUserIds: updated);
  }

  Future<void> sendTyping() async {
    final int myUserId = ref.read(authProvider).session?.userId ?? -1;
    if (myUserId <= 0) return;

    try {
      await ref.read(webSocketClientProvider).request(
        'im_writing',
        payload: <String, dynamic>{
          'chat_id': _chatId,
        },
      );
    } catch (e) {
      debugPrint('[typing_provider] Send typing error: $e');
    }
  }
}

final typingProvider =
    NotifierProvider.family<TypingNotifier, TypingState, int>(
  TypingNotifier.new,
);
