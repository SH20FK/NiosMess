import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';

class WebSocketPushDispatcher {
  WebSocketPushDispatcher._();

  static final Map<int, void Function(ApiMessage)> _chatListeners = {};
  static StreamSubscription<Map<String, dynamic>>? _subscription;

  static void registerChat(int chatId, void Function(ApiMessage) onMessage) {
    _chatListeners[chatId] = onMessage;
  }

  static void unregisterChat(int chatId) {
    _chatListeners.remove(chatId);
  }

  static void _handlePushEvent(Map<String, dynamic> event) {
    final String? action = event['action'] as String?;
    if (action != 'new_message') return;
    final dynamic payload = event['payload'];
    if (payload is! Map<String, dynamic>) return;

    try {
      final ApiMessage message = ApiMessage.fromJson(payload);
      final void Function(ApiMessage)? listener = _chatListeners[message.chatId];
      if (listener != null) {
        listener(message);
      }
    } catch (e) {
      debugPrint('[WebSocketPushDispatcher] Parse error: $e');
    }
  }

  static void init(WebSocketClient client) {
    if (_subscription != null) return;
    _subscription = client.pushStream.listen(_handlePushEvent);
  }

  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _chatListeners.clear();
  }
}

final Provider<WebSocketPushDispatcher> webSocketDispatcherProvider =
    Provider<WebSocketPushDispatcher>((Ref ref) {
  final bool authenticated = ref.watch(
    authProvider.select((AuthState s) => s.isAuthenticated),
  );

  if (!authenticated) {
    WebSocketPushDispatcher.dispose();
    return WebSocketPushDispatcher._();
  }

  final WebSocketClient client = ref.read(webSocketClientProvider);
  WebSocketPushDispatcher.init(client);

  ref.onDispose(() {
    WebSocketPushDispatcher.dispose();
  });

  return WebSocketPushDispatcher._();
});
