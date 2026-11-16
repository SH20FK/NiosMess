import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/chat_muted_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/core/services/desktop_window_service.dart';

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
  const ChatPushEvent.newMessage(this.message)
      : kind = ChatPushEventKind.newMessage,
        reactionEmoji = null,
        reactionAdded = false,
        userId = null,
        isOnline = false,
        isBlocked = false;

  const ChatPushEvent.edited(this.message)
      : kind = ChatPushEventKind.edited,
        reactionEmoji = null,
        reactionAdded = false,
        userId = null,
        isOnline = false,
        isBlocked = false;

  const ChatPushEvent.deleted(this.message)
      : kind = ChatPushEventKind.deleted,
        reactionEmoji = null,
        reactionAdded = false,
        userId = null,
        isOnline = false,
        isBlocked = false;

  const ChatPushEvent.reaction(
    this.message, {
    required this.reactionEmoji,
    required this.reactionAdded,
  })  : kind = ChatPushEventKind.reaction,
        userId = null,
        isOnline = false,
        isBlocked = false;

  const ChatPushEvent.read(this.message, {required this.userId})
      : kind = ChatPushEventKind.read,
        reactionEmoji = null,
        reactionAdded = false,
        isOnline = false,
        isBlocked = false;

  const ChatPushEvent.userStatus(this.message, {required this.userId, required this.isOnline})
      : kind = ChatPushEventKind.userStatus,
        reactionEmoji = null,
        reactionAdded = false,
        isBlocked = false;

  const ChatPushEvent.userBlocked(this.message, {required this.userId, required this.isBlocked})
      : kind = ChatPushEventKind.userBlocked,
        reactionEmoji = null,
        reactionAdded = false,
        isOnline = false;

  final ChatPushEventKind kind;

  /// For [ChatPushEventKind.newMessage]/[edited] this is the full message;
  /// for the rest it is a stub carrying only id/chatId.
  final ApiMessage message;
  final String? reactionEmoji;
  final bool reactionAdded;
  final int? userId;
  final bool isOnline;
  final bool isBlocked;
}

enum ChatPushEventKind { newMessage, edited, deleted, reaction, read, userStatus, userBlocked }

class WebSocketPushDispatcher {
  WebSocketPushDispatcher._();

  static final Map<int, void Function(ChatPushEvent)> _chatListeners = {};
  static final Map<int, void Function(ChatPushEvent)> _chatListListeners = {};
  static StreamSubscription<Map<String, dynamic>>? _subscription;

  /// Chat-level pushes (`chat_updated` / `chat_deleted`) do not carry a message,
  /// and [ChatPushEventKind] is consumed exhaustively by the inbox for
  /// message-level updates, so they are routed through this separate hook.
  /// [payload] is the raw server payload; it may or may not include a full
  /// chat summary or a mute flag.
  static void Function(String action, int chatId, Map<String, dynamic> payload)?
  onChatListPush;

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

  static void emit(ApiMessage stub, ChatPushEvent event) {
    _chatListeners[stub.chatId]?.call(event);
    _chatListListeners[-1]?.call(event);
  }

  /// Chat id of a chat-level payload: `chat_id` / `id`, or the nested full
  /// summary under `chat`.
  static int _chatIdOf(Map<String, dynamic> payload) {
    final int? direct = int.tryParse(
      payload['chat_id']?.toString() ?? payload['id']?.toString() ?? '',
    );
    if (direct != null && direct > 0) return direct;
    final dynamic chat = payload['chat'];
    if (chat is Map) {
      return int.tryParse(chat['id']?.toString() ?? '') ?? 0;
    }
    return 0;
  }

