import 'package:pulse_flutter/services/bluetooth_mesh/bluetooth_mesh_service.dart';
import 'package:pulse_flutter/services/bluetooth_mesh/mesh_history.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_service.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_codec.dart';
import 'package:pulse_flutter/providers/secret_chat_provider.dart';
import 'dart:async';
import 'package:pulse_flutter/models/interactive_message.dart';
import 'package:pulse_flutter/models/live_location.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/storage/cache_service.dart';
import 'package:pulse_flutter/core/storage/sorted_history.dart';
import 'package:pulse_flutter/providers/notifications_provider.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/core/services/push_notification_service.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/chat_muted_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/providers/websocket_dispatcher_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';

import 'chat_messages_provider.dart';

class ChatsNotifier extends AsyncNotifier<List<ApiChatSummary>> {
  int _generation = 0;
  bool _builtForSession = false;
  (int?, String?) _identity = (null, null);
  bool _valid(int generation) {
    if (!ref.mounted || generation != _generation) return false;
    if (!_builtForSession) return true;
    final session = ref.read(authProvider).session;
    return _identity == (session?.userId, session?.accessToken);
  }

  final _seenOperations = <String>{};

  /// Message keys already folded into the inbox counters. Unlike
  /// [_seenOperations] this survives a rebuild, so a mesh replay or a
  /// re-delivered push cannot bump the unread badge twice. It is cleared only
  /// when the account (or its token) changes.
  final _seenMessages = <String>{};

  /// Recently applied reaction pushes (event signature -> apply time). The WS
  /// dispatcher does not expose event ids, so duplicates are recognised by
  /// signature inside a short window instead.
  final Map<String, DateTime> _recentReactions = {};

  /// Monotonic `list_chats` sequence. Only the newest response may replace the
  /// state, otherwise a slow request would roll back fresher pushes.
  int _refreshSeq = 0;
  int _appliedSnapshotSeq = 0;

  /// Per-chat timestamp of the last local unread mutation, used to decide
  /// whether a server snapshot is allowed to lower a counter.
  final Map<int, DateTime> _unreadTouchedAt = {};

  /// Per-chat timestamp of the last local unread *decrease* (explicit read). A
  /// snapshot computed before that read must not resurrect the badge.
  final Map<int, DateTime> _unreadLoweredAt = {};

  /// Unread counters captured before an optimistic mark-read, per chat. Used to
  /// roll the badge back when the server call fails or cannot run.
  final Map<int, Map<int, int>> _readResets = {};

  /// Mute toggles made on this device that the server has not stored yet, by
  /// chat id. A snapshot must not undo them; they are sent again after it.
  final Map<int, bool> _muteUploads = <int, bool>{};
  bool _muteUploadRunning = false;

  /// Most chats one `set_chat_state` request may carry.
  static const int _stateBatch = 100;

  Timer? _persistTimer;
  final _previewDecryptions = <String>{};
  List<ApiChatSummary>? _pendingChats;
  int? _pendingChatsAccountId;
  CacheService? _pendingChatsCache;

  void _persistChats(List<ApiChatSummary> chats) {
    final generation = _generation;
    _pendingChats = chats;
    _pendingChatsAccountId = _identity.$1;
    _pendingChatsCache = ref.read(cacheServiceProvider);
    _persistTimer ??= Timer(const Duration(seconds: 2), () {
      _persistTimer = null;
      final List<ApiChatSummary>? snapshot = _pendingChats;
      final int? accountId = _pendingChatsAccountId;
      final CacheService? cache = _pendingChatsCache;
      _pendingChats = null;
      _pendingChatsAccountId = null;
      _pendingChatsCache = null;
      if (snapshot == null ||
          accountId == null ||
          cache == null ||
          !_valid(generation)) {
        return;
      }
      try {
        unawaited(cache.saveChats(snapshot, accountId: accountId));
      } catch (_) {}
    });
  }

  /// Flushes the debounced chat-list snapshot immediately so the last
  /// (up to 2s) batch of changes is not lost on rebuild, dispose or process
  /// death. When [onlyAccountId] is provided, a pending snapshot that belongs
  /// to another account is dropped instead of written (account switch must not
  /// leak the previous inbox into the cache). The method touches no provider,
  /// so it is safe to call from `onDispose`.
  void _flushPendingChats({int? onlyAccountId}) {
    _persistTimer?.cancel();
    _persistTimer = null;
    final List<ApiChatSummary>? snapshot = _pendingChats;
    final int? accountId = _pendingChatsAccountId;
    final CacheService? cache = _pendingChatsCache;
    _pendingChats = null;
    _pendingChatsAccountId = null;
    _pendingChatsCache = null;
    if (snapshot == null || accountId == null || cache == null) return;
    if (onlyAccountId != null && accountId != onlyAccountId) return;
    try {
      unawaited(cache.saveChats(snapshot, accountId: accountId));
    } catch (_) {}
  }

