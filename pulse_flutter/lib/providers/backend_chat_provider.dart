import 'package:pulse_flutter/providers/secret_chat_provider.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/core/storage/cache_service.dart';
import 'package:pulse_flutter/core/storage/chat_history_retention.dart';
import 'package:pulse_flutter/core/storage/sorted_history.dart';
import 'package:pulse_flutter/core/storage/chat_media_cache.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/core/storage/encrypted_message_cache.dart';
import 'package:pulse_flutter/core/storage/notification_storage.dart';
import 'package:pulse_flutter/models/api/chat_member_model.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/badge_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/models/api/sticker_model.dart';
import 'package:pulse_flutter/core/services/push_notification_service.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/chat_muted_provider.dart';
import 'package:pulse_flutter/providers/in_app_notification_provider.dart';
import 'package:pulse_flutter/providers/niosgram_provider.dart';
import 'package:pulse_flutter/providers/sticker_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/providers/websocket_dispatcher_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/services/double_ratchet_service.dart';
import 'package:pulse_flutter/services/e2ee_service.dart';

ApiMessage _stubMessage(
  int id,
  int chatId, {
  int senderId = 0,
  bool isDeleted = false,
}) => ApiMessage(
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

/// Parsed E2EE handshake (HELO) message: a plain text message whose content
/// is JSON `{"dh": ..., "ed": ..., "sig": ...}`.
class _E2eeHelo {
  const _E2eeHelo({
    required this.dhPubB64,
    required this.edPubB64,
    required this.signature,
  });

  final String dhPubB64;
  final String edPubB64;
  final List<int> signature;
}

_E2eeHelo? _parseHeloMessage(ApiMessage message) {
  if (message.isE2ee || message.isDeleted || message.msgType != 'text') {
    return null;
  }
  final String content = message.content;
  if (!content.startsWith('{"dh"')) return null;
  try {
    final Map<String, dynamic> map =
        jsonDecode(content) as Map<String, dynamic>;
    final String? dh = map['dh'] as String?;
    final String? ed = map['ed'] as String?;
    final String? sig = map['sig'] as String?;
    if (dh == null || ed == null || dh.isEmpty || ed.isEmpty) return null;
    return _E2eeHelo(
      dhPubB64: dh,
      edPubB64: ed,
      signature: sig != null ? base64Decode(sig) : const <int>[],
    );
  } catch (_) {
    return null;
  }
}

class ChatsNotifier extends AsyncNotifier<List<ApiChatSummary>> {
  Timer? _persistTimer;
  List<ApiChatSummary>? _pendingChats;

  void _persistChats(List<ApiChatSummary> chats) {
    _pendingChats = chats;
    _persistTimer ??= Timer(const Duration(seconds: 2), () {
      _persistTimer = null;
      final List<ApiChatSummary>? snapshot = _pendingChats;
      _pendingChats = null;
      if (snapshot == null) return;
      try {
        unawaited(ref.read(cacheServiceProvider).saveChats(snapshot));
      } catch (_) {}
    });
  }

  @override
  Future<List<ApiChatSummary>> build() async {
    final bool authenticated = ref.watch(
      authProvider.select((AuthState state) => state.isAuthenticated),
    );

    if (!authenticated) {
      return const <ApiChatSummary>[];
    }

    ref.read(webSocketDispatcherProvider);
    WebSocketPushDispatcher.registerGlobal(_handlePushEvent);
    final connected = ref.read(webSocketClientProvider).onConnected.listen((_) {
      if (ref.mounted) {
        unawaited(refresh());
      }
    });
    ref.onDispose(() {
      unawaited(connected.cancel());
      WebSocketPushDispatcher.unregisterGlobal();
      _persistTimer?.cancel();
      _persistTimer = null;
      _pendingChats = null;
    });

    final secret = await ref.read(secretChatCoordinatorProvider.future);
    if (secret != null) {
      final subscription = secret.engine.changes.listen((_) {
        if (!ref.mounted) return;
        state = AsyncData(
          secret.mergeChats(state.value ?? const <ApiChatSummary>[]),
        );
      });
      ref.onDispose(() => unawaited(subscription.cancel()));
      final local = secret.mergeChats(const <ApiChatSummary>[]);
      if (local.isNotEmpty) state = AsyncData(local);
    }

    // Load cache immediately
    try {
      final List<ApiChatSummary> chats = ref
          .read(cacheServiceProvider)
          .getCachedChats();
      if (chats.isNotEmpty) {
        if (secret != null) await secret.importChats(chats);
        state = AsyncData<List<ApiChatSummary>>(
          secret?.mergeChats(chats) ?? chats,
        );
      }
    } catch (e) {
      debugPrint('[backend_chat_provider.dart] Cache load error: $e');
    }

    return _fetch();
  }

  void _handlePushEvent(ChatPushEvent event) {
    switch (event.kind) {
      case ChatPushEventKind.newMessage:
        _handleNewMessagePush(event.message);
      case ChatPushEventKind.edited:
        _handleEditedPush(event.message);
      case ChatPushEventKind.deleted:
        _handleDeletedPush(event.message);
      case ChatPushEventKind.reaction:
        _handleReactionPush(
          event.message,
          event.reactionEmoji ?? '',
          added: event.reactionAdded,
        );
      case ChatPushEventKind.read:
        _handleReadPush(event.message.chatId, event.userId ?? 0);
      case ChatPushEventKind.userStatus:
        _handleUserStatusPush(
          event.message.chatId,
          event.userId ?? 0,
          event.isOnline,
        );
      case ChatPushEventKind.userBlocked:
        _handleUserBlockedPush(event.userId ?? 0, event.isBlocked);
    }
  }

  void _handleUserBlockedPush(int userId, bool isBlocked) {
    if (userId <= 0) return;
    final List<ApiChatSummary>? currentChats = state.value;
    if (currentChats == null) return;

    final int index = currentChats.indexWhere((ApiChatSummary c) {
      return c.chatType == 'direct' &&
          (c.partnerUserId == userId || c.id == userId);
    });
    if (index == -1) return;

    final ApiChatSummary chat = currentChats[index];
    if (chat.isBlockedByUser == isBlocked) return;

    final List<ApiChatSummary> updated = List<ApiChatSummary>.from(
      currentChats,
    );
    updated[index] = chat.copyWith(
      isBlockedByUser: isBlocked,
      isBlocked: isBlocked || chat.isBlockedByMe,
    );
    state = AsyncData<List<ApiChatSummary>>(updated);
    _persistChats(updated);
  }

  void _handleUserStatusPush(int chatId, int userId, bool isOnline) {
    final List<ApiChatSummary>? currentChats = state.value;
    if (currentChats == null) return;

    final int index = currentChats.indexWhere((ApiChatSummary c) {
      if (chatId > 0 && c.id == chatId) return true;
      if (c.chatType == 'direct' &&
          (c.partnerUserId == userId || c.id == userId)) {
        return true;
      }
      return false;
    });
    if (index == -1) return;

    final ApiChatSummary chat = currentChats[index];
    if (chat.isOnline == isOnline) return;

    final List<ApiChatSummary> updated = List<ApiChatSummary>.from(
      currentChats,
    );
    updated[index] = chat.copyWith(isOnline: isOnline);
    state = AsyncData<List<ApiChatSummary>>(updated);
  }

  void _handleReadPush(int chatId, int userId) {
    final List<ApiChatSummary>? currentChats = state.value;
    if (currentChats == null) return;

    final int index = currentChats.indexWhere(
      (ApiChatSummary c) => c.id == chatId,
    );
    if (index == -1) return;
    final ApiChatSummary chat = currentChats[index];

    final int myUserId = ref.read(authProvider).session?.userId ?? -1;
    final List<ApiChatSummary> updated = List<ApiChatSummary>.from(
      currentChats,
    );

    if (userId == myUserId) {
      // Current user read the chat
      if (chat.unreadCount != 0) {
        updated[index] = chat.copyWith(unreadCount: 0);
        state = AsyncData<List<ApiChatSummary>>(updated);
        _persistChats(updated);
      }
    } else {
      // Peer read the chat: mark our last message as read
      if (chat.lastMessage != null &&
          chat.lastMessage!.senderId == myUserId &&
          !chat.lastMessage!.isRead) {
        updated[index] = chat.copyWith(
          lastMessage: chat.lastMessage!.copyWith(isRead: true),
        );
        state = AsyncData<List<ApiChatSummary>>(updated);
        _persistChats(updated);
      }
    }
  }

  void _handleDeletedPush(ApiMessage message) {
    final List<ApiChatSummary>? currentChats = state.value;
    if (currentChats == null) return;

    final int index = currentChats.indexWhere(
      (ApiChatSummary c) => c.id == message.chatId,
    );
    if (index == -1) return;
    final ApiChatSummary chat = currentChats[index];
    if (chat.lastMessage?.id != message.id) return;

    final List<ApiChatSummary> updated = List<ApiChatSummary>.from(
      currentChats,
    );
    updated[index] = chat.copyWith(
      lastMessage: chat.lastMessage?.copyWith(
        content: 'Сообщение удалено',
        isDeleted: true,
      ),
    );
    state = AsyncData<List<ApiChatSummary>>(updated);
    _persistChats(updated);
  }

  void _handleReactionPush(
    ApiMessage message,
    String rawEmoji, {
    required bool added,
  }) {
    final String emoji = normalizeReactionEmoji(rawEmoji);
    if (emoji.isEmpty) return;
    final List<ApiChatSummary>? currentChats = state.value;
    if (currentChats == null) return;

    final int index = currentChats.indexWhere(
      (ApiChatSummary c) => c.id == message.chatId,
    );
    if (index == -1) return;
    final ApiChatSummary chat = currentChats[index];
    if (chat.lastMessage?.id != message.id) return;

    final Map<String, int> reactions = Map<String, int>.from(
      chat.lastMessage!.reactions,
    );
    final int count = (reactions[emoji] ?? 0) + (added ? 1 : -1);
    if (count > 0) {
      reactions[emoji] = count;
    } else {
      reactions.remove(emoji);
    }

    final List<ApiChatSummary> updated = List<ApiChatSummary>.from(
      currentChats,
    );
    updated[index] = chat.copyWith(
      lastMessage: chat.lastMessage!.copyWith(reactions: reactions),
    );
    state = AsyncData<List<ApiChatSummary>>(updated);
    _persistChats(updated);
  }

  void _handleEditedPush(ApiMessage message) {
    final List<ApiChatSummary>? currentChats = state.value;
    if (currentChats == null) return;

    final int index = currentChats.indexWhere(
      (ApiChatSummary c) => c.id == message.chatId,
    );
    if (index == -1) return;
    final ApiChatSummary chat = currentChats[index];
    if (chat.lastMessage?.id != message.id) return;

    final List<ApiChatSummary> updated = List<ApiChatSummary>.from(
      currentChats,
    );
    updated[index] = chat.copyWith(lastMessage: message);
    state = AsyncData<List<ApiChatSummary>>(updated);
    _persistChats(updated);
  }

  void _handleNewMessagePush(ApiMessage message) {
    final List<ApiChatSummary>? currentChats = state.value;
    if (currentChats == null) return;

    final int index = currentChats.indexWhere(
      (ApiChatSummary c) => c.id == message.chatId,
    );
    final int myUserId = ref.read(authProvider).session?.userId ?? -1;
    final bool isCurrentChatOpen =
        PushNotificationService.currentChatId == message.chatId;

    if (index != -1) {
      final List<ApiChatSummary> updated = List<ApiChatSummary>.from(
        currentChats,
      );
      final ApiChatSummary chat = updated[index];

      final int newUnreadCount =
          (message.senderId != myUserId && !isCurrentChatOpen)
          ? chat.unreadCount + 1
          : (isCurrentChatOpen ? 0 : chat.unreadCount);

      updated[index] = chat.copyWith(
        lastMessage: message,
        unreadCount: newUnreadCount,
      );

      // Sort chats by last activity
      updated.sort((ApiChatSummary a, ApiChatSummary b) {
        final DateTime timeA = a.lastMessage?.sentAt ?? a.lastActivity;
        final DateTime timeB = b.lastMessage?.sentAt ?? b.lastActivity;
        return timeB.compareTo(timeA);
      });

      state = AsyncData<List<ApiChatSummary>>(updated);
      _persistChats(updated);

      if (message.senderId != myUserId && isCurrentChatOpen) {
        // Chat is currently open: automatically mark read on backend in real time
        unawaited(ref.read(chatRepositoryProvider).markRead(message.chatId));
      }

      if (message.senderId != myUserId) {
        final String chatName = chat.name.isNotEmpty ? chat.name : 'NiosMess';
        final String body = message.content.isNotEmpty
            ? message.content
            : (message.msgType == 'media' ? '📎 Media' : '...');
        NotificationStorage.createAndSave(
          title: chatName,
          body: body,
          route: '/chat/${message.chatId}',
        );

        final bool isMuted =
            ref.read(chatMutedProvider(chat.id)).value ?? false;
        if (!isCurrentChatOpen && !isMuted) {
          ref
              .read(inAppNotificationProvider.notifier)
              .show(
                InAppNotificationItem(
                  id: 'msg_${message.id}',
                  title: chatName,
                  body: body,
                  avatarUrl: chat.avatarUrl,
                  chatId: message.chatId,
                  route: '/chat/${message.chatId}',
                  timestamp: message.sentAt,
                ),
              );
        }
      }
    } else {
      refresh();
      if (message.senderId != myUserId && !isCurrentChatOpen) {
        final String body = message.content.isNotEmpty
            ? message.content
            : (message.msgType == 'media' ? '📎 Media' : '...');
        NotificationStorage.createAndSave(
          title: 'NiosMess',
          body: body,
          route: '/chat/${message.chatId}',
        );
        ref
            .read(inAppNotificationProvider.notifier)
            .show(
              InAppNotificationItem(
                id: 'msg_${message.id}',
                title: 'NiosMess',
                body: body,
                chatId: message.chatId,
                route: '/chat/${message.chatId}',
                timestamp: message.sentAt,
              ),
            );
      }
    }
  }

  Future<List<ApiChatSummary>> _fetch() async {
    try {
      final secret = await ref.read(secretChatCoordinatorProvider.future);
      if (secret != null) await secret.register();
      final remote = await ref
          .read(chatRepositoryProvider)
          .listChats(publicKey: secret?.engine.publicKey);
      if (secret != null) await secret.importChats(remote);
      final chats = secret?.mergeChats(remote) ?? remote;
      // Save cache
      _persistChats(chats);
      return chats;
    } catch (e) {
      final List<ApiChatSummary>? currentData = state.value;
      if (currentData != null && currentData.isNotEmpty) {
        return currentData;
      }
      rethrow;
    }
  }

  Future<void> refresh() async {
    final bool authenticated = ref.read(authProvider).isAuthenticated;
    if (!authenticated) {
      state = const AsyncData<List<ApiChatSummary>>(<ApiChatSummary>[]);
      return;
    }

    try {
      final List<ApiChatSummary> chats = await _fetch();
      state = AsyncData<List<ApiChatSummary>>(chats);
    } catch (e) {
      // Do not overwrite state with error if we have cached data
      if (state.value == null || state.value!.isEmpty) {
        state = AsyncError<List<ApiChatSummary>>(e, StackTrace.current);
      }
    }
  }

  void upsertChat(ApiChatSummary chat) {
    final List<ApiChatSummary>? current = state.value;
    if (current == null) {
      state = AsyncData<List<ApiChatSummary>>(<ApiChatSummary>[chat]);
      return;
    }
    final int idx = current.indexWhere((ApiChatSummary c) => c.id == chat.id);
    final List<ApiChatSummary> updated = List<ApiChatSummary>.from(current);
    if (idx != -1) {
      final ApiChatSummary known = current[idx];
      final String? knownKey = known.partnerPublicKey;
      final bool keyMissing =
          chat.partnerPublicKey == null || chat.partnerPublicKey!.isEmpty;
      final bool badgesMissing =
          chat.partnerBadges.isEmpty && known.partnerBadges.isNotEmpty;
      updated[idx] = chat.copyWith(
        partnerPublicKey:
            (keyMissing && knownKey != null && knownKey.isNotEmpty)
            ? knownKey
            : null,
        partnerBadges: badgesMissing ? known.partnerBadges : null,
      );
    } else {
      updated.insert(0, chat);
    }
    state = AsyncData<List<ApiChatSummary>>(updated);
    _persistChats(updated);
  }

  void setChatBlockedByUser(int chatId, bool isBlocked) {
    final List<ApiChatSummary>? current = state.value;
    if (current == null) return;
    final int idx = current.indexWhere((ApiChatSummary c) => c.id == chatId);
    if (idx == -1) return;
    final ApiChatSummary chat = current[idx];
    if (chat.isBlockedByUser == isBlocked) return;
    final List<ApiChatSummary> updated = List<ApiChatSummary>.from(current);
    updated[idx] = chat.copyWith(
      isBlockedByUser: isBlocked,
      isBlocked: isBlocked || chat.isBlockedByMe,
    );
    state = AsyncData<List<ApiChatSummary>>(updated);
    _persistChats(updated);
  }

  void markChatAsRead(int chatId) {
    final List<ApiChatSummary>? current = state.value;
    if (current == null) return;
    final int idx = current.indexWhere((ApiChatSummary c) => c.id == chatId);
    if (idx == -1) return;
    final ApiChatSummary chat = current[idx];
    if (chat.unreadCount == 0) return;
    final List<ApiChatSummary> updated = List<ApiChatSummary>.from(current);
    updated[idx] = chat.copyWith(unreadCount: 0);
    state = AsyncData<List<ApiChatSummary>>(updated);
    _persistChats(updated);
  }
}

final AsyncNotifierProvider<ChatsNotifier, List<ApiChatSummary>> chatsProvider =
    AsyncNotifierProvider<ChatsNotifier, List<ApiChatSummary>>(
      ChatsNotifier.new,
    );

final chatByIdProvider = Provider.family<ApiChatSummary?, int>((
  Ref ref,
  int chatId,
) {
  final AsyncValue<List<ApiChatSummary>> value = ref.watch(chatsProvider);
  return value.maybeWhen(
    data: (List<ApiChatSummary> chats) {
      for (final ApiChatSummary chat in chats) {
        if (chat.id == chatId) {
          return chat;
        }
      }
      return null;
    },
    orElse: () => null,
  );
});

/// Total unread message count across all chats — drives the nav bar badge.
final Provider<int> totalUnreadCountProvider = Provider<int>((Ref ref) {
  final AsyncValue<List<ApiChatSummary>> chats = ref.watch(chatsProvider);
  return chats.maybeWhen(
    data: (List<ApiChatSummary> list) =>
        list.fold(0, (int sum, ApiChatSummary c) => sum + c.unreadCount),
    orElse: () => 0,
  );
});

int _compareMessages(ApiMessage a, ApiMessage b) {
  final bool aPending = a.id < 0 || a.isSending;
  final bool bPending = b.id < 0 || b.isSending;

  if (aPending != bPending) {
    final int timeCmp = a.resolvedSentAt.compareTo(b.resolvedSentAt);
    if (timeCmp != 0) return timeCmp;
    return aPending ? 1 : -1;
  }

  final int timeCmp = a.resolvedSentAt.compareTo(b.resolvedSentAt);
  if (timeCmp != 0) return timeCmp;

  if (!aPending && !bPending) {
    return a.id.compareTo(b.id);
  }

  return a.id.abs().compareTo(b.id.abs());
}

class ChatHistoryWindowState {
  const ChatHistoryWindowState({
    required this.hasNewer,
    required this.followingLatest,
    required this.incomingRevision,
    required this.revision,
  });
  final bool hasNewer;
  final bool followingLatest;
  final int incomingRevision;
  final int revision;
}

final chatHistoryWindowProvider = Provider.autoDispose
    .family<ChatHistoryWindowState, int>((ref, id) {
      ref.watch(chatMessagesProvider(id));
      return ref.read(chatMessagesProvider(id).notifier).window;
    });

final chatHistoryRetentionProvider = Provider<ChatHistoryRetention>((ref) {
  ref.watch(authProvider.select((state) => state.session?.userId));
  final retention = ChatHistoryRetention();
  ref.onDispose(retention.dispose);
  return retention;
});

class ChatMessagesNotifier extends AsyncNotifier<List<ApiMessage>> {
  ChatMessagesNotifier(this._chatId);

  final int _chatId;
  int _sendCounter = 0;
  SecretChatCoordinator? _secret;
  bool _secretMarkingRead = false;
  Future<void>? _refreshInFlight;
  Future<int>? _olderInFlight;

  Timer? _cacheFlushTimer;
  List<ApiMessage>? _pendingCacheSnapshot;
  bool _cacheWriteInFlight = false;
  Timer? _ephemeralEvictionTimer;
  KeepAliveLink? _pendingSendLease;
  int? _cacheAccountId;
  int? _cacheAccountGeneration;
  int _generation = 0;

  static const maxVisibleMessages = 300;
  EncryptedHistoryArchive? _historyArchive;
  final Map<int, ApiMessage> _persistedWindow = {};
  List<ApiMessage>? _archivePending;
  final Set<int> _archiveRemovals = {};
  Future<void>? _archiveTask;
  Future<void>? _newerInFlight;
  Future<void>? _latestInFlight;
  bool _projectingWindow = false;
  bool _followingLatest = true;
  bool _hasNewerArchived = false;
  String? _lowerWindowKey, _upperWindowKey;
  int _windowRevision = 0;
  int _selectionRevision = 0;
  int _incomingRevision = 0;
  Object? _archiveError;
  final _historyLoads = <Map<int, ApiMessage?>>{};

  void _recordHistoryMutation(int id, ApiMessage? message) {
    for (final changes in _historyLoads) {
      changes[id] = message;
    }
  }

  Future<T> _withHistoryMutations<T>(
    Future<T> Function(Map<int, ApiMessage?> changes) operation,
  ) async {
    final changes = <int, ApiMessage?>{};
    _historyLoads.add(changes);
    try {
      return await operation(changes);
    } finally {
      _historyLoads.remove(changes);
    }
  }

  List<ApiMessage> _overlayHistoryMutations(
    List<ApiMessage> rows,
    Map<int, ApiMessage?> changes,
  ) => [
    for (final row in rows)
      if (!changes.containsKey(row.id)) row else ?changes[row.id],
  ]..sort(_compareMessages);

  ChatHistoryWindowState get window => ChatHistoryWindowState(
    hasNewer: _hasNewerArchived,
    followingLatest: _followingLatest,
    incomingRevision: _incomingRevision,
    revision: _windowRevision,
  );

  void setFollowingLatest(bool atBottom) {
    if (_secret != null) return;
    _followingLatest = atBottom && !_hasNewerArchived;
    final current = state.value;
    if (current != null && current.isNotEmpty) {
      _lowerWindowKey = _historyArchive?.orderKey(current.first);
      _upperWindowKey = _historyArchive?.orderKey(current.last);
    }
  }

  void _observeHistory(List<ApiMessage>? previous, List<ApiMessage>? next) {
    if (_projectingWindow ||
        _secret != null ||
        next == null ||
        _historyArchive == null) {
      return;
    }
    final before = {for (final m in previous ?? const <ApiMessage>[]) m.id: m};
    final ids = next.map((m) => m.id).toSet();
    for (final m in next) {
      if (!identical(before[m.id], m)) _recordHistoryMutation(m.id, m);
    }
    for (final id in before.keys.where((id) => !ids.contains(id))) {
      _recordHistoryMutation(id, null);
    }
    _archiveRemovals.addAll(
      (previous ?? const <ApiMessage>[])
          .where((m) => !ids.contains(m.id))
          .map((m) => m.id),
    );
    _archivePending = next;
    if (_archiveTask != null) return;
    final generation = _generation;
    _archiveTask = _retainOperation(() => _archiveAndProject(generation))
        .catchError((Object error) {
          if (generation == _generation) _archiveError = error;
        })
        .whenComplete(() {
          if (generation == _generation) _archiveTask = null;
        });
  }

  Future<void> _archiveAndProject(int generation) async {
    final archive = _historyArchive;
    if (archive == null) return;
    while (_archivePending != null &&
        generation == _generation &&
        ref.mounted) {
      final snapshot = _archivePending!;
      _archivePending = null;
      final removals = Set<int>.from(_archiveRemovals)
        ..removeAll(snapshot.map((m) => m.id));
      _archiveRemovals.clear();
      final changed = snapshot
          .where((m) => !identical(_persistedWindow[m.id], m))
          .toList();
      try {
        await archive.write(changed, remove: removals);
      } catch (_) {
        _archiveRemovals.addAll(removals);
        _archivePending ??= snapshot;
        rethrow;
      }
      _archiveError = null;
      if (!ref.mounted || generation != _generation) return;
      _persistedWindow
        ..clear()
        ..addEntries(snapshot.map((m) => MapEntry(m.id, m)));
      if (_archivePending != null) continue;
      final List<ApiMessage> visible;
      if (_followingLatest ||
          _lowerWindowKey == null ||
          _upperWindowKey == null) {
        visible = snapshot.length > maxVisibleMessages
            ? snapshot.sublist(snapshot.length - maxVisibleMessages)
            : snapshot;
      } else {
        visible = snapshot
            .where((m) {
              final key = archive.orderKey(m);
              return key.compareTo(_lowerWindowKey!) >= 0 &&
                  key.compareTo(_upperWindowKey!) <= 0;
            })
            .take(maxVisibleMessages)
            .toList();
      }
      _replaceWindow(visible);
    }
  }

  Future<void> flushHistoryArchive() async {
    if (_archiveTask == null && _archivePending != null) {
      _observeHistory(null, _archivePending);
    }
    await _archiveTask;
    final error = _archiveError;
    if (error != null) throw error;
  }

  void _replaceWindow(
    List<ApiMessage> messages, {
    bool? followingLatest,
    bool? hasNewer,
  }) {
    if (followingLatest != null) _selectionRevision++;
    final archive = _historyArchive;
    if (followingLatest != null) _followingLatest = followingLatest;
    _hasNewerArchived =
        hasNewer ??
        (archive != null &&
            messages.isNotEmpty &&
            archive.hasAfter(messages.last));
    if (messages.isNotEmpty) {
      _lowerWindowKey = archive?.orderKey(messages.first);
      _upperWindowKey = archive?.orderKey(messages.last);
    }
    _persistedWindow
      ..clear()
      ..addEntries(messages.map((m) => MapEntry(m.id, m)));
    _windowRevision++;
    _projectingWindow = true;
    try {
      state = AsyncData(List<ApiMessage>.of(messages));
    } finally {
      _projectingWindow = false;
    }
  }

  Future<void> loadNewer({int pageSize = 50}) =>
      _newerInFlight ??= _retainOperation(
        () => _withHistoryMutations((changes) async {
          await flushHistoryArchive();
          final archive = _historyArchive;
          final current = state.value;
          if (archive == null || current == null || current.isEmpty) return;
          final generation = _generation;
          final revision = _selectionRevision;
          var newer = await archive.read(after: current.last, limit: pageSize);
          if (newer.isNotEmpty &&
              ref.read(webSocketClientProvider).isConnected) {
            final confirmed = newer.where((m) => m.id > 0).toList();
            if (confirmed.isNotEmpty) {
              newer = await _revalidateArchivedPage(
                archive,
                newer,
                beforeId: confirmed.last.id + 1,
                pageSize: confirmed.length,
                after: current.last,
              );
            }
          }
          if (!ref.mounted ||
              generation != _generation ||
              revision != _selectionRevision) {
            return;
          }
          final byId = {for (final m in current) m.id: m};
          for (final m in _overlayHistoryMutations(newer, changes)) {
            byId.putIfAbsent(m.id, () => m);
          }
          final merged = byId.values.toList()..sort(_compareMessages);
          final visible = merged.length > maxVisibleMessages
              ? merged.sublist(merged.length - maxVisibleMessages)
              : merged;
          _replaceWindow(
            visible,
            followingLatest: newer.isEmpty || !archive.hasAfter(visible.last),
            hasNewer: newer.isEmpty ? false : null,
          );
        }),
      ).whenComplete(() => _newerInFlight = null);

  Future<bool> loadAround(int messageId) => _retainOperation(
    () => _withHistoryMutations((changes) async {
      await flushHistoryArchive();
      final archive = _historyArchive;
      if (archive == null) return false;
      final generation = _generation;
      var target = await archive.message(messageId);
      if (target == null) {
        final fetched = await _fetchHistoryPage(
          beforeId: messageId + 1,
          pageSize: 80,
        );
        target = fetched.rows.where((m) => m.id == messageId).firstOrNull;
      }
      if (target == null || !ref.mounted || generation != _generation) {
        return false;
      }
      final older = await archive.read(
        before: target,
        limit: maxVisibleMessages ~/ 2,
      );
      final newer = await archive.read(
        after: target,
        limit: maxVisibleMessages ~/ 2 - 1,
      );
      if (!ref.mounted || generation != _generation) return false;
      final visible = _overlayHistoryMutations([
        ...older,
        target,
        ...newer,
      ], changes);
      if (!visible.any((row) => row.id == messageId)) return false;
      _replaceWindow(visible, followingLatest: false);
      return true;
    }),
  );

  Future<void> jumpToLatest() => _latestInFlight ??= _retainOperation(
    () => _withHistoryMutations((changes) async {
      if (_secret != null) return;
      final generation = _generation;
      await flushHistoryArchive();
      final archive = _historyArchive;
      if (archive == null) {
        await refresh();
        return;
      }
      try {
        await _fetchHistoryPage(pageSize: 80);
        if (!ref.mounted || generation != _generation) return;
      } catch (_) {
        // An offline jump can still use every previously loaded row.
      }
      final latest = await archive.read(limit: maxVisibleMessages);
      if (!ref.mounted || generation != _generation) return;
      _replaceWindow(
        _overlayHistoryMutations(latest, changes),
        followingLatest: true,
        hasNewer: false,
      );
    }),
  ).whenComplete(() => _latestInFlight = null);

  Future<T> _retainOperation<T>(Future<T> Function() operation) async {
    final lease = ref.keepAlive();
    try {
      return await operation();
    } finally {
      lease.close();
    }
  }

  void _updatePendingSendLease(List<ApiMessage>? messages) {
    final pending =
        _secret == null &&
        (messages?.any((message) => message.isSending) ?? false);
    if (pending) {
      _pendingSendLease ??= ref.keepAlive();
    } else {
      _pendingSendLease?.close();
      _pendingSendLease = null;
    }
  }

  @override
  Future<List<ApiMessage>> build() async {
    final int generation = ++_generation;
    final int? accountId = ref.watch(
      authProvider.select(
        (AuthState state) =>
            state.isAuthenticated ? state.session?.userId : null,
      ),
    );
    if (_cacheAccountId != null && _cacheAccountId != accountId) {
      // Riverpod can retain the previous AsyncValue during a rebuild. History
      // from a different account must never become input to this account's
      // cache/network merge, including its optimistic messages.
      state = const AsyncData(<ApiMessage>[]);
      _refreshInFlight = null;
      _olderInFlight = null;
      _secretMarkingRead = false;
    }
    _cacheAccountId = accountId;
    _cacheAccountGeneration = accountId == null
        ? null
        : EncryptedMessageCache.accountGeneration(accountId);
    _secret = null;
    _historyArchive = null;
    _persistedWindow.clear();
    _archivePending = null;
    _archiveRemovals.clear();
    _archiveTask = null;
    _followingLatest = true;
    _hasNewerArchived = false;
    _lowerWindowKey = _upperWindowKey = null;
    final retention = ref.read(chatHistoryRetentionProvider);
    KeepAliveLink? idleLease = ref.keepAlive();
    var observed = false;
    void retainWhenIdle() {
      // Riverpod lifecycle callbacks forbid using Ref synchronously. Acquire a
      // fresh lease outside that callback, before the disposal frame runs.
      scheduleMicrotask(() {
        if (!ref.mounted || observed || generation != _generation) return;
        idleLease ??= ref.keepAlive();
        retention.retain(this, () {
          idleLease?.close();
          idleLease = null;
        });
      });
    }

    ref.onCancel(() {
      observed = false;
      retainWhenIdle();
    });
    void resumeHistory() {
      observed = true;
      retention.resume(this);
    }

    ref.onResume(resumeHistory);
    ref.onAddListener(resumeHistory);
    // read(notifier) without a listener must also have bounded retention.
    retainWhenIdle();
    listenSelf((previous, next) {
      _updatePendingSendLease(next.value);
      _scheduleMessageExpiry(next.value);
      _observeHistory(previous?.value, next.value);
    });
    ref.onDispose(() {
      retention.resume(this);
      _pendingSendLease?.close();
      _pendingSendLease = null;
      _ephemeralEvictionTimer?.cancel();
    });

    if (accountId == null) {
      return const <ApiMessage>[];
    }

    ApiChatSummary? summary = ref.read(chatByIdProvider(_chatId));
    if (summary == null) {
      try {
        await ref.read(chatsProvider.future);
      } catch (_) {}
      summary = ref.read(chatByIdProvider(_chatId));
    }
    if (!ref.mounted || generation != _generation) return const [];
    if (summary?.isSecret == true) {
      _secret = await ref.read(secretChatCoordinatorProvider.future);
      if (!ref.mounted || generation != _generation) return const [];
      final secret = _secret;
      if (secret == null) return const <ApiMessage>[];
      if (secret.engine.findChat(_chatId) == null &&
          summary?.partnerUserId != null &&
          !summary!.keyMismatch) {
        await secret.importChats([summary]);
      }
      if (!ref.mounted || generation != _generation) return const [];
      final subscription = secret.engine.changes.listen((chatKey) {
        if (!ref.mounted ||
            generation != _generation ||
            secret.engine.findChat(_chatId) != chatKey) {
          return;
        }
        final messages = _secretMessages();
        state = AsyncData(messages);
        if (!_secretMarkingRead &&
            PushNotificationService.currentChatId == _chatId &&
            messages.any((m) => m.senderId != secret.userId && !m.isRead)) {
          _secretMarkingRead = true;
          unawaited(
            markRead().whenComplete(() {
              if (generation == _generation) _secretMarkingRead = false;
            }),
          );
        }
      });
      ref.onDispose(() => unawaited(subscription.cancel()));
      secret.engine.wake();
      return _secretMessages();
    }

    ref.read(webSocketDispatcherProvider);
    WebSocketPushDispatcher.registerChat(_chatId, handlePush);
    final cacheUserId = accountId;
    final cacheGeneration = _cacheAccountGeneration;
    final connected = ref.read(webSocketClientProvider).onConnected.listen((_) {
      if (ref.mounted && PushNotificationService.currentChatId == _chatId) {
        unawaited(refresh());
      }
    });
    ref.onDispose(() {
      unawaited(connected.cancel());
      WebSocketPushDispatcher.unregisterChat(_chatId);
      _cacheFlushTimer?.cancel();
      _cacheFlushTimer = null;
      _ephemeralEvictionTimer?.cancel();
      _ephemeralEvictionTimer = null;
      final List<ApiMessage>? pending = _pendingCacheSnapshot;
      _pendingCacheSnapshot = null;
      if (pending != null) {
        unawaited(
          _writeCache(
            pending,
            userId: cacheUserId,
            isSecretChat: false,
            accountGeneration: cacheGeneration,
          ),
        );
      }
    });

    try {
      final archive = await EncryptedHistoryArchive.open(
        accountId,
        _chatId,
        generation: cacheGeneration,
      );
      if (!ref.mounted || generation != _generation) return const [];
      _historyArchive = archive;
      final restored = await archive.read(limit: maxVisibleMessages);
      if (!ref.mounted || generation != _generation) return const [];
      if (restored.isNotEmpty) _replaceWindow(restored, followingLatest: true);
    } catch (error) {
      _archiveError = error;
    }

    // Load cache immediately
    try {
      final List<ApiMessage> cached = await EncryptedMessageCache.loadMessages(
        _chatId,
        userId: cacheUserId,
      );
      if (!ref.mounted || generation != _generation) {
        return const <ApiMessage>[];
      }
      if (cached.isNotEmpty && (state.value?.isEmpty ?? true)) {
        state = AsyncData<List<ApiMessage>>(cached);
      }
    } catch (e) {
      debugPrint('[backend_chat_provider.dart] Messages cache load error: $e');
    }

    final List<ApiMessage> messages;
    try {
      messages = await _fetch();
    } catch (_) {
      if (!ref.mounted || generation != _generation) return const [];
      // Disk history is useful data while offline, not a loading placeholder
      // that should disappear when the first network refresh fails.
      final cached = state.value;
      if (cached == null || cached.isEmpty) rethrow;
      return _withoutExpiredMessages(cached);
    }
    if (!ref.mounted || generation != _generation) return const <ApiMessage>[];
    unawaited(ensureSecretHandshake());
    return _withoutExpiredMessages(messages);
  }

  List<ApiMessage> _secretMessages() =>
      _secret?.engine.messages(_chatId).map(ApiMessage.fromJson).toList() ??
      <ApiMessage>[];

  void handlePush(ChatPushEvent event) {
    if (event.message.chatId != _chatId) return;
    switch (event.kind) {
      case ChatPushEventKind.newMessage:
        _handleNewIncomingMessage(event.message);
      case ChatPushEventKind.edited:
        _handleEditedIncomingMessage(event.message);
      case ChatPushEventKind.deleted:
        _handleDeletedIncomingMessage(event.message);
      case ChatPushEventKind.reaction:
        _handleReactionPush(
          event.message,
          event.reactionEmoji ?? '',
          added: event.reactionAdded,
        );
      case ChatPushEventKind.read:
        _handleReadPush(event.userId!);
      case ChatPushEventKind.userStatus:
      case ChatPushEventKind.userBlocked:
        break;
    }
  }

  Future<void> _handleEditedIncomingMessage(ApiMessage message) async {
    final generation = _generation;
    ApiMessage next = message;
    // Secret chats: re-decrypt the edited payload.
    if (message.isE2ee && message.e2eeContent != null) {
      final List<ApiMessage> decrypted = await _decryptE2eeMessages(
        <ApiMessage>[message],
      );
      if (decrypted.isNotEmpty) next = decrypted.first;
    }

    if (!ref.mounted || generation != _generation) return;
    final List<ApiMessage> current = state.value ?? const <ApiMessage>[];
    final int index = current.indexWhere((ApiMessage m) => m.id == message.id);

    final List<ApiMessage> updated;
    if (index != -1) {
      updated = List<ApiMessage>.from(current)..[index] = next;
    } else {
      updated = List<ApiMessage>.from(current);
      insertSorted(updated, next, _compareMessages);
    }
    state = AsyncData<List<ApiMessage>>(updated);
    await _saveToCache(updated);
  }

  void _handleDeletedIncomingMessage(ApiMessage message) {
    _recordHistoryMutation(message.id, null);
    unawaited(
      _historyArchive
              ?.write([], remove: {message.id})
              .catchError((Object _) {}) ??
          Future<void>.value(),
    );
    final List<ApiMessage> current = state.value ?? const <ApiMessage>[];
    final int index = current.indexWhere((ApiMessage m) => m.id == message.id);
    unawaited(ChatMediaCache.removeMediaMessage(_chatId, message.id));
    if (index == -1) {
      unawaited(_purgeFromCache(message.id));
      return;
    }

    final List<ApiMessage> updated = List<ApiMessage>.from(current)
      ..removeAt(index);
    state = AsyncData<List<ApiMessage>>(updated);
    _saveToCache(updated);
  }

  Future<void> _purgeFromCache(int messageId) async {
    try {
      final int myUserId = ref.read(authProvider).session?.userId ?? -1;
      final int? userId = myUserId > 0 ? myUserId : null;
      final List<ApiMessage> cached = await EncryptedMessageCache.loadMessages(
        _chatId,
        userId: userId,
      );
      if (!cached.any((ApiMessage m) => m.id == messageId)) return;
      final ApiChatSummary? chat = ref.read(chatByIdProvider(_chatId));
      await EncryptedMessageCache.saveMessages(
        _chatId,
        cached.where((ApiMessage m) => m.id != messageId).toList(),
        userId: userId,
        isSecretChat: chat?.isSecret == true,
      );
    } catch (e) {
      debugPrint('[backend_chat_provider.dart] Purge cached message error: $e');
    }
  }

  void _handleReactionPush(
    ApiMessage message,
    String rawEmoji, {
    required bool added,
  }) {
    final String emoji = normalizeReactionEmoji(rawEmoji);
    if (emoji.isEmpty) return;
    final List<ApiMessage> current = state.value ?? const <ApiMessage>[];
    final int index = current.indexWhere((ApiMessage m) => m.id == message.id);
    if (index == -1) {
      unawaited(
        _historyArchive
                ?.patch(message.id, (row) {
                  final reactions = Map<String, int>.from(row.reactions);
                  final count = (reactions[emoji] ?? 0) + (added ? 1 : -1);
                  if (count > 0) {
                    reactions[emoji] = count;
                  } else {
                    reactions.remove(emoji);
                  }
                  return row.copyWith(reactions: reactions);
                })
                .catchError((Object _) {}) ??
            Future<void>.value(),
      );
      return;
    }

    final Map<String, int> reactions = Map<String, int>.from(
      current[index].reactions,
    );
    final int count = (reactions[emoji] ?? 0) + (added ? 1 : -1);
    if (count > 0) {
      reactions[emoji] = count;
    } else {
      reactions.remove(emoji);
    }

    final List<ApiMessage> updated = List<ApiMessage>.from(current)
      ..[index] = current[index].copyWith(reactions: reactions);
    state = AsyncData<List<ApiMessage>>(updated);
    _saveToCache(updated);
  }

  /// [userId] read the whole chat: every message NOT sent by them is now read.
  void _handleReadPush(int userId) {
    unawaited(
      _historyArchive?.markReadBy(userId).catchError((Object _) {}) ??
          Future<void>.value(),
    );
    final List<ApiMessage> current = state.value ?? const <ApiMessage>[];
    bool changed = false;
    final List<ApiMessage> updated = current.map((ApiMessage m) {
      if (m.senderId != userId && !m.isRead) {
        changed = true;
        return m.copyWith(isRead: true);
      }
      return m;
    }).toList();
    if (!changed) return;
    state = AsyncData<List<ApiMessage>>(updated);
    _saveToCache(updated);
  }

  Future<void> _handleNewIncomingMessage(ApiMessage message) async {
    final generation = _generation;
    final archive = _historyArchive;
    if (archive?.contains(message.id) == true &&
        await archive!.message(message.id) != null) {
      return;
    }
    if (!ref.mounted || generation != _generation) return;
    if ((state.value ?? const <ApiMessage>[]).any(
      (ApiMessage m) => m.id == message.id,
    )) {
      return;
    }

    final List<ApiMessage> decrypted = await _decryptE2eeMessages(<ApiMessage>[
      message,
    ]);
    if (decrypted.isEmpty) {
      // The message was E2EE protocol traffic (handshake) — not rendered.
      return;
    }
    final ApiMessage finalMessage = decrypted.first;
    if (!ref.mounted || generation != _generation) return;
    final int myUserId = ref.read(authProvider).session?.userId ?? -1;
    final List<ApiMessage> next = List<ApiMessage>.from(
      state.value ?? const <ApiMessage>[],
    );
    if (next.any((m) => m.id == finalMessage.id)) return;
    if (finalMessage.senderId == myUserId) {
      next.removeWhere((m) => m.id < 0 && m.content == finalMessage.content);
    }
    insertSorted(next, finalMessage, _compareMessages);
    if (finalMessage.senderId != myUserId) _incomingRevision++;

    state = AsyncData<List<ApiMessage>>(next);
    await _saveToCache(next);

    if (message.senderId != myUserId) {
      if (PushNotificationService.currentChatId == _chatId &&
          _followingLatest) {
        unawaited(markRead());
      } else {
        final String? myUsername = ref.read(authProvider).session?.username;
        final bool isMention =
            (myUsername != null &&
                myUsername.isNotEmpty &&
                finalMessage.content.contains('@$myUsername')) ||
            (finalMessage.replyToId != null &&
                state.value?.any(
                      (m) =>
                          m.id == finalMessage.replyToId &&
                          m.senderId == myUserId,
                    ) ==
                    true);
        await _playNotificationSound(isMention: isMention);
      }
    }
  }

  Future<List<ApiMessage>> _fetch({bool catchUp = false}) =>
      _withHistoryMutations((changes) => _fetchWindow(catchUp, changes));

  Future<List<ApiMessage>> _fetchWindow(
    bool catchUp,
    Map<int, ApiMessage?> changes,
  ) async {
    final generation = _generation;
    if (_secret != null) {
      _secret!.engine.wake();
      return _secretMessages();
    }
    final before = <int, ApiMessage>{
      for (final message in state.value ?? const <ApiMessage>[])
        message.id: message,
    };
    var newestKnown = before.keys.fold<int>(0, (a, b) => a > b ? a : b);
    final archive = _historyArchive;
    if (archive != null) {
      final archivedMax = await archive.highestServerId;
      if (archivedMax > newestKnown) newestKnown = archivedMax;
    }
    final messages = <ApiMessage>[];
    int page = 1;
    while (true) {
      final fetched = await _fetchHistoryPage(page: page, pageSize: 80);
      final batch = fetched.remote;
      final decodedBatch = fetched.rows;
      if (!ref.mounted || generation != _generation) {
        return const <ApiMessage>[];
      }
      final combined = mergeSorted(
        messages,
        decodedBatch.toList()..sort(_compareMessages),
        _compareMessages,
      );
      messages
        ..clear()
        ..addAll(
          archive != null && combined.length > maxVisibleMessages
              ? combined.sublist(combined.length - maxVisibleMessages)
              : combined,
        );
      if (!catchUp ||
          newestKnown == 0 ||
          batch.length < 80 ||
          batch.any((message) => message.id <= newestKnown)) {
        break;
      }
      page++;
    }
    final List<ApiMessage> decrypted = messages;
    if (!ref.mounted || generation != _generation) return const <ApiMessage>[];
    final current = <int, ApiMessage>{
      for (final message in state.value ?? const <ApiMessage>[])
        message.id: message,
    };
    final merged = <int, ApiMessage>{
      for (final message in decrypted) message.id: message,
    };
    final oldestFetched = merged.keys
        .where((id) => id > 0)
        .fold<int>(0, (a, b) => a == 0 || b < a ? b : a);
    for (final message in current.values) {
      // Preserve optimistic sends, older loaded pages and events received while
      // history was in flight. The server remains authoritative for unchanged rows.
      if (message.id < 0 ||
          (oldestFetched > 0 && message.id < oldestFetched) ||
          !identical(before[message.id], message)) {
        merged[message.id] = message;
      }
    }
    for (final id in before.keys) {
      if (!current.containsKey(id)) merged.remove(id);
    }
    final retained = current.values
        .where((message) => identical(merged[message.id], message))
        .toList();
    final fetched =
        decrypted
            .where(
              (message) =>
                  identical(merged[message.id], message) &&
                  !identical(current[message.id], message),
            )
            .toList()
          ..sort(_compareMessages);
    final result = _overlayHistoryMutations(
      mergeSorted(retained, fetched, _compareMessages),
      changes,
    );
    try {
      unawaited(_saveToCache(result));
    } catch (e) {
      debugPrint('[backend_chat_provider.dart] Save messages cache error: $e');
    }
    return result;
  }

  Future<String?> _getPartnerPublicKey() async {
    ApiChatSummary? chat = ref.read(chatByIdProvider(_chatId));
    if (chat == null) {
      try {
        await ref.read(chatsProvider.future);
        chat = ref.read(chatByIdProvider(_chatId));
      } catch (_) {}
    }
    if (chat?.isSecret == true &&
        chat?.partnerPublicKey != null &&
        chat!.partnerPublicKey!.isNotEmpty) {
      return chat.partnerPublicKey;
    }
    return null;
  }

  Future<List<ApiMessage>> _decryptE2eeMessages(
    List<ApiMessage> messages,
  ) async {
    final partnerPublicKey = await _getPartnerPublicKey();
    if (partnerPublicKey == null) {
      // Not a secret chat — but handshake echoes can still be filtered out.
      return messages
          .where((ApiMessage m) => _parseHeloMessage(m) == null)
          .toList();
    }

    final e2eeService = ref.read(e2eeServiceProvider);
    final int myUserId = ref.read(authProvider).session?.userId ?? -1;
    final List<ApiMessage> result = <ApiMessage>[];

    final Map<int, ApiMessage> alreadyDecrypted = <int, ApiMessage>{
      for (final ApiMessage m in state.value ?? const <ApiMessage>[])
        if (m.isDecrypted && m.id > 0) m.id: m,
    };

    for (int i = 0; i < messages.length; i++) {
      final ApiMessage msg = messages[i];

      final _E2eeHelo? helo = _parseHeloMessage(msg);
      if (helo != null) {
        // Handshake messages are protocol traffic — never rendered in UI.
        // Critical: never process our own HELO echo (КРИП-ECHO).
        if (msg.senderId != myUserId) {
          await _handleIncomingHelo(helo, partnerPublicKey);
        }
        continue;
      }

      final ApiMessage? known = alreadyDecrypted[msg.id];
      if (known != null) {
        result.add(known);
        continue;
      }

      // 1. SENDER PLAIN-TEXT PRESERVATION (КРИП-1 / ПЛАВ-1):
      // Double Ratchet sending chain cannot decrypt its own outgoing messages.
      if (msg.senderId == myUserId) {
        if (msg.content.isNotEmpty) {
          if (msg.id > 0) {
            unawaited(
              EncryptedMessageCache.saveSenderPlaintext(
                chatId: _chatId,
                messageId: msg.id,
                plaintext: msg.content,
                userId: myUserId > 0 ? myUserId : null,
              ),
            );
          }
          result.add(msg.copyWith(isDecrypted: true));
          continue;
        }

        // Content is empty (e.g. freshly fetched from server). Restore from cache.
        final String? stored = EncryptedMessageCache.getSenderPlaintext(
          chatId: _chatId,
          messageId: msg.id,
          userId: myUserId > 0 ? myUserId : null,
        );
        if (stored != null && stored.isNotEmpty) {
          result.add(msg.copyWith(content: stored, isDecrypted: true));
        } else {
          result.add(msg);
        }
        continue;
      }

      // 2. Already decrypted:
      if (msg.isDecrypted && msg.content.isNotEmpty) {
        result.add(msg);
        continue;
      }

      if (!msg.isE2ee || msg.e2eeContent == null || msg.e2eeContent!.isEmpty) {
        result.add(msg);
        continue;
      }

      try {
        final String decrypted = await e2eeService.decryptE2EEMessage(
          e2eeContentBase64: msg.e2eeContent!,
          chatId: _chatId,
          theirPublicKeyBase64: partnerPublicKey,
        );

        // Media envelope: carries the per-file AES key for local decryption.
        if (decrypted.startsWith('{"e2ee_file"') ||
            decrypted.startsWith('{"type":"nios_file_key"') ||
            decrypted.contains('"nios_file_key"')) {
          try {
            final Map<String, dynamic> envelope =
                jsonDecode(decrypted) as Map<String, dynamic>;
            final String? fk =
                (envelope['fk'] as String?) ?? (envelope['keyB64'] as String?);
            if (fk != null && fk.isNotEmpty) {
              result.add(
                msg.copyWith(
                  content: '',
                  isDecrypted: true,
                  e2eeFileKey: fk,
                  mediaName: (envelope['name'] as String?) ?? msg.mediaName,
                  mediaSize: msg.mediaSize ?? (envelope['size'] as int?),
                ),
              );
              continue;
            }
          } catch (_) {}
        }

        result.add(msg.copyWith(content: decrypted, isDecrypted: true));
      } catch (e) {
        debugPrint(
          '[backend_chat_provider.dart] E2EE decrypt failed for msg ${msg.id}: $e',
        );
        result.add(msg);
      }
    }
    return result;
  }

  /// Runs the receiving side of the E2EE handshake state machine:
  static final Map<int, Future<void>> _handshakeFutures = <int, Future<void>>{};

  /// Runs the receiving side of the E2EE handshake state machine:
  /// - no session → respond (create responder session, reply with our HELO);
  /// - pending initiator session → the peer's HELO completes it;
  /// - secured/compromised → ignore (old duplicate).
  Future<void> _handleIncomingHelo(
    _E2eeHelo helo,
    String partnerPublicKey,
  ) async {
    final E2eeService e2ee = ref.read(e2eeServiceProvider);
    await e2ee.ready;
    final E2eeSessionStatus status = e2ee.getSessionStatus(_chatId);
    final DoubleRatchetSession? existing = await e2ee.getOrCreateSession(
      chatId: _chatId,
      theirPublicKeyBase64: partnerPublicKey,
    );

    try {
      if (existing != null && status == E2eeSessionStatus.connecting) {
        await e2ee.completeHandshake(
          chatId: _chatId,
          theirEphemeralPublicKeyBase64: helo.dhPubB64,
          theirEdPublicKeyBase64: helo.edPubB64,
        );
        debugPrint(
          '[backend_chat_provider.dart] E2EE handshake completed for chat $_chatId',
        );
        return;
      }

      if (existing == null) {
        await e2ee.handleHeloMessage(
          chatId: _chatId,
          dhPubB64: helo.dhPubB64,
          edPubB64: helo.edPubB64,
          signature: helo.signature,
          theirPublicKeyBase64: partnerPublicKey,
          theirEdPublicKeyBase64: helo.edPubB64,
        );
        // Answer with our own ephemeral so the initiator can complete too.
        final ({String dhPubB64, String edPubB64, List<int> signature}) ack =
            await e2ee.createHandshakeMessage(_chatId);
        await sendHandshakeMessage(
          dhPubB64: ack.dhPubB64,
          edPubB64: ack.edPubB64,
          signature: ack.signature,
        );
        debugPrint(
          '[backend_chat_provider.dart] E2EE handshake responded for chat $_chatId',
        );
      }
    } catch (e) {
      debugPrint(
        '[backend_chat_provider.dart] E2EE handshake handling failed: $e',
      );
    }
  }

  /// Makes sure a secret direct chat eventually runs a Double Ratchet
  /// handshake without the user pressing anything: when no session exists,
  /// exactly one side (the one with the lexicographically greater static
  /// public key) initiates, the other responds on HELO receipt.
  Future<void> ensureSecretHandshake() async {
    if (_secret != null) {
      _secret!.engine.wake();
      return;
    }
    final Future<void>? active = _handshakeFutures[_chatId];
    if (active != null) {
      await active;
      return;
    }
    final Completer<void> completer = Completer<void>();
    _handshakeFutures[_chatId] = completer.future;

    try {
      final String? partnerPublicKey = await _getPartnerPublicKey();
      if (partnerPublicKey == null) return;

      final E2eeService e2ee = ref.read(e2eeServiceProvider);
      await e2ee.ready;
      final DoubleRatchetSession? existing = await e2ee.getOrCreateSession(
        chatId: _chatId,
        theirPublicKeyBase64: partnerPublicKey,
      );
      if (existing != null) return;

      final String ourPub = await e2ee.getPublicKeyBase64();
      if (ourPub.compareTo(partnerPublicKey) <= 0) return; // peer initiates

      await e2ee.initiateHandshake(
        chatId: _chatId,
        theirPublicKeyBase64: partnerPublicKey,
      );
      final ({String dhPubB64, String edPubB64, List<int> signature}) msg =
          await e2ee.createHandshakeMessage(_chatId);
      await sendHandshakeMessage(
        dhPubB64: msg.dhPubB64,
        edPubB64: msg.edPubB64,
        signature: msg.signature,
      );
      debugPrint(
        '[backend_chat_provider.dart] E2EE handshake auto-initiated for chat $_chatId',
      );
    } finally {
      completer.complete();
      _handshakeFutures.remove(_chatId);
    }
  }

  List<ApiMessage> _withoutExpiredMessages(List<ApiMessage> messages) {
    final now = DateTime.now().toUtc();
    return messages
        .where(
          (message) =>
              message.expiresAt == null || message.expiresAt!.isAfter(now),
        )
        .toList();
  }

  void _scheduleMessageExpiry(List<ApiMessage>? messages) {
    _ephemeralEvictionTimer?.cancel();
    _ephemeralEvictionTimer = null;
    // The durable secret engine owns its expiration policy.
    if (_secret != null || messages == null) return;
    DateTime? deadline;
    for (final message in messages) {
      final expires = message.expiresAt;
      if (expires != null && (deadline == null || expires.isBefore(deadline))) {
        deadline = expires;
      }
    }
    if (deadline == null) return;
    final delay = deadline.difference(DateTime.now().toUtc());
    _ephemeralEvictionTimer = Timer(
      delay.isNegative ? Duration.zero : delay,
      () {
        _ephemeralEvictionTimer = null;
        if (!ref.mounted) return;
        final current = state.value;
        if (current == null) return;
        final valid = _withoutExpiredMessages(current);
        if (valid.length != current.length) {
          state = AsyncData(valid);
          unawaited(_saveToCache(valid));
        } else {
          _scheduleMessageExpiry(current);
        }
      },
    );
  }

  Future<void> _saveToCache(List<ApiMessage> messages) async {
    _pendingCacheSnapshot = messages;
    if (_cacheFlushTimer != null || _cacheWriteInFlight) return;
    _cacheFlushTimer = Timer(const Duration(seconds: 2), _flushCache);
  }

  Future<void> _flushCache() async {
    _cacheFlushTimer = null;
    final List<ApiMessage>? snapshot = _pendingCacheSnapshot;
    _pendingCacheSnapshot = null;
    if (snapshot == null) return;

    _cacheWriteInFlight = true;
    try {
      await _writeCache(snapshot);
    } finally {
      _cacheWriteInFlight = false;
      if (ref.mounted &&
          _pendingCacheSnapshot != null &&
          _cacheFlushTimer == null) {
        _cacheFlushTimer = Timer(const Duration(seconds: 2), _flushCache);
      }
    }
  }

  Future<void> _writeCache(
    List<ApiMessage> messages, {
    int? userId,
    bool? isSecretChat,
    int? accountGeneration,
  }) async {
    try {
      final int myUserId = userId ?? _cacheAccountId ?? -1;
      final expectedGeneration = accountGeneration ?? _cacheAccountGeneration;
      bool accountErased() =>
          expectedGeneration != null &&
          expectedGeneration !=
              EncryptedMessageCache.accountGeneration(myUserId);
      if (accountErased()) return;
      final bool secret =
          isSecretChat ?? ref.read(chatByIdProvider(_chatId))?.isSecret == true;
      await EncryptedMessageCache.saveMessages(
        _chatId,
        messages,
        userId: myUserId > 0 ? myUserId : null,
        isSecretChat: secret,
        expectedAccountGeneration: expectedGeneration,
      );
      if (accountErased()) return;
      await ChatMediaCache.saveMediaMessages(_chatId, messages);
    } catch (e) {
      debugPrint('[backend_chat_provider.dart] Save messages cache error: $e');
    }
  }

  Future<void> _playNotificationSound({
    double? volume,
    bool isMention = false,
  }) async {
    final UiSettingsState settings = ref.read(uiSettingsProvider);
    if (!settings.soundEffects) return;
    final bool isMuted = ref.read(chatMutedProvider(_chatId)).value ?? false;
    if (isMuted) return;
    await ref
        .read(appSoundProvider)
        .playEvent(
          isMention ? SoundEvent.mention : SoundEvent.messageReceive,
          volume: volume,
        );
  }

  Future<void> refresh() {
    final generation = _generation;
    return _refreshInFlight ??= _retainOperation(_refreshHistory).whenComplete(
      () {
        if (generation == _generation) _refreshInFlight = null;
      },
    );
  }

  Future<void> _refreshHistory() async {
    final generation = _generation;
    final List<ApiMessage>? previous = state.value;
    final AsyncValue<List<ApiMessage>> next = await AsyncValue.guard(
      () => _fetch(catchUp: true),
    );
    if (!ref.mounted || generation != _generation) return;
    // A temporary connection error must not hide already displayed messages.
    if (next.hasError && state.value != null) return;
    state = next;
    final List<ApiMessage>? messages = next.value;
    if (previous == null || messages == null || previous.isEmpty) return;

    final int myUserId = ref.read(authProvider).session?.userId ?? -1;
    final int previousMaxId = previous.fold<int>(
      0,
      (int maxId, ApiMessage message) =>
          message.id > maxId ? message.id : maxId,
    );
    final bool hasIncoming = messages.any(
      (ApiMessage message) =>
          message.id > previousMaxId &&
          message.senderId != myUserId &&
          message.msgType != 'call_log',
    );
    if (hasIncoming) {
      if (PushNotificationService.currentChatId == _chatId &&
          _followingLatest) {
        unawaited(markRead());
      } else {
        await _playNotificationSound();
      }
    }
  }

  /// Existing before_id history is also the authority for cached edits/deletes.
  /// Offline navigation can use disk immediately; online pages reconcile only
  /// the returned ID interval, never infer deletions outside that interval.
  Future<List<ApiMessage>> _revalidateArchivedPage(
    EncryptedHistoryArchive archive,
    List<ApiMessage> cached, {
    required int beforeId,
    required int pageSize,
    ApiMessage? after,
  }) async {
    try {
      final fetched = await _fetchHistoryPage(
        beforeId: beforeId,
        pageSize: pageSize,
        reconcile: cached,
      );
      return fetched.rows
          .where((m) => after == null || _compareMessages(m, after) > 0)
          .toList()
        ..sort(_compareMessages);
    } catch (_) {
      return cached;
    }
  }

  /// Records mutations only for the lifetime of an in-flight request. Its
  /// bounded UI snapshot must not overwrite a push received during network I/O
  /// or decryption, including edits/deletes outside the visible window.
  Future<({List<ApiMessage> remote, List<ApiMessage> rows})> _fetchHistoryPage({
    int page = 1,
    int pageSize = 80,
    int? beforeId,
    List<ApiMessage>? reconcile,
  }) async {
    final changes = <int, ApiMessage?>{};
    _historyLoads.add(changes);
    final generation = _generation;
    try {
      final remote = await ref
          .read(chatRepositoryProvider)
          .getHistory(
            _chatId,
            page: page,
            pageSize: pageSize,
            beforeId: beforeId,
          );
      final decoded = await _decryptE2eeMessages(remote);
      if (!ref.mounted || generation != _generation) {
        return (remote: remote, rows: <ApiMessage>[]);
      }
      final rows = <ApiMessage>[];
      for (final row in decoded) {
        if (!changes.containsKey(row.id)) {
          rows.add(row);
        } else if (changes[row.id] case final changed?) {
          rows.add(changed);
        }
      }
      final ids = rows.map((m) => m.id).toSet();
      final lower = remote.length < pageSize || remote.isEmpty
          ? 0
          : remote.map((m) => m.id).reduce((a, b) => a < b ? a : b);
      final removals = <int>{
        for (final change in changes.entries)
          if (change.value == null) change.key,
        if (reconcile != null && beforeId != null)
          for (final cached in reconcile)
            if (cached.id > 0 &&
                cached.id >= lower &&
                cached.id < beforeId &&
                !ids.contains(cached.id) &&
                !changes.containsKey(cached.id))
              cached.id,
      };
      // This synchronously queues the disk transaction. Any subsequent push is
      // queued behind it, so its newer content wins without a permanent ID map.
      await _historyArchive?.write(rows, remove: removals);
      return (remote: remote, rows: _overlayHistoryMutations(rows, changes));
    } finally {
      _historyLoads.remove(changes);
    }
  }

  Future<int> loadOlder({int pageSize = 50}) {
    final generation = _generation;
    return _olderInFlight ??=
        _retainOperation(() => _loadOlder(pageSize: pageSize)).whenComplete(() {
          if (generation == _generation) _olderInFlight = null;
        });
  }

  Future<int> _loadOlder({int pageSize = 50}) =>
      _withHistoryMutations((changes) => _loadOlderWindow(pageSize, changes));

  Future<int> _loadOlderWindow(
    int pageSize,
    Map<int, ApiMessage?> changes,
  ) async {
    final generation = _generation;
    if (_secret != null) {
      _secret!.engine.wake();
      return 0;
    }
    final List<ApiMessage> current = state.value ?? const <ApiMessage>[];
    if (current.isEmpty) {
      final List<ApiMessage> initial = await _fetch();
      if (!ref.mounted || generation != _generation) return 0;
      state = AsyncData<List<ApiMessage>>(initial);
      return initial.length;
    }

    await flushHistoryArchive();
    final archive = _historyArchive;
    final revision = _selectionRevision;
    final int beforeId = current.first.id;
    final cachedOlder = archive == null
        ? const <ApiMessage>[]
        : await archive.read(before: current.first, limit: pageSize);
    final List<ApiMessage> older = cachedOlder.isNotEmpty
        ? (ref.read(webSocketClientProvider).isConnected
              ? await _revalidateArchivedPage(
                  archive!,
                  cachedOlder,
                  beforeId: beforeId,
                  pageSize: pageSize,
                )
              : cachedOlder)
        : (await _fetchHistoryPage(
            pageSize: pageSize,
            beforeId: beforeId,
          )).rows;

    if (older.isEmpty) {
      return 0;
    }

    // Decrypt ONLY newly fetched older slice, not the entire history
    final List<ApiMessage> decryptedOlder = _overlayHistoryMutations(
      older,
      changes,
    );

    if (!ref.mounted ||
        generation != _generation ||
        revision != _selectionRevision) {
      return 0;
    }
    // Read again after I/O so concurrent pushes/edits/deletions are retained.
    final latest = state.value ?? const <ApiMessage>[];
    final seen = latest.map((message) => message.id).toSet();
    final newOlder =
        decryptedOlder.where((message) => seen.add(message.id)).toList()
          ..sort(_compareMessages);
    final added = newOlder.length;
    final merged = mergeSorted(latest, newOlder, _compareMessages);
    if (archive != null) {
      if (!ref.mounted || generation != _generation) return 0;
      _replaceWindow(
        merged.take(maxVisibleMessages).toList(),
        followingLatest: false,
      );
    } else {
      // No eviction if the disk backing failed to open.
      state = AsyncData<List<ApiMessage>>(merged);
    }
    unawaited(_saveToCache(merged));
    return added;
  }

  Future<void> markRead() async {
    try {
      final generation = _generation;
      final secret = _secret;
      final remoteId =
          secret?.engine.chat(_chatId)['remote_id'] as int? ?? _chatId;
      if (remoteId <= 0) return;
      await ref.read(chatRepositoryProvider).markRead(remoteId);
      if (!ref.mounted || generation != _generation) return;
      await secret?.engine.markReadLocally(_chatId);
      if (!ref.mounted || generation != _generation) return;
      final int myUserId = ref.read(authProvider).session?.userId ?? -1;
      ref.read(chatsProvider.notifier)._handleReadPush(_chatId, myUserId);
    } catch (e) {
      debugPrint('[backend_chat_provider.dart] Error: $e');
    }
  }

  Future<void> send(
    String content, {
    int? replyToId,
    String? uploadId,
    String msgType = 'text',
    String? localId,
    String? e2eePlaintext,
    String? e2eeFileKey,
  }) => _retainOperation(
    () => _send(
      content,
      replyToId: replyToId,
      uploadId: uploadId,
      msgType: msgType,
      localId: localId,
      e2eePlaintext: e2eePlaintext,
      e2eeFileKey: e2eeFileKey,
    ),
  );

  Future<void> _send(
    String content, {
    int? replyToId,
    String? uploadId,
    String msgType = 'text',
    String? localId,
    String? e2eePlaintext,
    String? e2eeFileKey,
  }) async {
    final generation = _generation;
    if (ref.read(chatByIdProvider(_chatId)) == null && _secret == null) {
      try {
        await ref.read(chatsProvider.future);
      } catch (_) {}
      if (!ref.mounted || generation != _generation) return;
      if (ref.read(chatByIdProvider(_chatId)) == null) {
        throw StateError('Conversation metadata unavailable');
      }
    }
    if (ref.read(chatByIdProvider(_chatId))?.isSecret == true ||
        _secret != null) {
      final secret =
          _secret ?? await ref.read(secretChatCoordinatorProvider.future);
      if (secret == null) throw StateError('Secret storage unavailable');
      _secret = secret;
      await secret.engine.enqueue(_chatId, {
        'text': content,
        'type': msgType,
      }, replyToId: replyToId);
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(_secretMessages());
      return;
    }
    final String trimmed = content.trim();
    if (trimmed.isEmpty && (uploadId == null || uploadId.trim().isEmpty)) {
      return;
    }

    // Try to parse localId to an integer if it's already there
    final int tempId;
    if (localId != null) {
      tempId =
          int.tryParse(localId) ??
          -(DateTime.now().millisecondsSinceEpoch + _sendCounter++);
    } else {
      tempId = -(DateTime.now().millisecondsSinceEpoch + _sendCounter++);
    }

    final int myUserId = ref.read(authProvider).session?.userId ?? -1;
    final String myUsername = ref.read(authProvider).session?.username ?? '';

    String? e2eeContent;
    bool isE2ee = false;

    final ApiChatSummary? chat = ref.read(chatByIdProvider(_chatId));
    // For media in secret chats the DR plaintext is the file-key envelope,
    // not the visible text.
    final String e2eePlain = e2eePlaintext ?? trimmed;
    if (chat?.isSecret == true) {
      // Fail closed: in a secret chat every message MUST leave encrypted. If
      // anything here is missing we throw instead of falling through to a
      // plaintext send, which the server would happily store.
      final e2eeService = ref.read(e2eeServiceProvider);
      await e2eeService.ready;

      String? partnerKey = chat?.partnerPublicKey;
      if (partnerKey == null || partnerKey.isEmpty) {
        await ensureSecretHandshake();
        partnerKey = ref.read(chatByIdProvider(_chatId))?.partnerPublicKey;
      }
      if (partnerKey == null || partnerKey.isEmpty) {
        throw StateError(
          'Секретный чат: ключ собеседника не получен. Сообщение не отправлено, чтобы не уйти открытым текстом.',
        );
      }

      if (e2eePlain.isEmpty) {
        throw StateError('Секретный чат: нечего шифровать, отправка отменена.');
      }

      DoubleRatchetSession? session = await e2eeService.getOrCreateSession(
        chatId: _chatId,
        theirPublicKeyBase64: partnerKey,
      );
      if (session == null) {
        await ensureSecretHandshake();
        for (int i = 0; i < 6 && session == null; i++) {
          session = await e2eeService.getOrCreateSession(
            chatId: _chatId,
            theirPublicKeyBase64: partnerKey,
          );
          if (session == null) {
            await Future<void>.delayed(const Duration(milliseconds: 500));
          }
        }
      }
      if (session == null) {
        throw StateError(
          'Сквозное шифрование еще устанавливается. Пожалуйста, подождите завершения рукопожатия ключей.',
        );
      }
      try {
        e2eeContent = await e2eeService.encryptE2EEMessageDR(
          plaintext: e2eePlain,
          chatId: _chatId,
        );
        isE2ee = true;
      } catch (e) {
        if (!ref.mounted || generation != _generation) return;
        debugPrint('[backend_chat_provider.dart] E2EE encrypt failed: $e');
        rethrow;
      }
    }

    final ApiMessage optimisticMessage = ApiMessage(
      clientMessageId: 'normal:$_cacheAccountId:$_chatId:$tempId',
      id: tempId,
      chatId: _chatId,
      senderId: myUserId,
      senderUsername: myUsername,
      senderDisplayName: myUsername.isEmpty ? 'Я' : myUsername,
      senderBadges: const [],
      content: (isE2ee && uploadId != null) ? '' : trimmed,
      msgType: uploadId != null ? msgType : 'text',
      replyToId: replyToId,
      mediaUrl: uploadId != null
          ? 'local://$localId'
          : null, // placeholder indicating local file being sent
      mediaType: uploadId != null ? 'file' : null,
      mediaName: uploadId != null ? 'file' : null,
      mediaSize: null,
      mediaDuration: null,
      commentsCount: 0,
      reactions: const {},
      sentAt: DateTime.now(),
      editedAt: null,
      isDeleted: false,
      isSending: true,
      isFailed: false,
      isE2ee: isE2ee,
      e2eeContent: e2eeContent,
      e2eeFileKey: e2eeFileKey,
    );

    List<ApiMessage> current = state.value ?? const <ApiMessage>[];
    // Avoid duplicates if we already added it in optimistic UI from outside
    if (!current.any((m) => m.id == tempId)) {
      final next = List<ApiMessage>.from(current);
      insertSorted(next, optimisticMessage, _compareMessages);
      state = AsyncData<List<ApiMessage>>(next);
      unawaited(
        ref
            .read(appSoundProvider)
            .playEvent(
              msgType == 'sticker'
                  ? SoundEvent.stickerSend
                  : SoundEvent.messageSend,
            ),
      );
    }

    try {
      ApiMessage sent = await ref
          .read(chatRepositoryProvider)
          .sendMessage(
            _chatId,
            content: isE2ee ? '' : trimmed,
            replyToId: replyToId,
            uploadId: uploadId,
            e2eeContent: e2eeContent,
          );

      if (!ref.mounted || generation != _generation) return;
      sent = sent.copyWith(clientMessageId: optimisticMessage.clientMessageId);
      if (isE2ee) {
        sent = sent.copyWith(
          content: trimmed,
          e2eeFileKey: e2eeFileKey,
          isDecrypted: true,
        );
        if (sent.id > 0) {
          unawaited(
            EncryptedMessageCache.saveSenderPlaintext(
              chatId: _chatId,
              messageId: sent.id,
              plaintext: trimmed,
              userId: myUserId > 0 ? myUserId : null,
            ),
          );
        }
      }

      _archiveRemovals.add(tempId);
      current = state.value ?? const <ApiMessage>[];
      List<ApiMessage> next = List<ApiMessage>.from(current)
        ..removeWhere((ApiMessage message) => message.id == tempId)
        ..removeWhere((ApiMessage message) => message.id == sent.id);
      insertSorted(next, sent, _compareMessages);

      state = AsyncData<List<ApiMessage>>(next);
      await _saveToCache(next);
      ref.read(chatsProvider.notifier)._handleNewMessagePush(sent);
      ref.read(chatsProvider.notifier).setChatBlockedByUser(_chatId, false);
    } catch (e) {
      if (!ref.mounted || generation != _generation) return;
      current = state.value ?? const <ApiMessage>[];
      List<ApiMessage> next = List<ApiMessage>.from(current);
      final int index = next.indexWhere((ApiMessage m) => m.id == tempId);
      final failed = optimisticMessage.copyWith(
        isSending: false,
        isFailed: true,
      );
      if (index != -1) {
        next[index] = failed;
        state = AsyncData<List<ApiMessage>>(next);
      } else {
        // The user may have paged away while the account-owned send was active.
        // Persist its final status even though its bubble is outside the window.
        await _historyArchive?.write([failed]);
      }
    }
  }

  Future<void> sendSticker(int stickerId, {int? replyToId}) =>
      _retainOperation(() => _sendSticker(stickerId, replyToId: replyToId));

  Future<void> _sendSticker(int stickerId, {int? replyToId}) async {
    final generation = _generation;
    if (ref.read(chatByIdProvider(_chatId)) == null && _secret == null) {
      try {
        await ref.read(chatsProvider.future);
      } catch (_) {}
      if (!ref.mounted || generation != _generation) return;
      if (ref.read(chatByIdProvider(_chatId)) == null) {
        throw StateError('Conversation metadata unavailable');
      }
    }
    final int myUserId = ref.read(authProvider).session?.userId ?? -1;
    final String myUsername = ref.read(authProvider).session?.username ?? '';
    final int tempId =
        -(DateTime.now().millisecondsSinceEpoch + _sendCounter++);

    final List<ApiStickerSet> sets =
        ref.read(stickerSetsProvider).value ?? const <ApiStickerSet>[];
    ApiSticker? foundSticker;
    for (final ApiStickerSet s in sets) {
      for (final ApiSticker st in s.stickers) {
        if (st.id == stickerId) {
          foundSticker = st;
          break;
        }
      }
      if (foundSticker != null) break;
    }

    if (ref.read(chatByIdProvider(_chatId))?.isSecret == true ||
        _secret != null) {
      _secret ??= await ref.read(secretChatCoordinatorProvider.future);
      if (_secret == null) throw StateError('Secret account unavailable');
      if (foundSticker == null) throw StateError('Sticker unavailable');
      await _secret!.engine.enqueue(_chatId, {
        'text': '',
        'type': 'sticker',
        'sticker': foundSticker.toJson(),
      }, replyToId: replyToId);
      return;
    }

    final ApiMessage optimisticMessage = ApiMessage(
      clientMessageId: 'normal:$_cacheAccountId:$_chatId:$tempId',
      id: tempId,
      chatId: _chatId,
      senderId: myUserId,
      senderUsername: myUsername,
      senderDisplayName: myUsername.isEmpty ? 'Я' : myUsername,
      senderBadges: const [],
      content: '',
      msgType: 'sticker',
      sticker: foundSticker,
      stickerSetId: foundSticker?.setId,
      replyToId: replyToId,
      mediaUrl: foundSticker?.url,
      mediaType: foundSticker?.mediaType,
      mediaName: null,
      mediaSize: foundSticker?.fileSize,
      mediaDuration: foundSticker?.durationSeconds,
      commentsCount: 0,
      reactions: const {},
      sentAt: DateTime.now(),
      editedAt: null,
      isDeleted: false,
      isSending: true,
      isFailed: false,
    );

    List<ApiMessage> current = state.value ?? const <ApiMessage>[];
    List<ApiMessage> next = List<ApiMessage>.from(current);
    insertSorted(next, optimisticMessage, _compareMessages);
    state = AsyncData<List<ApiMessage>>(next);

    try {
      ApiMessage sent = await ref
          .read(chatRepositoryProvider)
          .sendSticker(_chatId, stickerId, replyToId: replyToId);

      if (!ref.mounted || generation != _generation) return;
      sent = sent.copyWith(clientMessageId: optimisticMessage.clientMessageId);
      _archiveRemovals.add(tempId);
      current = state.value ?? const <ApiMessage>[];
      next = List<ApiMessage>.from(current)
        ..removeWhere((ApiMessage m) => m.id == tempId || m.id == sent.id);
      insertSorted(next, sent, _compareMessages);

      state = AsyncData<List<ApiMessage>>(next);
      await _saveToCache(next);
      ref.read(chatsProvider.notifier)._handleNewMessagePush(sent);
      await _playNotificationSound(volume: 0.65);
    } catch (e) {
      if (!ref.mounted || generation != _generation) return;
      debugPrint('[backend_chat_provider.dart] sendSticker error: $e');
      if (!ref.mounted || generation != _generation) return;
      current = state.value ?? const <ApiMessage>[];
      final int index = current.indexWhere((ApiMessage m) => m.id == tempId);
      if (index != -1) {
        next = List<ApiMessage>.from(current);
        next[index] = next[index].copyWith(isSending: false, isFailed: true);
        state = AsyncData<List<ApiMessage>>(next);
      }
      rethrow;
    }
  }

  Future<void> sendHandshakeMessage({
    required String dhPubB64,
    required String edPubB64,
    required List<int> signature,
  }) async {
    final handshakePayload = jsonEncode({
      'dh': dhPubB64,
      'ed': edPubB64,
      'sig': base64Encode(signature),
    });

    try {
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(
            _chatId,
            content: handshakePayload,
            replyToId: null,
            uploadId: null,
            e2eeContent: null,
          );
    } catch (e) {
      debugPrint('[backend_chat_provider.dart] sendHandshakeMessage error: $e');
      rethrow;
    }
  }

  void addOptimisticLocalMessage(ApiMessage msg) {
    List<ApiMessage> current = state.value ?? const <ApiMessage>[];
    if (!current.any((m) => m.id == msg.id)) {
      final next = List<ApiMessage>.from(current);
      insertSorted(next, msg, _compareMessages);
      state = AsyncData<List<ApiMessage>>(next);
    }
  }

  void markLocalMessageFailed(String localId) {
    final int tempId = int.tryParse(localId) ?? 0;
    if (tempId == 0) return;
    List<ApiMessage> current = state.value ?? const <ApiMessage>[];
    final int index = current.indexWhere((m) => m.id == tempId);
    if (index == -1) {
      unawaited(
        _historyArchive
                ?.patch(
                  tempId,
                  (row) => row.copyWith(isSending: false, isFailed: true),
                )
                .catchError((Object _) {}) ??
            Future<void>.value(),
      );
    }
    if (index != -1) {
      List<ApiMessage> next = List<ApiMessage>.from(current);
      next[index] = next[index].copyWith(isSending: false, isFailed: true);
      state = AsyncData<List<ApiMessage>>(next);
    }
  }

  void markLocalMessageSending(int messageId) {
    if (messageId == 0) return;
    List<ApiMessage> current = state.value ?? const <ApiMessage>[];
    final int index = current.indexWhere((m) => m.id == messageId);
    if (index == -1) {
      unawaited(
        _historyArchive
                ?.patch(
                  messageId,
                  (row) => row.copyWith(isSending: true, isFailed: false),
                )
                .catchError((Object _) {}) ??
            Future<void>.value(),
      );
    }
    if (index != -1) {
      List<ApiMessage> next = List<ApiMessage>.from(current);
      next[index] = next[index].copyWith(isSending: true, isFailed: false);
      state = AsyncData<List<ApiMessage>>(next);
    }
  }

  void removeOptimisticMessage(int tempId) {
    if (tempId == 0) return;
    unawaited(
      _historyArchive?.write([], remove: {tempId}).catchError((Object _) {}) ??
          Future<void>.value(),
    );
    List<ApiMessage> current = state.value ?? const <ApiMessage>[];
    final List<ApiMessage> next = List<ApiMessage>.from(current)
      ..removeWhere((m) => m.id == tempId);
    state = AsyncData<List<ApiMessage>>(next);
    _saveToCache(next);
  }

  Future<void> editMessage(int messageId, String content) =>
      _retainOperation(() => _editMessage(messageId, content));

  Future<void> _editMessage(int messageId, String content) async {
    final generation = _generation;
    if (_secret != null) {
      await _secret!.engine.edit(_chatId, messageId, content);
      return;
    }
    final String trimmed = content.trim();
    if (trimmed.isEmpty) return;

    final List<ApiMessage> current = state.value ?? const <ApiMessage>[];
    final ApiMessage target = current.firstWhere(
      (ApiMessage m) => m.id == messageId,
      orElse: () => ApiMessage(
        id: 0,
        chatId: 0,
        senderId: 0,
        senderUsername: '',
        senderDisplayName: '',
        senderBadges: const <ApiBadge>[],
        content: '',
        msgType: 'text',
        replyToId: null,
        mediaUrl: null,
        mediaType: null,
        mediaName: null,
        mediaSize: null,
        mediaDuration: null,
        commentsCount: 0,
        reactions: <String, int>{},
        sentAt: DateTime.fromMillisecondsSinceEpoch(0),
        editedAt: null,
        isDeleted: false,
      ),
    );

    if (target.id == 0) return;

    final ApiMessage optimisticEdited = target.copyWith(
      content: trimmed,
      editedAt: DateTime.now(),
    );
    final List<ApiMessage> optimisticNext = List<ApiMessage>.from(current)
      ..removeWhere((ApiMessage m) => m.id == messageId);
    insertSorted(optimisticNext, optimisticEdited, _compareMessages);
    state = AsyncData<List<ApiMessage>>(optimisticNext);

    try {
      // Editing has to respect the same fail-closed rule as sending: in a
      // secret chat the new body is encrypted client-side before it leaves.
      String? editE2ee;
      final ApiChatSummary? editChat = ref.read(chatByIdProvider(_chatId));
      if (editChat?.isSecret == true) {
        final e2eeService = ref.read(e2eeServiceProvider);
        await e2eeService.ready;
        String? partnerKey = editChat?.partnerPublicKey;
        if (partnerKey == null || partnerKey.isEmpty) {
          await ensureSecretHandshake();
          partnerKey = ref.read(chatByIdProvider(_chatId))?.partnerPublicKey;
        }
        final DoubleRatchetSession? session =
            (partnerKey == null || partnerKey.isEmpty)
            ? null
            : await e2eeService.getOrCreateSession(
                chatId: _chatId,
                theirPublicKeyBase64: partnerKey,
              );
        if (session == null) {
          throw StateError(
            'Secret chat: peer key unavailable, edit cancelled.',
          );
        }
        editE2ee = await e2eeService.encryptE2EEMessageDR(
          plaintext: trimmed,
          chatId: _chatId,
        );
      }

      final ApiMessage? edited = await ref
          .read(chatRepositoryProvider)
          .editMessage(
            _chatId,
            messageId,
            content: trimmed,
            e2eeContent: editE2ee,
          );

      if (!ref.mounted || generation != _generation) return;
      if (edited != null) {
        final List<ApiMessage> confirmed = List<ApiMessage>.from(
          state.value ?? const <ApiMessage>[],
        )..removeWhere((ApiMessage m) => m.id == edited.id);
        insertSorted(confirmed, edited, _compareMessages);
        state = AsyncData<List<ApiMessage>>(confirmed);
        await _saveToCache(confirmed);
        ref.read(chatsProvider.notifier)._handleEditedPush(edited);
      }
    } catch (e) {
      if (!ref.mounted || generation != _generation) return;
      final List<ApiMessage> latest = state.value ?? const <ApiMessage>[];
      final List<ApiMessage> reverted = latest
          .map((m) => m.id == messageId ? target : m)
          .toList();
      state = AsyncData<List<ApiMessage>>(reverted);
    }
  }

  Future<void> deleteMessage(int messageId) =>
      _retainOperation(() => _deleteMessage(messageId));

  Future<void> _deleteMessage(int messageId) async {
    final generation = _generation;
    if (_secret != null) {
      await _secret!.engine.delete(_chatId, messageId);
      return;
    }
    final List<ApiMessage> current = state.value ?? const <ApiMessage>[];
    final ApiMessage? target = current
        .where((m) => m.id == messageId)
        .firstOrNull;
    final List<ApiMessage> optimisticNext = List<ApiMessage>.from(current)
      ..removeWhere((ApiMessage m) => m.id == messageId);
    state = AsyncData<List<ApiMessage>>(optimisticNext);

    try {
      await ref.read(chatRepositoryProvider).deleteMessage(_chatId, messageId);
      if (!ref.mounted || generation != _generation) return;
      await _saveToCache(optimisticNext);
      unawaited(ChatMediaCache.removeMediaMessage(_chatId, messageId));
      final ApiMessage deletedStub = _stubMessage(
        messageId,
        _chatId,
        isDeleted: true,
      );
      ref.read(chatsProvider.notifier)._handleDeletedPush(deletedStub);
    } catch (e) {
      if (!ref.mounted || generation != _generation) return;
      if (e is ApiException &&
          e.message.toLowerCase().contains('message not found')) {
        await _saveToCache(optimisticNext);
        unawaited(ChatMediaCache.removeMediaMessage(_chatId, messageId));
        final ApiMessage deletedStub = _stubMessage(
          messageId,
          _chatId,
          isDeleted: true,
        );
        ref.read(chatsProvider.notifier)._handleDeletedPush(deletedStub);
        return;
      }
      if (target != null) {
        final List<ApiMessage> latest = List<ApiMessage>.from(
          state.value ?? const <ApiMessage>[],
        );
        if (!latest.any((m) => m.id == messageId)) {
          insertSorted(latest, target, _compareMessages);
          state = AsyncData<List<ApiMessage>>(latest);
        }
      }
    }
  }

  void removeLocalMessage(int messageId) {
    final List<ApiMessage> current = state.value ?? const <ApiMessage>[];
    final List<ApiMessage> next = List<ApiMessage>.from(current)
      ..removeWhere((ApiMessage m) => m.id == messageId);
    state = AsyncData<List<ApiMessage>>(next);
  }

  Future<void> sendCallbackQuery(int messageId, String data) async {
    if (data.trim().isEmpty) return;
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendCallbackQuery(_chatId, messageId, data);
    } catch (e) {
      debugPrint('[backend_chat_provider.dart] sendCallbackQuery error: $e');
    }
  }

  Future<void> toggleReaction(int messageId, String rawEmoji) =>
      _retainOperation(() => _toggleReaction(messageId, rawEmoji));

  Future<void> _toggleReaction(int messageId, String rawEmoji) async {
    final generation = _generation;
    final String emoji = normalizeReactionEmoji(rawEmoji);
    if (emoji.isEmpty) return;

    final List<ApiMessage> current = state.value ?? const <ApiMessage>[];
    final ApiMessage? original = current
        .where((m) => m.id == messageId)
        .firstOrNull;

    final List<ApiMessage> optimisticNext = current
        .map((ApiMessage m) {
          if (m.id != messageId) return m;
          final Map<String, int> newReactions = Map<String, int>.from(
            m.reactions,
          );
          if (newReactions.containsKey(emoji)) {
            final int count = newReactions[emoji]!;
            if (count <= 1) {
              newReactions.remove(emoji);
            } else {
              newReactions[emoji] = count - 1;
            }
          } else {
            newReactions[emoji] = (newReactions[emoji] ?? 0) + 1;
          }
          return m.copyWith(reactions: newReactions);
        })
        .toList(growable: false);
    state = AsyncData<List<ApiMessage>>(optimisticNext);
    unawaited(ref.read(appSoundProvider).playEvent(SoundEvent.reaction));

    try {
      await ref
          .read(chatRepositoryProvider)
          .toggleReaction(_chatId, messageId, emoji: emoji);
      if (!ref.mounted || generation != _generation) return;
      await _saveToCache(optimisticNext);
      final ApiMessage? updatedMsg = optimisticNext
          .where((m) => m.id == messageId)
          .firstOrNull;
      if (updatedMsg != null) {
        ref.read(chatsProvider.notifier)._handleEditedPush(updatedMsg);
      }
    } catch (e) {
      if (!ref.mounted || generation != _generation) return;
      debugPrint('[backend_chat_provider.dart] toggleReaction error: $e');
      if (original != null) {
        final List<ApiMessage> latest = state.value ?? const <ApiMessage>[];
        final List<ApiMessage> reverted = latest
            .map((m) => m.id == messageId ? original : m)
            .toList();
        state = AsyncData<List<ApiMessage>>(reverted);
      }
      rethrow;
    }
  }
}