  static void _handlePushEvent(Map<String, dynamic> event) {
    final String? action = event['action'] as String?;
    final dynamic rawPayload = event['payload'];
    if (rawPayload is! Map) return;
    final Map<String, dynamic> payload =
        rawPayload.map((k, v) => MapEntry(k.toString(), v));

    try {
      switch (action) {
        case 'new_message':
          final ApiMessage msg = ApiMessage.fromJson(payload);
          emit(msg, ChatPushEvent.newMessage(msg));
          if (DesktopWindowService.isWindows) {
            unawaited(DesktopWindowService.instance.flashTaskbar());
          }
          break;
        case 'edit_message':
        case 'message_edited':
          final ApiMessage msg = ApiMessage.fromJson(payload);
          emit(msg, ChatPushEvent.edited(msg));
          break;
        case 'message_deleted':
          final int chatId = int.tryParse(payload['chat_id']?.toString() ?? '') ?? 0;
          final int messageId = int.tryParse(payload['message_id']?.toString() ?? '') ?? 0;
          if (chatId > 0 && messageId > 0) {
            final ApiMessage stub = _stub(messageId, chatId, isDeleted: true);
            emit(stub, ChatPushEvent.deleted(stub));
          }
          break;
        case 'message_reaction':
          final int chatId = int.tryParse(payload['chat_id']?.toString() ?? '') ?? 0;
          final int messageId = int.tryParse(payload['message_id']?.toString() ?? '') ?? 0;
          final String? rawEmoji = payload['emoji']?.toString();
          if (chatId > 0 && messageId > 0 && rawEmoji != null && rawEmoji.isNotEmpty) {
            final String emoji = normalizeReactionEmoji(rawEmoji);
            final ApiMessage stub = _stub(messageId, chatId);
            emit(
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
          final int chatId = int.tryParse(payload['chat_id']?.toString() ?? '') ?? 0;
          final int userId = int.tryParse(payload['user_id']?.toString() ?? '') ?? 0;
          if (chatId > 0 && userId > 0) {
            final ApiMessage stub = _stub(0, chatId, senderId: userId);
            emit(stub, ChatPushEvent.read(stub, userId: userId));
          }
          break;
        case 'user_status':
          final int chatId = int.tryParse(payload['chat_id']?.toString() ?? '') ?? 0;
          final int userId = int.tryParse(payload['user_id']?.toString() ?? '') ?? 0;
          final bool isOnline = payload['is_online'] == true ||
              payload['is_online'] == 1 ||
              payload['is_online']?.toString().toLowerCase() == 'true';
          if (userId > 0) {
            final ApiMessage stub = _stub(0, chatId, senderId: userId);
            emit(stub, ChatPushEvent.userStatus(stub, userId: userId, isOnline: isOnline));
          }
          break;
        case 'user_blocked':
          final int byUserId = int.tryParse(payload['by_user_id']?.toString() ?? '') ?? 0;
          final bool isBlocked = payload['is_blocked'] == true ||
              payload['is_blocked'] == 1 ||
              payload['is_blocked']?.toString().toLowerCase() == 'true';
          if (byUserId > 0) {
            final ApiMessage stub = _stub(0, 0, senderId: byUserId);
            emit(stub, ChatPushEvent.userBlocked(stub, userId: byUserId, isBlocked: isBlocked));
          }
          break;
        // Chat-level pushes carry no message (rename, auto-delete TTL,
        // membership change, deletion). They must not go through `emit`, whose
        // payload is an ApiMessage consumed by the open-chat screen.
        case 'chat_updated':
        case 'chat_deleted':
        case 'chat_removed':
          final int chatId = _chatIdOf(payload);
          if (chatId > 0) {
            onChatListPush?.call(action!, chatId, payload);
          }
          break;
        case 'end_call':
        case 'call_ended':
          final dynamic callMsg = payload['message'];
          if (callMsg is Map) {
            final Map<String, dynamic> callMsgMap =
                callMsg.map((k, v) => MapEntry(k.toString(), v));
            final ApiMessage msg = ApiMessage.fromJson(callMsgMap);
            emit(msg, ChatPushEvent.edited(msg));
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
    onChatListPush = null;
    _chatListeners.clear();
    _chatListListeners.clear();
  }
}

/// Coalesces chat-level pushes into one inbox sync.
///
/// The server's `chat_updated` carries identifiers (TTL, rename, membership),
/// not a full summary, so the inbox cannot be patched from it; a refresh is
/// needed. Debouncing means a burst — bulk member changes, several renames —
/// costs one `list_chats` instead of one per event. A payload that does carry a
/// full summary is applied pointwise through `ChatsNotifier.upsertChat`.
class _ChatListPushSync {
  _ChatListPushSync(this._ref);

  static const Duration _window = Duration(milliseconds: 500);

  final Ref _ref;
  Timer? _timer;
  bool _refresh = false;
  bool _disposed = false;

  void handle(String action, int chatId, Map<String, dynamic> payload) {
    if (_disposed || chatId <= 0) return;

    // A mute flag, when the server starts sending one, is applied immediately:
    // notifications must stop without waiting for the refresh window.
    final dynamic mute = payload['is_muted'] ?? payload['muted'];
    if (mute is bool) {
      unawaited(
        _ref.read(chatMuteHubProvider.notifier).applyServerMute(chatId, mute),
      );
    }

    final Map<String, dynamic>? summary = _fullSummary(payload, chatId);
    if (summary != null && action != 'chat_deleted') {
      _ref.read(chatsProvider.notifier).upsertChat(
        ApiChatSummary.fromJson(summary),
      );
    } else {
      // `chat_deleted` / `chat_removed` (and any sparse update) needs the
      // server list: it is what drops a chat the user left or that was removed.
      _refresh = true;
    }
    if (_refresh) _timer ??= Timer(_window, _flush);
  }

  void _flush() {
    _timer = null;
    if (_disposed || !_ref.mounted) return;
    final bool refresh = _refresh;
    _refresh = false;
    if (!refresh) return;
    // `refresh()` keeps the current list on a failed request (unlike
    // invalidate, which also drops the pending cache snapshot) and replaces it
    // with the server list, which is what removes a deleted chat.
    unawaited(_ref.read(chatsProvider.notifier).refresh());
  }

  /// The payload is a full chat summary when it carries the summary fields; a
  /// sparse `{chat_id, auto_delete_seconds}` update must not overwrite a tile.
  Map<String, dynamic>? _fullSummary(Map<String, dynamic> payload, int chatId) {
    final dynamic nested = payload['chat'];
    final dynamic candidate = nested is Map ? nested : payload;
    if (candidate is! Map) return null;
    final Map<String, dynamic> summary = <String, dynamic>{
      for (final MapEntry<dynamic, dynamic> entry in candidate.entries)
        entry.key.toString(): entry.value,
    };
    if (summary['chat_type'] == null || summary['name'] == null) return null;
    summary['id'] = chatId;
    return summary;
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
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

  final WebSocketClient client = ref.watch(webSocketClientProvider);
  WebSocketPushDispatcher.init(client);

  final _ChatListPushSync chatListSync = _ChatListPushSync(ref);
  WebSocketPushDispatcher.onChatListPush = chatListSync.handle;

  ref.onDispose(() {
    chatListSync.dispose();
    WebSocketPushDispatcher.dispose();
  });

  return WebSocketPushDispatcher._();
});