  @override
  Future<List<ApiChatSummary>> build() async {
    final identity = ref.watch(
      authProvider.select((s) => (s.session?.userId, s.session?.accessToken)),
    );
    final generation = ++_generation;
    final bool accountChanged = _identity != identity;
    _identity = identity;
    _builtForSession = true;
    if (accountChanged) {
      // Rebuilds keep the dedupe/dedupe-adjacent caches: Riverpod disposes and
      // rebuilds on `ref.invalidate`, and dropping them there re-counted every
      // replayed mesh operation. A different account must start clean.
      _seenOperations.clear();
      _seenMessages.clear();
      _recentReactions.clear();
      _unreadTouchedAt.clear();
      _unreadLoweredAt.clear();
      _readResets.clear();
      _muteUploads.clear();
    }
    _previewDecryptions.clear();
    // Riverpod carries the previous value through a rebuild, and another
    // account must not inherit it. The first build has nothing to drop: an
    // empty list published there read as "no chats" instead of loading.
    if (state.hasValue) {
      state = const AsyncData([]);
      state = const AsyncLoading();
    }
    if (identity.$1 == null || identity.$2 == null || identity.$2!.isEmpty) {
      return const <ApiChatSummary>[];
    }

    final ordinary = ref.read(ordinaryE2eeProvider);
    if (ordinary != null) {
      var previousEpoch = ordinary.keyState;
      void onKeysChanged() {
        final current = ordinary.keyState;
        if (current != 'locked' &&
            current != previousEpoch &&
            _valid(generation)) {
          previousEpoch = current;
          ref.invalidate(chatMessagesProvider);
          unawaited(_hydrateInboxPreviews(state.value ?? const []));
        }
      }

      ordinary.addListener(onKeysChanged);
      ref.onDispose(() => ordinary.removeListener(onKeysChanged));
      unawaited(ordinary.open().catchError((Object _) {}));
    }
    // A mute toggled anywhere in the app lands in the hub. From there it goes
    // to the server, so every device of the account follows. Only a change
    // between two loaded sets counts: a reload belongs to another account.
    ref.listen(chatMuteHubProvider, (
      AsyncValue<Set<int>>? previous,
      AsyncValue<Set<int>> next,
    ) {
      if (!_valid(generation)) return;
      if (previous == null || previous.isLoading || next.isLoading) return;
      final Set<int>? before = previous.value;
      final Set<int>? after = next.value;
      if (before == null || after == null) return;
      _queueMuteUploads(before, after);
    });
    final productivitySubscription = ref
        .read(webSocketClientProvider)
        .pushStream
        .listen((event) {
          if (!_valid(generation)) return;
          final data = event['payload'];
          if (event['action'] == 'productivity_changed' &&
              data is Map &&
              data['chat_id'] != null) {
            unawaited(refresh());
          }
          // Pin, archive, mute or manual unread changed on another device.
          if (event['action'] == 'chat_state_changed' && data is Map) {
            final dynamic rows = data['chats'];
            if (rows is List) {
              applyChatStates(<Map<String, dynamic>>[
                for (final Map<dynamic, dynamic> row in rows.whereType<Map>())
                  row.map(
                    (dynamic key, dynamic value) =>
                        MapEntry<String, dynamic>(key.toString(), value),
                  ),
              ]);
            }
          }
          if (event['action'] == 'chat_reminder_due' && data is Map) {
            final notification = <String, dynamic>{
              'event_id': 'reminder:${data['id']}',
              'account_id': identity.$1,
              'type': 'reminder',
              'chat_id': data['chat_id'],
              'message_id': data['message_id'],
              'title': 'Напоминание',
              'body': 'Время вернуться к сообщению',
              'created_at': DateTime.now().toUtc().toIso8601String(),
            };
            unawaited(
              ref.read(notificationsProvider.notifier).accept(notification),
            );
            if (!PushNotificationService.isForeground) {
              unawaited(
                PushNotificationService.showLocalNotification(notification),
              );
            }
          }
        });
    ref.onDispose(() => unawaited(productivitySubscription.cancel()));
    ref.read(webSocketDispatcherProvider);
    WebSocketPushDispatcher.registerGlobal(_handlePushEvent);
    final connected = ref.read(webSocketClientProvider).onConnected.listen((_) {
      if (_valid(generation)) {
        unawaited(refresh());
      }
    });
    ref.onDispose(() {
      unawaited(connected.cancel());
      WebSocketPushDispatcher.unregisterGlobal();
      // Riverpod forbids provider reads inside dispose, so the pending
      // snapshot is written from the fields captured when it was queued. The
      // guard keeps a snapshot from leaking into another account's cache: it is
      // only written when it belongs to the identity this notifier was built
      // for. Rebuilds (invalidate) and account switches both land here, and
      // `build()` runs after dispose, so this is the only place that can flush.
      final int? accountId = _identity.$1;
      if (accountId != null) _flushPendingChats(onlyAccountId: accountId);
    });

    // Cached ordinary chats go on screen before anything is awaited. Secret
    // rows take their ids and previews from the secret store, which opens its
    // boxes and secure storage first, so they join once it is ready.
    List<ApiChatSummary> cached = const <ApiChatSummary>[];
    try {
      cached = ref
          .read(cacheServiceProvider)
          .getCachedChats(accountId: identity.$1);
      final List<ApiChatSummary> plain = cached
          .where((ApiChatSummary c) => !c.isSecret)
          .toList(growable: false);
      if (plain.isNotEmpty) state = AsyncData<List<ApiChatSummary>>(plain);
    } catch (e) {
      debugPrint('[backend_chat_provider.dart] Cache load error: $e');
    }

    final secret = await ref.read(secretChatCoordinatorProvider.future);
    if (!_valid(generation)) return const [];
    if (secret != null) {
      final subscription = secret.engine.changes.listen((_) {
        if (!_valid(generation)) return;
        state = AsyncData(
          secret.mergeChats(state.value ?? const <ApiChatSummary>[]),
        );
      });
      ref.onDispose(() => unawaited(subscription.cancel()));
      final local = secret.mergeChats(
        state.value ?? const <ApiChatSummary>[],
      );
      if (local.isNotEmpty) state = AsyncData(local);
    }

    if (cached.isNotEmpty) {
      try {
        if (secret != null) await secret.importChats(cached);
        if (!_valid(generation)) return const [];
        if (cached.any((ApiChatSummary c) => c.isSecret && !c.keyMismatch)) {
          // Ordinary rows are taken from the live state: a push may have
          // updated them since they were published above.
          final List<ApiChatSummary> rows = <ApiChatSummary>[
            ...(state.value ?? const <ApiChatSummary>[]).where(
              (ApiChatSummary c) => !c.isSecret,
            ),
            ...cached.where(
              (ApiChatSummary c) => c.isSecret && !c.keyMismatch,
            ),
          ];
          state = AsyncData<List<ApiChatSummary>>(
            (secret?.mergeChats(rows) ?? (rows..sort(compareChatRecency)))
                .where((ApiChatSummary c) => !(c.isSecret && c.keyMismatch))
                .toList(growable: false),
          );
        }
        unawaited(_hydrateInboxPreviews(cached));
      } catch (e) {
        debugPrint('[backend_chat_provider.dart] Cache load error: $e');
      }
    }

    final mesh = ref.read(bluetoothMeshProvider);
    if (mesh != null) {
      final seen = <String>{};
      final sub = mesh.changes.listen((chatId) {
        if (!_valid(generation)) return;
        for (final m in mesh.messages(chatId)) {
          if (!seen.add(m.operationId)) continue;
          if (seen.length > 512) seen.remove(seen.first);
          handleNewMessagePush(m.asApi(ownId: mesh.userId, senderName: ''));
        }
      });
      ref.onDispose(() => unawaited(sub.cancel()));
      unawaited(mesh.replay());
    }
    try {
      return await _fetch();
    } catch (_) {
      if (state.value?.isNotEmpty == true) return state.value!;
      rethrow;
    }
  }

