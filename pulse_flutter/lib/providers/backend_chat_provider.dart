import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/core/storage/cache_service.dart';
import 'package:pulse_flutter/core/storage/encrypted_message_cache.dart';
import 'package:pulse_flutter/models/api/chat_member_model.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/badge_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/niosgram_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/services/e2ee_service.dart';

class ChatsNotifier extends AsyncNotifier<List<ApiChatSummary>> {
  @override
  Future<List<ApiChatSummary>> build() async {
    final bool authenticated = ref.watch(
      authProvider.select((AuthState state) => state.isAuthenticated),
    );

    if (!authenticated) {
      return const <ApiChatSummary>[];
    }

    final StreamSubscription<Map<String, dynamic>> subscription = ref
        .read(webSocketClientProvider)
        .pushStream
        .listen(_handlePushEvent);

    ref.onDispose(() {
      subscription.cancel();
    });

    // Load cache immediately
    try {
      final List<ApiChatSummary> chats = ref.read(cacheServiceProvider).getCachedChats();
      if (chats.isNotEmpty) {
        state = AsyncData<List<ApiChatSummary>>(chats);
      }
    } catch (e) {
      debugPrint('[backend_chat_provider.dart] Cache load error: $e');
    }

    return _fetch();
  }

  void _handlePushEvent(Map<String, dynamic> event) {
    final String? action = event['action'] as String?;
    if (action == 'new_message') {
      final dynamic payload = event['payload'];
      if (payload is Map<String, dynamic>) {
        try {
          final ApiMessage message = ApiMessage.fromJson(payload);
          _handleNewMessagePush(message);
        } catch (e) {
          debugPrint('[backend_chat_provider.dart] Error parsing message push: $e');
        }
      }
    }
  }

  void _handleNewMessagePush(ApiMessage message) {
    final List<ApiChatSummary>? currentChats = state.value;
    if (currentChats == null) return;

    final int index = currentChats.indexWhere((ApiChatSummary c) => c.id == message.chatId);
    if (index != -1) {
      final List<ApiChatSummary> updated = List<ApiChatSummary>.from(currentChats);
      final ApiChatSummary chat = updated[index];

      final int myUserId = ref.read(authProvider).session?.userId ?? -1;
      final int newUnreadCount = message.senderId != myUserId
          ? chat.unreadCount + 1
          : chat.unreadCount;

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
      ref.read(cacheServiceProvider).saveChats(updated);
    } else {
      refresh();
    }
  }