final chatMessagesProvider = AsyncNotifierProvider.autoDispose
    .family<ChatMessagesNotifier, List<ApiMessage>, int>(
      ChatMessagesNotifier.new,
    );

class PostCommentsArgs {
  const PostCommentsArgs({required this.channelId, required this.postId});

  final int channelId;
  final int postId;

  @override
  bool operator ==(Object other) {
    return other is PostCommentsArgs &&
        other.channelId == channelId &&
        other.postId == postId;
  }

  @override
  int get hashCode => Object.hash(channelId, postId);
}

class PostCommentsNotifier extends AsyncNotifier<List<ApiMessage>> {
  PostCommentsNotifier(this._args);

  final PostCommentsArgs _args;

  @override
  Future<List<ApiMessage>> build() async {
    final bool authenticated = ref.watch(
      authProvider.select((AuthState state) => state.isAuthenticated),
    );

    if (!authenticated) {
      return const <ApiMessage>[];
    }

    return _fetch();
  }

  Future<List<ApiMessage>> _fetch() {
    return ref
        .read(chatRepositoryProvider)
        .getComments(_args.channelId, _args.postId, pageSize: 80);
  }

  Future<void> _playNotificationSound({double volume = 0.65}) async {
    if (!ref.read(uiSettingsProvider).notifications) return;
    await ref.read(appSoundProvider).play(AppSound.message, volume: volume);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> send(String content, {int? replyToId}) async {
    final String trimmed = content.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final int userId = ref.read(authProvider).session?.userId ?? 0;

    final ApiMessage created = await ref
        .read(chatRepositoryProvider)
        .sendComment(
          _args.channelId,
          _args.postId,
          content: trimmed,
          replyToId: replyToId,
          senderId: userId,
        );

    final List<ApiMessage> current = state.value ?? const <ApiMessage>[];
    final List<ApiMessage> next = List<ApiMessage>.from(current)
      ..removeWhere((ApiMessage message) => message.id == created.id)
      ..add(created)
      ..sort(_compareMessages);

    state = AsyncData<List<ApiMessage>>(next);

    if (_args.channelId != 0) {
      await ref.read(chatMessagesProvider(_args.channelId).notifier).refresh();
    } else {
      ref.invalidate(niosgramProvider);
    }

    await _playNotificationSound();
  }

  Future<void> deleteComment(int commentId) async {
    final List<ApiMessage> current = state.value ?? const <ApiMessage>[];
    state = AsyncData<List<ApiMessage>>(
      current.where((ApiMessage message) => message.id != commentId).toList(),
    );
    try {
      await ref
          .read(chatRepositoryProvider)
          .deleteMessage(
            _args.channelId > 0 ? _args.channelId : _args.postId,
            commentId,
          );
    } catch (_) {}
  }
}

final postCommentsProvider =
    AsyncNotifierProvider.family<
      PostCommentsNotifier,
      List<ApiMessage>,
      PostCommentsArgs
    >(PostCommentsNotifier.new);

class ChatMembersNotifier extends AsyncNotifier<List<ApiChatMember>> {
  ChatMembersNotifier(this._chatId);

  final int _chatId;

  @override
  Future<List<ApiChatMember>> build() async {
    final bool authenticated = ref.watch(
      authProvider.select((AuthState state) => state.isAuthenticated),
    );
    if (!authenticated) return const <ApiChatMember>[];
    return _fetch();
  }

  Future<List<ApiChatMember>> _fetch() {
    return ref.read(chatRepositoryProvider).getMembers(_chatId);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_fetch);
  }
}

final chatMembersProvider =
    AsyncNotifierProvider.family<ChatMembersNotifier, List<ApiChatMember>, int>(
      ChatMembersNotifier.new,
    );

final myChatRoleProvider = Provider.family<String, int>((Ref ref, int chatId) {
  final int myUserId = ref.watch(
    authProvider.select((AuthState s) => s.session?.userId ?? -1),
  );
  final AsyncValue<List<ApiChatMember>> membersAsync = ref.watch(
    chatMembersProvider(chatId),
  );
  final List<ApiChatMember> members =
      membersAsync.value ?? const <ApiChatMember>[];
  for (final ApiChatMember m in members) {
    if (m.userId == myUserId) return m.role;
  }
  return 'member';
});
