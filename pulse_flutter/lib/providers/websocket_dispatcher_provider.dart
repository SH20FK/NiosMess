import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';

/// Minimal message stub carrying only routing ids.
ApiMessage _stub(int id, int chatId, {int senderId = 0, bool isDeleted = false}) =>
    ApiMessage(
      id: id,
      chatId: chatId,
      senderId: senderId,
      senderUsername: '',
      senderDisplayName: '',
      senderBadges: const [],
      content: '',
      msgType: 'text',
      replyToId: null,
      mediaUrl: null,
      mediaType: null,
      mediaName: null,
      mediaSize: null,
      mediaDuration: null,
      commentsCount: 0,
      reactions: const {},
      sentAt: DateTime.now(),
      editedAt: null,
      isDeleted: isDeleted,
    );

/// A realtime chat event routed to the open chat screen.
class ChatPushEvent {
  const ChatPushEvent.newMessage(ApiMessage this.message)
      : kind = ChatPushEventKind.newMessage,
        reactionEmoji = null,
        reactionAdded = false,
        userId = null;

  const ChatPushEvent.edited(ApiMessage this.message)
      : kind = ChatPushEventKind.edited,
        reactionEmoji = null,
        reactionAdded = false,
        userId = null;

  const ChatPushEvent.deleted(this.message)
      : kind = ChatPushEventKind.deleted,
        reactionEmoji = null,
        reactionAdded = false,
        userId = null;

  const ChatPushEvent.reaction(
    this.message, {
    required this.reactionEmoji,
    required this.reactionAdded,
  })  : kind = ChatPushEventKind.reaction,
        userId = null;

  const ChatPushEvent.read(this.message, {required this.userId})
      : kind = ChatPushEventKind.read,
        reactionEmoji = null,
        reactionAdded = false;

  final ChatPushEventKind kind;

  /// For [ChatPushEventKind.newMessage]/[edited] this is the full message;
  /// for the rest it is a stub carrying only id/chatId.
  final ApiMessage message;
  final String? reactionEmoji;
  final bool reactionAdded;
  final int? userId;
}

enum ChatPushEventKind { newMessage, edited, deleted, reaction, read }

class WebSocketPushDispatcher {
  WebSocketPushDispatcher._();

  static final Map<int, void Function(ChatPushEvent)> _chatListeners = {};
  static final Map<int, void Function(ChatPushEvent)> _chatListListeners = {};
  static StreamSubscription<Map<String, dynamic>>? _subscription;

  static void registerChat(int chatId, void Function(ChatPushEvent) onEvent) {
    _chatListeners[chatId] = onEvent;
  }

  static void unregisterChat(int chatId) {
    _chatListeners.remove(chatId);
  }

  /// Global listener (chat id -1) used by the chat list for previews and
  /// unread counters.
  static void registerGlobal(void Function(ChatPushEvent) onEvent) {
    _chatListListeners[-1] = onEvent;
  }

  static void unregisterGlobal() {
    _chatListListeners.remove(-1);
  }

  static void _emit(ApiMessage stub, ChatPushEvent event) {
    _chatListeners[stub.chatId]?.call(event);
    _chatListListeners[-1]?.call(event);
  }

  static void _handlePushEvent(Map<String, dynamic> event) {
    final String? action = event['action'] as String?;
    final dynamic payload = event['payload'];
    if (payload is! Map<String, dynamic>) return;

    try {
      switch (action) {
        case 'new_message':
          _emit(
            ApiMessage.fromJson(payload),
            ChatPushEvent.newMessage(ApiMessage.fromJson(payload)),
          );
          break;
        case 'edit_message':
        case 'message_edited':
          final ApiMessage msg = ApiMessage.fromJson(payload);
          _emit(msg, ChatPushEvent.edited(msg));
          break;
        case 'message_deleted':
          final int chatId = payload['chat_id'] as int? ?? 0;
          final int messageId = payload['message_id'] as int? ?? 0;
          if (chatId > 0 && messageId > 0) {
            final ApiMessage stub = _stub(messageId, chatId, isDeleted: true);
            _emit(stub, ChatPushEvent.deleted(stub));
          }
          break;
        case 'message_reaction':
          final int chatId = payload['chat_id'] as int? ?? 0;
          final int messageId = payload['message_id'] as int? ?? 0;
          final String? emoji = payload['emoji'] as String?;
          if (chatId > 0 && messageId > 0 && emoji != null && emoji.isNotEmpty) {
            final ApiMessage stub = _stub(messageId, chatId);
            _emit(
              stub,
              ChatPushEvent.reaction(
                stub,
                reactionEmoji: emoji,
                reactionAdded: payload['action'] != 'removed',
              ),
            );
          }
          break;
        case 'chat_read':
          final int chatId = payload['chat_id'] as int? ?? 0;
          final int userId = payload['user_id'] as int? ?? 0;
          if (chatId > 0 && userId > 0) {
            final ApiMessage stub = _stub(0, chatId, senderId: userId);
            _emit(stub, ChatPushEvent.read(stub, userId: userId));
          }
          break;
      }
    } catch (e) {
      debugPrint('[WebSocketPushDispatcher] Parse error: $e');
    }
  }

  static void init(WebSocketClient client) {
    _subscription?.cancel();
    _subscription = client.pushStream.listen(_handlePushEvent);
  }

  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _chatListeners.clear();
    _chatListListeners.clear();
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