  void _handlePushEvent(ChatPushEvent event) {
    if (!_valid(_generation)) return;
    switch (event.kind) {
      case ChatPushEventKind.newMessage:
        handleNewMessagePush(event.message);
      case ChatPushEventKind.edited:
        handleEditedPush(event.message);
      case ChatPushEventKind.deleted:
        handleDeletedPush(event.message);
      case ChatPushEventKind.reaction:
        _handleReactionPush(
          event.message,
          event.reactionEmoji ?? '',
          added: event.reactionAdded,
        );
      case ChatPushEventKind.read:
        handleReadPush(event.message.chatId, event.userId ?? 0);
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

  void handleReadPush(int chatId, int userId) {
    final List<ApiChatSummary>? currentChats = state.value;
    if (currentChats == null) return;

    final int index = currentChats.indexWhere(
      (ApiChatSummary c) => c.id == chatId,
    );
    if (index == -1) return;
    final ApiChatSummary chat = currentChats[index];

    final int myUserId = ref.read(authProvider).session?.userId ?? -1;

    if (userId == myUserId) {
      // Current user read the chat: topic children are read as well, otherwise
      // the aggregated group badge would keep showing the old counters.
      final Map<int, int> zeros = <int, int>{
        for (final ApiChatSummary c in currentChats)
          if ((c.id == chatId || c.topicParentId == chatId) &&
              c.unreadCount != 0)
            c.id: 0,
      };
      if (zeros.isNotEmpty) _writeUnread(zeros);
      // The server takes a manual unread mark back together with the counter.
      _rewriteChats(
        <int>{chatId},
        (ApiChatSummary c) =>
            c.markedUnread ? c.copyWith(markedUnread: false) : c,
      );
    } else {
      // Peer read the chat: mark our last message as read
      if (chat.lastMessage != null &&
          chat.lastMessage!.senderId == myUserId &&
          !chat.lastMessage!.isRead) {
        final List<ApiChatSummary> updated = List<ApiChatSummary>.from(
          currentChats,
        );
        updated[index] = chat.copyWith(
          lastMessage: chat.lastMessage!.copyWith(isRead: true),
        );
        state = AsyncData<List<ApiChatSummary>>(updated);
        _persistChats(updated);
      }
    }
  }

  /// Writes absolute unread counters and remembers when they were touched so a
  /// concurrent `list_chats` response does not resurrect an older value.
  void _writeUnread(Map<int, int> values) {
    final List<ApiChatSummary>? current = state.value;
    if (current == null) return;
    final List<ApiChatSummary> updated = List<ApiChatSummary>.from(current);
    final List<int> changed = <int>[];
    final List<int> lowered = <int>[];
    for (int i = 0; i < updated.length; i++) {
      final int? value = values[updated[i].id];
      if (value == null || value == updated[i].unreadCount) continue;
      if (value < updated[i].unreadCount) lowered.add(updated[i].id);
      updated[i] = updated[i].copyWith(unreadCount: value);
      changed.add(updated[i].id);
    }
    if (changed.isEmpty) return;
    final DateTime now = DateTime.now();
    for (final int id in changed) {
      _unreadTouchedAt[id] = now;
    }
    for (final int id in lowered) {
      _unreadLoweredAt[id] = now;
    }
    state = AsyncData<List<ApiChatSummary>>(updated);
    _persistChats(updated);
  }

  void handleDeletedPush(ApiMessage message) {
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

    // The dispatcher does not forward event ids, so the same push delivered
    // twice is recognised by its signature within a short window instead of
    // being applied twice.
    final String eventKey =
        '${message.chatId}:${message.id}:$emoji:${added ? 1 : 0}';
    final DateTime now = DateTime.now();
    final DateTime? appliedAt = _recentReactions[eventKey];
    if (appliedAt != null &&
        now.difference(appliedAt) < const Duration(seconds: 2)) {
      return;
    }
    _recentReactions[eventKey] = now;
    if (_recentReactions.length > 256) {
      _recentReactions.removeWhere(
        (_, DateTime time) => now.difference(time) > const Duration(seconds: 10),
      );
    }

    final Map<String, int> reactions;
    if (message.reactions.isNotEmpty) {
      // An authoritative aggregate beats local arithmetic: a missed push can no
      // longer desynchronise the counter forever.
      reactions = Map<String, int>.from(message.reactions);
    } else {
      reactions = Map<String, int>.from(chat.lastMessage!.reactions);
      final int count = (reactions[emoji] ?? 0) + (added ? 1 : -1);
      if (count > 0) {
        reactions[emoji] = count;
      } else {
        reactions.remove(emoji);
      }
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

  void handleEditedPush(ApiMessage message) {
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
      lastMessage: _newestLastMessage(chat.lastMessage, message),
    );
    state = AsyncData<List<ApiChatSummary>>(updated);
    _persistChats(updated);
    if (!message.isDecrypted &&
        message.e2eeContent != null &&
        OrdinaryCodec.recognises(message.e2eeContent!)) {
      unawaited(_decryptInboxPreview(message));
    }
  }

  void handleNewMessagePush(ApiMessage message) {
    final ordinary =
        message.e2eeContent != null &&
        OrdinaryCodec.recognises(message.e2eeContent!);
    if (ordinary && !message.isDecrypted) {
      _applyNewMessagePush(message, notify: false);
      unawaited(_decryptInboxPreview(message, notify: true));
    } else {
      _applyNewMessagePush(message);
    }
  }

  Future<void> _decryptInboxPreview(
    ApiMessage message, {
    bool notify = false,
  }) async {
    final account = ref.read(authProvider).session?.userId;
    final key = '${message.chatId}:${message.id}:${message.editedAt}';
    if (!_previewDecryptions.add(key)) return;
    try {
      final decoded =
          await ref.read(ordinaryE2eeProvider)?.decrypt(message) ?? message;
      if (!ref.mounted || account != ref.read(authProvider).session?.userId) {
        return;
      }
      handleEditedPush(decoded);
      if (notify && decoded.senderId != account) {
        final chat = state.value
            ?.where((c) => c.id == message.chatId)
            .firstOrNull;
        final open =
            PushNotificationService.isForeground &&
            PushNotificationService.currentChatId == message.chatId;
        _notifyMessage(decoded, chat: chat, present: !open);
      }
    } finally {
      _previewDecryptions.remove(key);
    }
  }

  Future<void> _hydrateInboxPreviews(List<ApiChatSummary> chats) async {
    final generation = _generation;
    final account = ref.read(authProvider).session?.userId;
    for (var offset = 0; offset < chats.length; offset += 4) {
      if (!_valid(generation) ||
          account != ref.read(authProvider).session?.userId) {
        return;
      }
      await Future.wait(
        chats
            .skip(offset)
            .take(4)
            .where(
              (c) =>
                  !c.isSecret &&
                  c.lastMessage?.e2eeContent != null &&
                  !c.lastMessage!.isDecrypted &&
                  OrdinaryCodec.recognises(c.lastMessage!.e2eeContent!),
            )
            .map((c) => _decryptInboxPreview(c.lastMessage!)),
      );
    }
  }

  /// True only when the user is actually looking at the newest messages of
  /// [chatId]. A kept-alive route or a chat scrolled into the history is not
  /// proof of reading, so read receipts and counter resets stay suppressed.
  bool _isViewingLatest(int chatId) {
    if (!PushNotificationService.isForeground) return false;
    if (PushNotificationService.currentChatId != chatId) return false;
    // Reading the history notifier would build the whole conversation for a
    // chat that may never have been opened, so it is only consulted when it is
    // already alive (i.e. the screen is mounted).
    if (!ref.exists(chatMessagesProvider(chatId))) return true;
    return ref.read(chatMessagesProvider(chatId).notifier).followingLatest;
  }

  /// Stable identity of a message inside its chat, used to fold a message into
  /// the counters at most once. Mesh messages carry a session-stable client id
  /// (`mesh:<operation>`), server messages are identified by id.
  String? _messageKey(ApiMessage message) {
    if (message.id > 0) return '${message.chatId}:${message.id}';
    final String clientId = message.clientMessageId ?? '';
    if (clientId.isEmpty) return null;
    return '${message.chatId}:$clientId';
  }

  void _rememberMessage(String? key) {
    if (key == null) return;
    while (_seenMessages.length > 4096) {
      _seenMessages.remove(_seenMessages.first);
    }
  }

  /// Keeps the newer of two summaries' last messages. A server acknowledgement
  /// always replaces the optimistic placeholder; otherwise an older edit or a
  /// replay cannot move the preview backwards.
  static ApiMessage? _newestLastMessage(ApiMessage? current, ApiMessage? next) {
    if (current == null) return next;
    if (next == null) return current;
    if (current.id == next.id) return next;
    if (current.id < 0 && next.id > 0) return next;
    if (next.id < 0 && current.id > 0) return current;
    return next.sentAt.isBefore(current.sentAt) ? current : next;
  }

  void _applyNewMessagePush(ApiMessage message, {bool notify = true}) {
    // A list that is still loading counts as empty: the message then asks for
    // a fresh list instead of being dropped before the first response.
    final List<ApiChatSummary> currentChats =
        state.value ?? const <ApiChatSummary>[];

    final int index = currentChats.indexWhere(
      (ApiChatSummary c) => c.id == message.chatId,
    );
    final int myUserId = ref.read(authProvider).session?.userId ?? -1;
    final bool isCurrentChatOpen = _isViewingLatest(message.chatId);

    final String? key = _messageKey(message);
    // A replayed mesh operation or a re-delivered push must not bump the badge
    // again; the counter is kept as-is instead of incremented.
    final String? operation = meshOperation(message);
    final bool operationDuplicate =
        operation != null && !_seenOperations.add(operation);
    while (_seenOperations.length > 4096) {
      _seenOperations.remove(_seenOperations.first);
    }
    final bool duplicate =
        (key != null && !_seenMessages.add(key)) || operationDuplicate;
    _rememberMessage(key);

    if (index != -1) {
      final List<ApiChatSummary> updated = List<ApiChatSummary>.from(
        currentChats,
      );
      final ApiChatSummary chat = updated[index];

      final int newUnreadCount;
      if (message.senderId == myUserId) {
        newUnreadCount = isCurrentChatOpen ? 0 : chat.unreadCount;
      } else if (isCurrentChatOpen) {
        newUnreadCount = 0;
      } else if (duplicate) {
        newUnreadCount = chat.unreadCount;
      } else {
        newUnreadCount = chat.unreadCount + 1;
      }

      updated[index] = chat.copyWith(
        lastMessage: _newestLastMessage(chat.lastMessage, message),
        unreadCount: newUnreadCount,
      );

      // Same rule as the server: a message from someone else returns an
      // archived chat to the inbox unless its notifications are muted. A
      // message in a topic returns the group.
      if (message.senderId != myUserId) {
        final int rootId = chat.topicParentId ?? chat.id;
        final int rootIndex = rootId == chat.id
            ? index
            : updated.indexWhere((ApiChatSummary c) => c.id == rootId);
        if (rootIndex != -1 &&
            updated[rootIndex].isArchived &&
            updated[rootIndex].notificationsMuted != true) {
          updated[rootIndex] = updated[rootIndex].copyWith(isArchived: false);
        }
      }

      if (newUnreadCount != chat.unreadCount) {
        final DateTime now = DateTime.now();
        _unreadTouchedAt[chat.id] = now;
        if (newUnreadCount < chat.unreadCount) _unreadLoweredAt[chat.id] = now;
      }

      // Keep the inbox ordered by activity: a chat that just received a
      // message belongs to the top, secret and server chats alike.
      updated.sort(compareChatRecency);

      state = AsyncData<List<ApiChatSummary>>(updated);
      _persistChats(updated);
      if (duplicate) return;

      if (message.senderId != myUserId && isCurrentChatOpen) {
        // Chat is currently open: automatically mark read on backend in real time
        unawaited(ref.read(chatRepositoryProvider).markRead(message.chatId));
      }

      if (notify && message.senderId != myUserId) {
        _notifyMessage(message, chat: chat, present: !isCurrentChatOpen);
      }
    } else {
      unawaited(refresh());
      if (notify && message.senderId != myUserId && !duplicate) {
        _notifyMessage(message, present: !isCurrentChatOpen);
      }
    }
  }

  void _notifyMessage(
    ApiMessage message, {
    ApiChatSummary? chat,
    bool present = true,
  }) {
    final encrypted =
        chat?.isSecret == true ||
        ((message.e2eeContent != null || message.isE2ee) &&
            !OrdinaryCodec.recognises(message.e2eeContent ?? ''));
    final locale = ref
        .read(uiSettingsProvider)
        .effectiveLocaleCode(PlatformDispatcher.instance.locale.languageCode);
    final strings = lookupAppLocalizations(Locale(locale));
    final sender = message.senderDisplayName.isNotEmpty
        ? message.senderDisplayName
        : message.senderUsername;
    final title = chat?.name.isNotEmpty == true
        ? chat!.name
        : sender.isNotEmpty
        ? sender
        : 'NiosMess';
    final text = encrypted
        ? strings.noticeEncrypted
        : (message.isE2ee && !message.isDecrypted)
        ? strings.noticeNewMessage
        : message.content.isNotEmpty
        ? (LiveLocation.parse(message.content)?.preview ?? InteractiveMessage.parse(message.content)?.preview ??
              message.content)
        : strings.noticeAttachment;
    final notification = <String, dynamic>{
      'event_id': 'message:${message.chatId}:${message.id}',
      'type': 'new_message',
      'chat_id': message.chatId,
      'message_id': message.id,
      'title': title,
      'body': sender.isNotEmpty && sender != title && !encrypted
          ? '$sender: $text'
          : text,
      'avatar_url': chat?.avatarUrl ?? message.senderAvatarUrl,
      'created_at': message.sentAt.toIso8601String(),
      'is_secret': encrypted ? 'true' : 'false',
    };
    unawaited(
      ref
          .read(notificationsProvider.notifier)
          .accept(notification, present: present),
    );
    // No direct `showLocalNotification` here: it bypassed the mute/preference
    // checks in notificationsProvider, which is the single delivery path.
  }

  /// Reconciles a freshly fetched server snapshot with the pushes applied
  /// while the request was in flight, so a slow `list_chats` can never roll the
  /// inbox back. Returns `null` when a newer snapshot already won the race.
  List<ApiChatSummary>? _adoptSnapshot(
    List<ApiChatSummary> fetched,
    int seq,
    DateTime requestedAt,
  ) {
    if (seq < _appliedSnapshotSeq) return null;
    _appliedSnapshotSeq = seq;
    final Map<int, ApiChatSummary> known = <int, ApiChatSummary>{
      for (final ApiChatSummary chat in state.value ?? const <ApiChatSummary>[])
        chat.id: chat,
    };
    // The server owns chat membership: locally known chats that a snapshot no
    // longer contains were deleted or left, so they are dropped here. Pushed
    // chats are covered because a push for an unknown chat triggers `refresh`.
    return <ApiChatSummary>[
      for (final ApiChatSummary remote in fetched)
        if (!(remote.isSecret && remote.keyMismatch))
          known[remote.id] == null
              ? remote
              : _mergeChatSummary(known[remote.id]!, remote, requestedAt),
    ]..sort(compareChatRecency);
  }

  /// Field-wise merge of a local summary with a server one.
  ///
  /// "Non-empty wins" for descriptive fields (a partial summary must not erase a
  /// known name/key/avatar), the newest last message wins, and an unread counter
  /// that was mutated locally after the request started is never lowered.
  /// [requestedAt] is the moment the `list_chats` request was sent; `null` means
  /// "local counters are always at least as fresh as the incoming summary".
  ApiChatSummary _mergeChatSummary(
    ApiChatSummary known,
    ApiChatSummary incoming,
    DateTime? requestedAt,
  ) {
    final DateTime? touched = _unreadTouchedAt[incoming.id];
    final bool recentLocalWrite =
        requestedAt != null &&
        touched != null &&
        !touched.isBefore(requestedAt);
    final DateTime? lowered = _unreadLoweredAt[incoming.id];
    final bool recentLocalRead =
        requestedAt != null &&
        lowered != null &&
        !lowered.isBefore(requestedAt);
    final int unreadCount;
    if (requestedAt == null) {
      // A summary that arrives while an explicit read is still pending must not
      // bring the badge back.
      unreadCount = _readResets.containsKey(incoming.id)
          ? known.unreadCount
          : (known.unreadCount > incoming.unreadCount
                ? known.unreadCount
                : incoming.unreadCount);
    } else if (recentLocalRead) {
      // An explicit read happened after the request was sent: the snapshot still
      // carries the old counter and must not resurrect the badge.
      unreadCount = known.unreadCount;
    } else if (recentLocalWrite) {
      unreadCount = known.unreadCount > incoming.unreadCount
          ? known.unreadCount
          : incoming.unreadCount;
    } else {
      unreadCount = incoming.unreadCount;
    }
    final ApiChatSummary merged = incoming.copyWith(
      name: incoming.name.trim().isEmpty ? known.name : null,
      username: _isBlank(incoming.username) ? known.username : null,
      avatarUrl: _isBlank(incoming.avatarUrl) ? known.avatarUrl : null,
      description: incoming.description.trim().isEmpty
          ? known.description
          : null,
      partnerBadges: incoming.partnerBadges.isEmpty
          ? known.partnerBadges
          : null,
      partnerPublicKey: _isBlank(incoming.partnerPublicKey)
          ? known.partnerPublicKey
          : null,
      partnerStatusEmoji: incoming.partnerStatusEmoji == null
          ? known.partnerStatusEmoji
          : null,
      partnerUserId: incoming.partnerUserId == null
          ? known.partnerUserId
          : null,
      autoDeleteSeconds: incoming.autoDeleteSeconds == null
          ? known.autoDeleteSeconds
          : null,
      lastMessage: _newestLastMessage(known.lastMessage, incoming.lastMessage),
      unreadCount: unreadCount,
      isOnline: known.isOnline,
      // A device-bound key mismatch is a safety signal: it stays sticky until a
      // rebind clears it on both sides.
      keyMismatch: known.keyMismatch || incoming.keyMismatch,
    );
    // A pointwise summary without the inbox state says nothing about it: what
    // is known stays. A full snapshot is the server's word either way.
    if (requestedAt != null || incoming.notificationsMuted != null) {
      return merged;
    }
    return merged.copyWith(
      pinnedAt: known.pinnedAt,
      clearPin: known.pinnedAt == null,
      isArchived: known.isArchived,
      markedUnread: known.markedUnread,
      notificationsMuted: known.notificationsMuted,
    );
  }

  static bool _isBlank(String? value) => value == null || value.trim().isEmpty;

  Future<List<ApiChatSummary>> _fetch({bool allowStale = true}) async {
    final generation = _generation;
    final int seq = ++_refreshSeq;
    final DateTime requestedAt = DateTime.now();
    try {
      final secret = await ref.read(secretChatCoordinatorProvider.future);
      if (!_valid(generation)) return const [];
      if (secret != null) await secret.register();
      if (!_valid(generation)) return const [];
      final remote = await ref
          .read(chatRepositoryProvider)
          .listChats(publicKey: secret?.engine.publicKey);
      if (!_valid(generation)) return const [];
      if (secret != null) await secret.importChats(remote);
      if (!_valid(generation)) return const [];
      final List<ApiChatSummary> chats = (secret?.mergeChats(remote) ?? remote)
          .where((ApiChatSummary c) => !(c.isSecret && c.keyMismatch))
          .toList(growable: false);
      ref.read(bluetoothMeshProvider)?.warmChats(chats);
      final List<ApiChatSummary>? merged = _adoptSnapshot(chats, seq, requestedAt);
      if (merged == null) {
        // A newer request already published a fresher snapshot.
        return state.value ?? const [];
      }
      // Publish synchronously with the merge: any await here would reopen the
      // window for a push to be overwritten by the older snapshot.
      state = AsyncData<List<ApiChatSummary>>(merged);
      // Cache mirrors the final state, never the raw response.
      _persistChats(merged);
      unawaited(_adoptServerMutes(merged, generation));
      // Hydrate presentation after publishing; never block the inbox on
      // key/network repair.
      final previewAccount = ref.read(authProvider).session?.userId;
      Timer.run(() {
        if (_valid(generation) &&
            previewAccount == ref.read(authProvider).session?.userId) {
          unawaited(_hydrateInboxPreviews(merged));
        }
      });
      return merged;
    } catch (e) {
      if (!_valid(generation)) return const [];
      final List<ApiChatSummary>? currentData = state.value;
      if (allowStale && currentData != null && currentData.isNotEmpty) {
        return currentData;
      }
      rethrow;
    }
  }

  Future<void> refreshOrThrow() async {
    final generation = _generation;
    try {
      // `_fetch` publishes the merged snapshot itself.
      await _fetch(allowStale: false);
      if (!_valid(generation)) return;
    } catch (error, stack) {
      if (!_valid(generation)) return;
      if (state.value == null || state.value!.isEmpty) {
        state = AsyncError(error, stack);
      }
      rethrow;
    }
  }

  Future<void> refresh() async {
    final generation = _generation;
    final bool authenticated = ref.read(authProvider).isAuthenticated;
    if (!authenticated) {
      state = const AsyncData<List<ApiChatSummary>>(<ApiChatSummary>[]);
      return;
    }

    try {
      // `_fetch` merges with concurrent pushes and publishes the result.
      await _fetch();
      if (!_valid(generation)) return;
    } catch (e) {
      if (!_valid(generation)) return;
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
    if (idx != -1) {
      final List<ApiChatSummary> updated = List<ApiChatSummary>.from(current);
      // A partial summary must not wipe the known preview/unread state; the
      // position follows the recency comparator instead of jumping to the top.
      updated[idx] = _mergeChatSummary(updated[idx], chat, null);
      updated.sort(compareChatRecency);
      state = AsyncData<List<ApiChatSummary>>(updated);
      _persistChats(updated);
      return;
    }
    final List<ApiChatSummary> updated = List<ApiChatSummary>.from(current);
    insertSorted(updated, chat, compareChatRecency);
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

  /// Optimistically clears the badge of [chatId] (and of its topic children,
  /// which the aggregated tile badge includes). The server call is owned by
  /// [ChatMessagesNotifier.markRead]; if it fails or cannot run it calls
  /// [rollbackChatRead], so the badge never disappears for good without the
  /// server agreeing.
  void markChatAsRead(int chatId) {
    final List<ApiChatSummary>? current = state.value;
    if (current == null) return;
    final Map<int, int> zeros = <int, int>{};
    final Map<int, int> snapshot = <int, int>{};
    for (final ApiChatSummary chat in current) {
      if (chat.id != chatId && chat.topicParentId != chatId) continue;
      if (chat.unreadCount == 0) continue;
      zeros[chat.id] = 0;
      snapshot[chat.id] = chat.unreadCount;
    }
    if (zeros.isEmpty) return;
    // The first snapshot wins: a repeated mark-read must still restore the
    // counters the user actually saw before the optimistic reset.
    _readResets.putIfAbsent(chatId, () => snapshot);
    _writeUnread(zeros);
  }

  /// Drops the rollback snapshot once the server confirmed the read.
  void confirmChatRead(int chatId) {
    _readResets.remove(chatId);
  }

  /// Restores the counters captured by [markChatAsRead]. Never lowers a value
  /// that grew in the meantime (a new message read is still unread).
  void rollbackChatRead(int chatId) {
    final Map<int, int>? snapshot = _readResets.remove(chatId);
    if (snapshot == null) return;
    final List<ApiChatSummary>? current = state.value;
    if (current == null) return;
    final Map<int, int> restore = <int, int>{};
    for (final ApiChatSummary chat in current) {
      final int? previous = snapshot[chat.id];
      if (previous == null || chat.unreadCount >= previous) continue;
      restore[chat.id] = previous;
    }
    if (restore.isNotEmpty) _writeUnread(restore);
  }

  /// True when a local mark-read reset is waiting for its server confirmation.
  bool hasPendingReadReset(int chatId) => _readResets.containsKey(chatId);

  /// Marks [chatId] read straight from the inbox: the badge clears at once and
  /// a single `mark_read` request goes out. Unlike
  /// [ChatMessagesNotifier.markRead] it does not build the chat's message
  /// provider, so a swipe never loads a conversation history. Secret chats
  /// need their engine and stay on the message-provider path.
  Future<void> markReadFromInbox(int chatId) async {
    // Same rule as the message provider: a backgrounded app must not cancel
    // the system push as already read.
    if (!PushNotificationService.isForeground) {
      throw StateError('READ_RECEIPT_UNAVAILABLE: app is in background');
    }
    final int generation = _generation;
    markChatAsRead(chatId);
    try {
      await ref.read(chatRepositoryProvider).markRead(chatId);
    } catch (_) {
      if (_valid(generation)) rollbackChatRead(chatId);
      rethrow;
    }
    if (!_valid(generation)) return;
    confirmChatRead(chatId);
    // The server takes a manual unread mark back together with the counter.
    _rewriteChats(
      <int>{chatId},
      (ApiChatSummary chat) =>
          chat.markedUnread ? chat.copyWith(markedUnread: false) : chat,
    );
  }

  /// Server id of [chat]: a secret conversation is listed under its local id.
  int _remoteId(ApiChatSummary chat) {
    if (!chat.isSecret) return chat.id;
    return ref.read(secretChatEngineProvider)?.chat(chat.id)['remote_id']
            as int? ??
        chat.id;
  }

  /// Rewrites the summaries of [ids] and, when one of them changed, publishes
  /// the list again in inbox order.
  void _rewriteChats(
    Set<int> ids,
    ApiChatSummary Function(ApiChatSummary chat) rewrite,
  ) {
    final List<ApiChatSummary>? current = state.value;
    if (current == null) return;
    bool changed = false;
    final List<ApiChatSummary> updated = <ApiChatSummary>[];
    for (final ApiChatSummary chat in current) {
      final ApiChatSummary next = ids.contains(chat.id) ? rewrite(chat) : chat;
      if (!identical(next, chat)) changed = true;
      updated.add(next);
    }
    if (!changed) return;
    updated.sort(compareChatRecency);
    state = AsyncData<List<ApiChatSummary>>(updated);
    _persistChats(updated);
  }

  /// Pins, archives or marks [chats] unread for the whole account. Only the
  /// flags that are passed change. Chats that keep no such state (topics,
  /// «Избранное», a server without it) are skipped. The list follows the
  /// server's answer, so a refused request changes nothing on screen.
  Future<void> setInboxState(
    Iterable<ApiChatSummary> chats, {
    bool? pinned,
    bool? archived,
    bool? unread,
  }) async {
    final int generation = _generation;
    final List<ApiChatSummary> targets = <ApiChatSummary>[
      for (final ApiChatSummary chat in chats)
        if (chat.hasInboxState) chat,
    ];
    if (targets.isEmpty) return;
    if (pinned == true) {
      final Set<int> ids = <int>{
        for (final ApiChatSummary chat in targets) chat.id,
      };
      final int others = (state.value ?? const <ApiChatSummary>[])
          .where((ApiChatSummary c) => c.isPinned && !ids.contains(c.id))
          .length;
      if (others + targets.length > kMaxPinnedChats) {
        throw const ChatPinLimitException();
      }
    }
    final List<int> remoteIds = <int>[
      for (final ApiChatSummary chat in targets) _remoteId(chat),
    ];
    for (int start = 0; start < remoteIds.length; start += _stateBatch) {
      final List<Map<String, dynamic>> rows = await ref
          .read(chatRepositoryProvider)
          .setChatState(
            remoteIds.skip(start).take(_stateBatch).toList(growable: false),
            pinned: pinned,
            archived: archived,
            unread: unread,
          );
      if (!_valid(generation)) return;
      applyChatStates(rows);
    }
  }

  /// Applies inbox state rows stored by the server: the answer to
  /// `set_chat_state` or a `chat_state_changed` push from another device.
  /// Rows carry server chat ids.
  void applyChatStates(List<Map<String, dynamic>> rows) {
    final Map<int, Map<String, dynamic>> byRemoteId =
        <int, Map<String, dynamic>>{
          for (final Map<String, dynamic> row in rows)
            if (row['chat_id'] is num) (row['chat_id'] as num).toInt(): row,
        };
    final List<ApiChatSummary>? current = state.value;
    if (byRemoteId.isEmpty || current == null) return;
    final Map<int, Map<String, dynamic>> byId = <int, Map<String, dynamic>>{};
    for (final ApiChatSummary chat in current) {
      final Map<String, dynamic>? row = byRemoteId[_remoteId(chat)];
      if (row != null) byId[chat.id] = row;
    }
    if (byId.isEmpty) return;
    _rewriteChats(byId.keys.toSet(), (ApiChatSummary chat) {
      final Map<String, dynamic> row = byId[chat.id]!;
      final DateTime? pinnedAt = DateTime.tryParse(
        row['pinned_at']?.toString() ?? '',
      );
      final bool archived = row['is_archived'] == true;
      final bool unread = row['marked_unread'] == true;
      final bool muted = row['notifications_muted'] == true;
      if (chat.pinnedAt == pinnedAt &&
          chat.isArchived == archived &&
          chat.markedUnread == unread &&
          chat.notificationsMuted == muted) {
        return chat;
      }
      return chat.copyWith(
        pinnedAt: pinnedAt,
        clearPin: pinnedAt == null,
        isArchived: archived,
        markedUnread: unread,
        notificationsMuted: muted,
      );
    });
    // The summaries above already carry the server value, so the hub change
    // below is not sent back. A toggle still waiting to be uploaded wins.
    final Map<int, bool> mutes = <int, bool>{
      for (final MapEntry<int, Map<String, dynamic>> entry in byId.entries)
        if (!_muteUploads.containsKey(entry.key))
          entry.key: entry.value['notifications_muted'] == true,
    };
    if (mutes.isEmpty) return;
    unawaited(
      ref
          .read(chatMuteHubProvider.notifier)
          .applyServerMutes(mutes)
          .catchError((Object _) {}),
    );
  }

  /// Brings the device mute preference in line with a server snapshot, then
  /// sends what the server does not know yet.
  Future<void> _adoptServerMutes(
    List<ApiChatSummary> chats,
    int generation,
  ) async {
    final Map<int, bool> values = <int, bool>{
      for (final ApiChatSummary chat in chats)
        if (chat.hasInboxState && !_muteUploads.containsKey(chat.id))
          chat.id: chat.notificationsMuted == true,
    };
    if (values.isNotEmpty) {
      try {
        final Set<int> localOnly = await ref
            .read(chatMuteHubProvider.notifier)
            .adoptServerMutes(values);
        if (!_valid(generation)) return;
        for (final int id in localOnly) {
          _muteUploads.putIfAbsent(id, () => true);
        }
      } catch (_) {
        debugPrint('[backend_chat_provider.dart] Mute adoption failed');
      }
    }
    if (_valid(generation) && _muteUploads.isNotEmpty) {
      unawaited(_uploadMutes());
    }
  }

  /// Queues the chats whose mute changed in the hub for upload. A change that
  /// only repeats what the server already stores is not sent.
  void _queueMuteUploads(Set<int> before, Set<int> after) {
    final Map<int, ApiChatSummary> known = <int, ApiChatSummary>{
      for (final ApiChatSummary chat in state.value ?? const <ApiChatSummary>[])
        chat.id: chat,
    };
    for (final int id in <int>{
      ...before.difference(after),
      ...after.difference(before),
    }) {
      final bool muted = after.contains(id);
      final ApiChatSummary? chat = known[id];
      if (chat == null ||
          !chat.hasInboxState ||
          chat.notificationsMuted == muted) {
        _muteUploads.remove(id);
      } else {
        _muteUploads[id] = muted;
      }
    }
    if (_muteUploads.isNotEmpty) unawaited(_uploadMutes());
  }

  /// Sends the queued mute toggles, one request per value. A failed request
  /// leaves its chats queued: the next snapshot (reconnect, refresh) sends
  /// them again.
  Future<void> _uploadMutes() async {
    if (_muteUploadRunning) return;
    _muteUploadRunning = true;
    final int generation = _generation;
    try {
      while (_muteUploads.isNotEmpty && _valid(generation)) {
        final bool muted = _muteUploads.values.first;
        final Map<int, ApiChatSummary> known = <int, ApiChatSummary>{
          for (final ApiChatSummary chat
              in state.value ?? const <ApiChatSummary>[])
            chat.id: chat,
        };
        // Chat id in the list -> server id.
        final Map<int, int> remoteIds = <int, int>{};
        for (final MapEntry<int, bool> entry
            in _muteUploads.entries.toList(growable: false)) {
          if (entry.value != muted) continue;
          final ApiChatSummary? chat = known[entry.key];
          if (chat == null ||
              !chat.hasInboxState ||
              chat.notificationsMuted == muted) {
            _muteUploads.remove(entry.key);
          } else if (remoteIds.length < _stateBatch) {
            remoteIds[entry.key] = _remoteId(chat);
          }
        }
        if (remoteIds.isEmpty) continue;
        final List<Map<String, dynamic>> rows;
        try {
          rows = await ref
              .read(chatRepositoryProvider)
              .setChatState(
                remoteIds.values.toList(growable: false),
                muted: muted,
              );
        } catch (_) {
          debugPrint('[backend_chat_provider.dart] Mute sync failed');
          return;
        }
        if (!_valid(generation)) return;
        for (final int id in remoteIds.keys) {
          if (_muteUploads[id] == muted) _muteUploads.remove(id);
        }
        applyChatStates(rows);
      }
    } finally {
      _muteUploadRunning = false;
    }
  }
}

/// Pinning would take the account over [kMaxPinnedChats] pinned chats.
class ChatPinLimitException implements Exception {
  const ChatPinLimitException();

  @override
  String toString() => 'ChatPinLimitException';
}

final AsyncNotifierProvider<ChatsNotifier, List<ApiChatSummary>> chatsProvider =
    AsyncNotifierProvider<ChatsNotifier, List<ApiChatSummary>>(
      ChatsNotifier.new,
    );

/// Watches a single summary. `select` narrows the subscription to the requested
/// chat, so presence/unread changes of other chats no longer rebuild every
/// family instance, and the scan stops as soon as the id is found.
final chatByIdProvider = Provider.family<ApiChatSummary?, int>((
  Ref ref,
  int chatId,
) {
  return ref.watch(
    chatsProvider.select((AsyncValue<List<ApiChatSummary>> value) {
      final List<ApiChatSummary>? chats = value.value;
      if (chats == null) return null;
      for (final ApiChatSummary chat in chats) {
        if (chat.id == chatId) return chat;
      }
      return null;
    }),
  );
});

/// Presence of one chat, for the dot on its inbox row.
///
/// Auto-disposable and narrowed to a bool: an online/offline push rebuilds the
/// one row that shows it, and a row that scrolls away releases its element.
final chatOnlineProvider = Provider.autoDispose.family<bool, int>((
  Ref ref,
  int chatId,
) {
  return ref.watch(
    chatsProvider.select((AsyncValue<List<ApiChatSummary>> value) {
      final List<ApiChatSummary>? chats = value.value;
      if (chats == null) return false;
      for (final ApiChatSummary chat in chats) {
        if (chat.id == chatId) return chat.isOnline;
      }
      return false;
    }),
  );
});

/// Unread messages the navigation badge counts: every chat whose
/// notifications are on and that is not archived. A muted chat (or a topic of
/// a muted group) keeps its own counter in the list but does not ask for
/// attention from every screen. A chat marked unread by hand counts as one.
final Provider<int> totalUnreadCountProvider = Provider<int>((Ref ref) {
  final List<ApiChatSummary>? chats = ref.watch(chatsProvider).value;
  if (chats == null) return 0;
  final Set<int> quiet = <int>{
    ...?ref.watch(chatMuteHubProvider).value,
    for (final ApiChatSummary chat in chats)
      if (chat.isArchived) chat.id,
  };
  int total = 0;
  for (final ApiChatSummary chat in chats) {
    if (!chat.hasUnread) continue;
    if (quiet.contains(chat.id) || quiet.contains(chat.topicParentId)) {
      continue;
    }
    total += chat.unreadCount > 0 ? chat.unreadCount : 1;
  }
  return total;
});