  Future<List<ApiChatSummary>> _fetch() async {
    try {
      String? publicKey;
      try {
        final E2eeService e2ee = E2eeService();
        publicKey = await e2ee.getPublicKeyBase64();
      } catch (_) {}
      final List<ApiChatSummary> chats = await ref.read(chatRepositoryProvider).listChats(publicKey: publicKey);
      // Save cache
      await ref.read(cacheServiceProvider).saveChats(chats);
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

class ChatMessagesNotifier extends AsyncNotifier<List<ApiMessage>> {
  ChatMessagesNotifier(this._chatId);

  final int _chatId;
  int _sendCounter = 0;

  @override
  Future<List<ApiMessage>> build() async {
    final bool authenticated = ref.watch(
      authProvider.select((AuthState state) => state.isAuthenticated),
    );

    if (!authenticated) {
      return const <ApiMessage>[];
    }

    final StreamSubscription<Map<String, dynamic>> subscription = ref
        .read(webSocketClientProvider)
        .pushStream
        .listen(_handlePushEvent);

    ref.onDispose(() {
      subscription.cancel();
    });

    // Load cache immediately
    try {
      final List<ApiMessage> cached = await EncryptedMessageCache.loadMessages(_chatId);
      if (cached.isNotEmpty) {
        state = AsyncData<List<ApiMessage>>(cached);
      }
    } catch (e) {
      debugPrint('[backend_chat_provider.dart] Messages cache load error: $e');
    }

    return _fetch();
  }

  void _handlePushEvent(Map<String, dynamic> event) {
    final String? action = event['action'] as String?;
    if (action == 'new_message') {
      final dynamic payload = event['payload'];
      if (payload is Map<String, dynamic>) {
        try {
          final ApiMessage message = ApiMessage.fromJson(payload);
          if (message.chatId == _chatId) {
            _handleNewIncomingMessage(message);
          }
        } catch (e) {
          debugPrint('[backend_chat_provider.dart] Message push parse error: $e');
        }
      }
    }
  }

  Future<void> _handleNewIncomingMessage(ApiMessage message) async {
    final List<ApiMessage> current = state.value ?? const <ApiMessage>[];

    if (current.any((ApiMessage m) => m.id == message.id)) {
      return;
    }

    final List<ApiMessage> next = List<ApiMessage>.from(current)..add(message);
    next.sort((ApiMessage a, ApiMessage b) => a.id.compareTo(b.id));

    state = AsyncData<List<ApiMessage>>(next);
    await _saveToCache(next);

    final int myUserId = ref.read(authProvider).session?.userId ?? -1;
    if (message.senderId != myUserId) {
      await _playNotificationSound();
    }
  }

  Future<List<ApiMessage>> _fetch() async {
    final List<ApiMessage> messages = await ref.read(chatRepositoryProvider).getHistory(_chatId, pageSize: 80);
    try {
      await EncryptedMessageCache.saveMessages(_chatId, messages);
    } catch (e) {
      debugPrint('[backend_chat_provider.dart] Save messages cache error: $e');
    }
    return messages;
  }

  Future<void> _saveToCache(List<ApiMessage> messages) async {
    try {
      await EncryptedMessageCache.saveMessages(_chatId, messages);
    } catch (e) {
      debugPrint('[backend_chat_provider.dart] Save messages cache error: $e');
    }
  }

  Future<void> _playNotificationSound({double volume = 0.9}) async {
    if (!ref.read(uiSettingsProvider).notifications) return;
    await ref.read(appSoundProvider).play(AppSound.message, volume: volume);
  }

  Future<void> refresh() async {
    final List<ApiMessage>? previous = state.value;
    final AsyncValue<List<ApiMessage>> next = await AsyncValue.guard(_fetch);
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
      await _playNotificationSound();
    }
  }

  Future<int> loadOlder({int pageSize = 50}) async {
    final List<ApiMessage> current = state.value ?? const <ApiMessage>[];
    if (current.isEmpty) {
      final List<ApiMessage> initial = await _fetch();
      state = AsyncData<List<ApiMessage>>(initial);
      return initial.length;
    }

    final int beforeId = current.first.id;
    final List<ApiMessage> older = await ref
        .read(chatRepositoryProvider)
        .getHistory(_chatId, pageSize: pageSize, beforeId: beforeId);

    if (older.isEmpty) {
      return 0;
    }

    final Set<int> seen = current.map((ApiMessage m) => m.id).toSet();
    final List<ApiMessage> merged = List<ApiMessage>.from(current);
    int added = 0;

    for (final ApiMessage message in older) {
      if (seen.add(message.id)) {
        merged.add(message);
        added++;
      }
    }

    merged.sort((ApiMessage a, ApiMessage b) => a.id.compareTo(b.id));
    state = AsyncData<List<ApiMessage>>(merged);
    await _saveToCache(merged);
    return added;
  }

  Future<void> markRead() async {
    try {
      await ref.read(chatRepositoryProvider).markRead(_chatId);
      await ref.read(chatsProvider.notifier).refresh();
    } catch (e) { debugPrint('[backend_chat_provider.dart] Error: $e'); }
  }

  Future<void> send(String content, {int? replyToId, String? uploadId}) async {
    final String trimmed = content.trim();
    if (trimmed.isEmpty && (uploadId == null || uploadId.trim().isEmpty)) {
      return;
    }

    final int tempId = -(DateTime.now().millisecondsSinceEpoch + _sendCounter++);
    final int myUserId = ref.read(authProvider).session?.userId ?? -1;
    final String myUsername = ref.read(authProvider).session?.username ?? '';

    final ApiMessage optimisticMessage = ApiMessage(
      id: tempId,
      chatId: _chatId,
      senderId: myUserId,
      senderUsername: myUsername,
      senderDisplayName: myUsername.isEmpty ? 'Я' : myUsername,
      senderBadges: const [],
      content: trimmed,
      msgType: uploadId != null ? 'media' : 'text',
      replyToId: replyToId,
      mediaUrl: null,
      mediaType: null,
      mediaName: null,
      mediaSize: null,
      mediaDuration: null,
      commentsCount: 0,
      reactions: const {},
      sentAt: DateTime.now(),
      editedAt: null,
      isDeleted: false,
      isSending: true,
      isFailed: false,
      isE2ee: false,
      e2eeContent: null,
    );

    List<ApiMessage> current = state.value ?? const <ApiMessage>[];
    List<ApiMessage> next = List<ApiMessage>.from(current)..add(optimisticMessage);
    next.sort((ApiMessage a, ApiMessage b) => a.id.compareTo(b.id));
    state = AsyncData<List<ApiMessage>>(next);

    try {
      final ApiMessage sent = await ref
          .read(chatRepositoryProvider)
          .sendMessage(
            _chatId,
            content: trimmed,
            replyToId: replyToId,
            uploadId: uploadId,
          );

      current = state.value ?? const <ApiMessage>[];
      next = List<ApiMessage>.from(current)
        ..removeWhere((ApiMessage message) => message.id == tempId)
        ..removeWhere((ApiMessage message) => message.id == sent.id)
        ..add(sent)
        ..sort((ApiMessage a, ApiMessage b) => a.id.compareTo(b.id));

      state = AsyncData<List<ApiMessage>>(next);
      await _saveToCache(next);
      await ref.read(chatsProvider.notifier).refresh();
      await _playNotificationSound(volume: 0.65);
    } catch (e) {
      current = state.value ?? const <ApiMessage>[];
      next = List<ApiMessage>.from(current);
      final int index = next.indexWhere((ApiMessage m) => m.id == tempId);
      if (index != -1) {
        final ApiMessage failedMsg = ApiMessage(
          id: optimisticMessage.id,
          chatId: optimisticMessage.chatId,
          senderId: optimisticMessage.senderId,
          senderUsername: optimisticMessage.senderUsername,
          senderDisplayName: optimisticMessage.senderDisplayName,
          senderBadges: optimisticMessage.senderBadges,
          content: optimisticMessage.content,
          msgType: optimisticMessage.msgType,
          replyToId: optimisticMessage.replyToId,
          mediaUrl: optimisticMessage.mediaUrl,
          mediaType: optimisticMessage.mediaType,
          mediaName: optimisticMessage.mediaName,
          mediaSize: optimisticMessage.mediaSize,
          mediaDuration: optimisticMessage.mediaDuration,
          commentsCount: optimisticMessage.commentsCount,
          reactions: optimisticMessage.reactions,
          sentAt: optimisticMessage.sentAt,
          editedAt: optimisticMessage.editedAt,
          isDeleted: optimisticMessage.isDeleted,
          isSending: false,
          isFailed: true,
          isE2ee: optimisticMessage.isE2ee,
          e2eeContent: optimisticMessage.e2eeContent,
        );
        next[index] = failedMsg;
        state = AsyncData<List<ApiMessage>>(next);
      }
    }
  }

  Future<void> editMessage(int messageId, String content) async {
    final String trimmed = content.trim();
    if (trimmed.isEmpty) return;

    final List<ApiMessage> current = state.value ?? const <ApiMessage>[];
    final ApiMessage? target = current.firstWhere(
      (ApiMessage m) => m.id == messageId,
      orElse: () => ApiMessage(
        id: 0, chatId: 0, senderId: 0, senderUsername: '', senderDisplayName: '',
        senderBadges: const <ApiBadge>[], content: '', msgType: 'text', replyToId: null,
        mediaUrl: null, mediaType: null, mediaName: null, mediaSize: null,
        mediaDuration: null, commentsCount: 0, reactions: <String, int>{},
        sentAt: DateTime.fromMillisecondsSinceEpoch(0), editedAt: null, isDeleted: false,
      ),
    );

    if (target == null || target.id == 0) return;

    final ApiMessage optimisticEdited = target.copyWith(
      content: trimmed,
      editedAt: DateTime.now(),
    );
    final List<ApiMessage> optimisticNext = List<ApiMessage>.from(current)
      ..removeWhere((ApiMessage m) => m.id == messageId)
      ..add(optimisticEdited)
      ..sort((ApiMessage a, ApiMessage b) => a.id.compareTo(b.id));
    state = AsyncData<List<ApiMessage>>(optimisticNext);

    try {
      final ApiMessage? edited = await ref
          .read(chatRepositoryProvider)
          .editMessage(_chatId, messageId, content: trimmed);

      if (edited != null) {
        final List<ApiMessage> confirmed = List<ApiMessage>.from(state.value ?? const <ApiMessage>[])
          ..removeWhere((ApiMessage m) => m.id == edited.id)
          ..add(edited)
          ..sort((ApiMessage a, ApiMessage b) => a.id.compareTo(b.id));
        state = AsyncData<List<ApiMessage>>(confirmed);
        await _saveToCache(confirmed);
      }
      await ref.read(chatsProvider.notifier).refresh();
    } catch (e) {
      state = AsyncData<List<ApiMessage>>(current);
    }
  }

  Future<void> deleteMessage(int messageId) async {
    final List<ApiMessage> current = state.value ?? const <ApiMessage>[];
    final List<ApiMessage> optimisticNext = List<ApiMessage>.from(current)
      ..removeWhere((ApiMessage m) => m.id == messageId);
    state = AsyncData<List<ApiMessage>>(optimisticNext);

    try {
      await ref.read(chatRepositoryProvider).deleteMessage(_chatId, messageId);
      await _saveToCache(optimisticNext);
      await ref.read(chatsProvider.notifier).refresh();
    } catch (e) {
      state = AsyncData<List<ApiMessage>>(current);
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
      await ref.read(chatRepositoryProvider).sendCallbackQuery(_chatId, messageId, data);
    } catch (e) {
      debugPrint('[backend_chat_provider.dart] sendCallbackQuery error: $e');
    }
  }

  Future<void> toggleReaction(int messageId, String emoji) async {
    if (emoji.trim().isEmpty) return;

    final List<ApiMessage> current = state.value ?? const <ApiMessage>[];

    final List<ApiMessage> optimisticNext = current.map((ApiMessage m) {
      if (m.id != messageId) return m;
      final Map<String, int> newReactions = Map<String, int>.from(m.reactions);
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
    }).toList(growable: false);
    state = AsyncData<List<ApiMessage>>(optimisticNext);

    try {
      await ref.read(chatRepositoryProvider).toggleReaction(_chatId, messageId, emoji: emoji);
      await _saveToCache(optimisticNext);
      await ref.read(chatsProvider.notifier).refresh();
    } catch (e) {
      state = AsyncData<List<ApiMessage>>(current);
    }
  }
}

final chatMessagesProvider =
    AsyncNotifierProvider.family<ChatMessagesNotifier, List<ApiMessage>, int>(
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
      ..sort((ApiMessage a, ApiMessage b) => a.id.compareTo(b.id));

    state = AsyncData<List<ApiMessage>>(next);

    if (_args.channelId != 0) {
      await ref.read(chatMessagesProvider(_args.channelId).notifier).refresh();
    } else {
      ref.invalidate(niosgramProvider);
    }

    await _playNotificationSound();
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
