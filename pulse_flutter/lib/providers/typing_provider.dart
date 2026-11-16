import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';

class TypingState {
  const TypingState({this.typingUserIds = const <int>{}});
  final Set<int> typingUserIds;
}

/// How long a typing indicator survives without a fresh ping.
const Duration _typingTtl = Duration(milliseconds: 4500);

/// Minimum interval between outgoing `im_writing` pings for the same chat.
const Duration _sendThrottle = Duration(seconds: 3);

/// Single process-wide listener for typing pushes.
///
/// The per-chat family below used to own the subscription itself. Because the
/// family was not auto-disposable, every chat the inbox ever rendered kept a
/// `TypingNotifier` — and therefore a `pushStream` subscription plus its timer
/// map — alive for the rest of the session: a 200-chat inbox ran 200 handlers
/// for every websocket frame. One hub subscription now serves every chat, and
/// the map only holds chats that currently have an active typist.
class TypingHub extends Notifier<Map<int, Set<int>>> {
  final Map<(int chatId, int userId), Timer> _expiry =
      <(int, int), Timer>{};
  final Map<int, DateTime> _lastSent = <int, DateTime>{};
  StreamSubscription<Map<String, dynamic>>? _subscription;
  bool _disposed = false;
  int? _account;

  @override
  Map<int, Set<int>> build() {
    final int? account = ref.watch(
      authProvider.select((AuthState state) => state.session?.userId),
    );
    if (_account != account) {
      _account = account;
      _cancelTimers();
      _lastSent.clear();
    }
    _disposed = false;
    _subscription?.cancel();
    _subscription = ref
        .read(webSocketClientProvider)
        .pushStream
        .listen(_handlePush);
    ref.onDispose(() {
      _disposed = true;
      _subscription?.cancel();
      _subscription = null;
      _cancelTimers();
    });
    return const <int, Set<int>>{};
  }

  /// Typing user ids for [chatId]; empty when nobody is typing.
  Set<int> typingFor(int chatId) => state[chatId] ?? const <int>{};

  void _handlePush(Map<String, dynamic> event) {
    if (_disposed) return;
    final String? action = event['action'] as String?;
    if (action != 'typing' && action != 'who_writing') return;

    final dynamic payload = event['payload'];
    if (payload is! Map) return;

    final int? chatId = _asInt(payload['chat_id']);
    final int? senderId = _asInt(payload['user_id'] ?? payload['sender_id']);
    if (chatId == null || chatId <= 0 || senderId == null) return;

    final int myUserId = ref.read(authProvider).session?.userId ?? -1;
    if (senderId == myUserId) return;

    final (int, int) key = (chatId, senderId);
    if (action == 'typing' && payload['is_typing'] == false) {
      _expiry.remove(key)?.cancel();
      _removeUser(chatId, senderId);
      return;
    }

    _expiry.remove(key)?.cancel();
    _expiry[key] = Timer(_typingTtl, () {
      _expiry.remove(key);
      if (_disposed) return;
      _removeUser(chatId, senderId);
    });
    _addUser(chatId, senderId);
  }

  void _addUser(int chatId, int userId) {
    final Set<int> current = state[chatId] ?? const <int>{};
    if (current.contains(userId)) return;
    state = <int, Set<int>>{...state, chatId: <int>{...current, userId}};
  }

  void _removeUser(int chatId, int userId) {
    final Set<int>? current = state[chatId];
    if (current == null || !current.contains(userId)) return;
    final Set<int> next = <int>{...current}..remove(userId);
    if (next.isEmpty) {
      state = <int, Set<int>>{...state}..remove(chatId);
      return;
    }
    state = <int, Set<int>>{...state, chatId: next};
  }

  void _cancelTimers() {
    for (final Timer timer in _expiry.values) {
      timer.cancel();
    }
    _expiry.clear();
  }

  /// Throttled "I am writing" ping; the per-chat rate limit is shared by every
  /// screen that sends typing for the same chat.
  Future<void> sendTyping(int chatId) async {
    final int myUserId = ref.read(authProvider).session?.userId ?? -1;
    if (myUserId <= 0) return;
    if (ref.read(uiSettingsProvider).hideOnline) return;

    final DateTime now = DateTime.now();
    if (_lastSent.length > 64) {
      _lastSent.removeWhere(
        (int _, DateTime sentAt) =>
            now.difference(sentAt) > const Duration(minutes: 1),
      );
    }
    final DateTime? last = _lastSent[chatId];
    if (last != null && now.difference(last) < _sendThrottle) return;
    _lastSent[chatId] = now;

    final WebSocketClient client = ref.read(webSocketClientProvider);
    try {
      await client.request(
        'im_writing',
        payload: <String, dynamic>{'chat_id': chatId},
      );
    } catch (error) {
      debugPrint('[typing_provider] Send typing error: $error');
    }
  }
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}

/// Per-chat facade over [TypingHub], kept because screens read
/// `typingProvider(chatId)` and call `notifier.sendTyping()`.
///
/// Auto-disposable: a chat that scrolls out of the inbox releases its element.
/// Typing is ephemeral, so rebuilding it empty is the intended behaviour.
class TypingNotifier extends Notifier<TypingState> {
  TypingNotifier(this.chatId);

  final int chatId;

  @override
  TypingState build() {
    final Set<int>? typingUserIds = ref.watch(
      typingHubProvider.select(
        (Map<int, Set<int>> state) => state[chatId],
      ),
    );
    return TypingState(typingUserIds: typingUserIds ?? const <int>{});
  }

  Future<void> sendTyping() =>
      ref.read(typingHubProvider.notifier).sendTyping(chatId);
}

final typingHubProvider = NotifierProvider<TypingHub, Map<int, Set<int>>>(
  TypingHub.new,
);

final typingProvider =
    NotifierProvider.autoDispose.family<TypingNotifier, TypingState, int>(
      TypingNotifier.new,
    );
