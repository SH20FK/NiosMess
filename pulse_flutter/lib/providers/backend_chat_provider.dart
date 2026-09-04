import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/core/storage/cache_service.dart';
import 'package:pulse_flutter/core/storage/encrypted_message_cache.dart';
import 'package:pulse_flutter/core/storage/notification_storage.dart';
import 'package:pulse_flutter/models/api/chat_member_model.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/badge_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/niosgram_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/providers/websocket_dispatcher_provider.dart';
import 'package:pulse_flutter/repositories/auth_repository.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/services/double_ratchet_service.dart';
import 'package:pulse_flutter/services/e2ee_service.dart';

ApiMessage _stubMessage(int id, int chatId, {int senderId = 0, bool isDeleted = false}) =>
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

/// Parsed E2EE handshake (HELO) message: a plain text message whose content
/// is JSON `{"dh": ..., "ed": ..., "sig": ...}`.
class _E2eeHelo {
  const _E2eeHelo({required this.dhPubB64, required this.edPubB64, required this.signature});

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
    final Map<String, dynamic> map = jsonDecode(content) as Map<String, dynamic>;
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
    ref.onDispose(() {
      WebSocketPushDispatcher.unregisterGlobal();
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
    }
  }

  void _handleReadPush(int chatId, int userId) {
    final List<ApiChatSummary>? currentChats = state.value;
    if (currentChats == null) return;

    final int index =
        currentChats.indexWhere((ApiChatSummary c) => c.id == chatId);
    if (index == -1) return;
    final ApiChatSummary chat = currentChats[index];

    final int myUserId = ref.read(authProvider).session?.userId ?? -1;
    final List<ApiChatSummary> updated = List<ApiChatSummary>.from(currentChats);

    if (userId == myUserId) {
      // Current user read the chat
      if (chat.unreadCount != 0) {
        updated[index] = chat.copyWith(unreadCount: 0);
        state = AsyncData<List<ApiChatSummary>>(updated);
        ref.read(cacheServiceProvider).saveChats(updated);
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
        ref.read(cacheServiceProvider).saveChats(updated);
      }
    }
  }

  void _handleDeletedPush(ApiMessage message) {
    final List<ApiChatSummary>? currentChats = state.value;
    if (currentChats == null) return;

    final int index =
        currentChats.indexWhere((ApiChatSummary c) => c.id == message.chatId);
    if (index == -1) return;
    final ApiChatSummary chat = currentChats[index];
    if (chat.lastMessage?.id != message.id) return;

    final List<ApiChatSummary> updated = List<ApiChatSummary>.from(currentChats);
    updated[index] = chat.copyWith(
      lastMessage: chat.lastMessage?.copyWith(
        content: 'Сообщение удалено',
        isDeleted: true,
      ),
    );
    state = AsyncData<List<ApiChatSummary>>(updated);
    ref.read(cacheServiceProvider).saveChats(updated);
  }

  void _handleReactionPush(ApiMessage message, String emoji, {required bool added}) {
    if (emoji.isEmpty) return;
    final List<ApiChatSummary>? currentChats = state.value;
    if (currentChats == null) return;

    final int index =
        currentChats.indexWhere((ApiChatSummary c) => c.id == message.chatId);
    if (index == -1) return;
    final ApiChatSummary chat = currentChats[index];
    if (chat.lastMessage?.id != message.id) return;

    final Map<String, int> reactions =
        Map<String, int>.from(chat.lastMessage!.reactions);
    final int count = (reactions[emoji] ?? 0) + (added ? 1 : -1);
    if (count > 0) {
      reactions[emoji] = count;
    } else {
      reactions.remove(emoji);
    }

    final List<ApiChatSummary> updated = List<ApiChatSummary>.from(currentChats);
    updated[index] = chat.copyWith(
      lastMessage: chat.lastMessage!.copyWith(reactions: reactions),
    );
    state = AsyncData<List<ApiChatSummary>>(updated);
    ref.read(cacheServiceProvider).saveChats(updated);
  }

  void _handleEditedPush(ApiMessage message) {
    final List<ApiChatSummary>? currentChats = state.value;
    if (currentChats == null) return;

    final int index =
        currentChats.indexWhere((ApiChatSummary c) => c.id == message.chatId);
    if (index == -1) return;
    final ApiChatSummary chat = currentChats[index];
    if (chat.lastMessage?.id != message.id) return;

    final List<ApiChatSummary> updated = List<ApiChatSummary>.from(currentChats);
    updated[index] = chat.copyWith(lastMessage: message);
    state = AsyncData<List<ApiChatSummary>>(updated);
    ref.read(cacheServiceProvider).saveChats(updated);
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
      }
    } else {
      refresh();
    }
  }

  Future<List<ApiChatSummary>> _fetch() async {
    try {
      String? publicKey;
      try {
        final e2ee = ref.read(e2eeServiceProvider);
        publicKey = await e2ee.getPublicKeyBase64();
        if (publicKey.isNotEmpty) {
          try {
            await ref.read(authRepositoryProvider).setPublicKey(publicKey);
          } catch (e) {
            debugPrint('[backend_chat_provider] Set public key error: $e');
          }
        }
      } catch (e) {
        debugPrint('[backend_chat_provider] Get public key error: $e');
      }
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

    ref.read(webSocketDispatcherProvider);
    WebSocketPushDispatcher.registerChat(_chatId, handlePush);
    ref.onDispose(() {
      WebSocketPushDispatcher.unregisterChat(_chatId);
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

    final List<ApiMessage> messages = await _fetch();
    unawaited(ensureSecretHandshake());
    return messages;
  }

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
        _handleReactionPush(event.message, event.reactionEmoji!,
            added: event.reactionAdded);
      case ChatPushEventKind.read:
        _handleReadPush(event.userId!);
    }
  }

  Future<void> _handleEditedIncomingMessage(ApiMessage message) async {
    final List<ApiMessage> current = state.value ?? const <ApiMessage>[];
    final int index = current.indexWhere((ApiMessage m) => m.id == message.id);

    ApiMessage next = message;
    // Secret chats: re-decrypt the edited payload.
    if (message.isE2ee && message.e2eeContent != null) {
      final List<ApiMessage> decrypted =
          await _decryptE2eeMessages(<ApiMessage>[message]);
      if (decrypted.isNotEmpty) next = decrypted.first;
    }

    final List<ApiMessage> updated;
    if (index != -1) {
      updated = List<ApiMessage>.from(current)..[index] = next;
    } else {
      updated = List<ApiMessage>.from(current)..add(next);
      updated.sort(_compareMessages);
    }
    state = AsyncData<List<ApiMessage>>(updated);
    await _saveToCache(updated);
  }

  void _handleDeletedIncomingMessage(ApiMessage message) {
    final List<ApiMessage> current = state.value ?? const <ApiMessage>[];
    final int index = current.indexWhere((ApiMessage m) => m.id == message.id);
    if (index == -1) return;

    final List<ApiMessage> updated = List<ApiMessage>.from(current)
      ..removeAt(index);
    state = AsyncData<List<ApiMessage>>(updated);
    _saveToCache(updated);
  }

  void _handleReactionPush(ApiMessage message, String emoji,
      {required bool added}) {
    final List<ApiMessage> current = state.value ?? const <ApiMessage>[];
    final int index = current.indexWhere((ApiMessage m) => m.id == message.id);
    if (index == -1) return;

    final Map<String, int> reactions =
        Map<String, int>.from(current[index].reactions);
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
    final List<ApiMessage> current = state.value ?? const <ApiMessage>[];

    if (current.any((ApiMessage m) => m.id == message.id)) {
      return;
    }

    final List<ApiMessage> decrypted = await _decryptE2eeMessages(<ApiMessage>[message]);
    if (decrypted.isEmpty) {
      // The message was E2EE protocol traffic (handshake) — not rendered.
      return;
    }
    final ApiMessage finalMessage = decrypted.first;
    final int myUserId = ref.read(authProvider).session?.userId ?? -1;
    final List<ApiMessage> next = List<ApiMessage>.from(current);
    if (finalMessage.senderId == myUserId) {
      next.removeWhere((m) => m.id < 0 && m.content == finalMessage.content);
    }
    next.add(finalMessage);
    next.sort(_compareMessages);

    state = AsyncData<List<ApiMessage>>(next);
    await _saveToCache(next);

    if (message.senderId != myUserId) {
      await _playNotificationSound();
    }
  }

  Future<List<ApiMessage>> _fetch() async {
    final List<ApiMessage> messages = await ref.read(chatRepositoryProvider).getHistory(_chatId, pageSize: 80);
    final List<ApiMessage> decrypted = await _decryptE2eeMessages(messages);
    try {
      await EncryptedMessageCache.saveMessages(_chatId, decrypted);
    } catch (e) {
      debugPrint('[backend_chat_provider.dart] Save messages cache error: $e');
    }
    return decrypted;
  }

  Future<String?> _getPartnerPublicKey() {
    final chat = ref.read(chatByIdProvider(_chatId));
    if (chat?.partnerPublicKey != null && chat!.partnerPublicKey!.isNotEmpty) {
      return Future.value(chat.partnerPublicKey);
    }
    return Future.value(null);
  }

  Future<List<ApiMessage>> _decryptE2eeMessages(List<ApiMessage> messages) async {
    final partnerPublicKey = await _getPartnerPublicKey();
    if (partnerPublicKey == null) {
      // Not a secret chat — but handshake echoes can still be filtered out.
      return messages.where((ApiMessage m) => _parseHeloMessage(m) == null).toList();
    }

    final e2eeService = ref.read(e2eeServiceProvider);
    final List<ApiMessage> result = <ApiMessage>[];

    for (int i = 0; i < messages.length; i++) {
      final ApiMessage msg = messages[i];

      final _E2eeHelo? helo = _parseHeloMessage(msg);
      if (helo != null) {
        // Only act on a HELO when it is the newest message (fresh handshake
        // in flight); old HELOs from history must not re-key the session.
        final bool isLatest = i == messages.length - 1;
        if (isLatest) {
          await _handleIncomingHelo(helo, partnerPublicKey);
        }
        // Handshake messages are protocol traffic — never rendered.
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
              result.add(msg.copyWith(
                content: '',
                e2eeFileKey: fk,
                mediaName: (envelope['name'] as String?) ?? msg.mediaName,
                mediaSize: msg.mediaSize ?? (envelope['size'] as int?),
              ));
              continue;
            }
          } catch (_) {}
        }

        result.add(msg.copyWith(content: decrypted));
      } catch (e) {
        debugPrint('[backend_chat_provider.dart] E2EE decrypt failed for msg ${msg.id}: $e');
        result.add(msg);
      }
    }
    return result;
  }

  /// Runs the receiving side of the E2EE handshake state machine:
  /// - no session → respond (create responder session, reply with our HELO);
  /// - pending initiator session → the peer's HELO completes it;
  /// - secured/compromised → ignore (old duplicate).
  Future<void> _handleIncomingHelo(
    _E2eeHelo helo,
    String partnerPublicKey,
  ) async {
    final E2eeService e2ee = ref.read(e2eeServiceProvider);
    final E2eeSessionStatus status = e2ee.getSessionStatus(_chatId);
    final DoubleRatchetSession? existing =
        await e2ee.getOrCreateSession(chatId: _chatId, theirPublicKeyBase64: partnerPublicKey);

    try {
      if (existing != null && status == E2eeSessionStatus.connecting) {
        await e2ee.completeHandshake(
          chatId: _chatId,
          theirEphemeralPublicKeyBase64: helo.dhPubB64,
          theirEdPublicKeyBase64: helo.edPubB64,
        );
        debugPrint('[backend_chat_provider.dart] E2EE handshake completed for chat $_chatId');
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
        debugPrint('[backend_chat_provider.dart] E2EE handshake responded for chat $_chatId');
      }
    } catch (e) {
      debugPrint('[backend_chat_provider.dart] E2EE handshake handling failed: $e');
    }
  }

  /// Makes sure a secret direct chat eventually runs a Double Ratchet
  /// handshake without the user pressing anything: when no session exists,
  /// exactly one side (the one with the lexicographically greater static
  /// public key) initiates, the other responds on HELO receipt.
  Future<void> ensureSecretHandshake() async {
    final String? partnerPublicKey = await _getPartnerPublicKey();
    if (partnerPublicKey == null) return;

    final E2eeService e2ee = ref.read(e2eeServiceProvider);
    final DoubleRatchetSession? existing = await e2ee.getOrCreateSession(
      chatId: _chatId,
      theirPublicKeyBase64: partnerPublicKey,
    );
    if (existing != null) return;

    final String ourPub = await e2ee.getPublicKeyBase64();
    if (ourPub.compareTo(partnerPublicKey) <= 0) return; // peer initiates

    final String edPubB64 = await e2ee.getEdPublicKeyBase64();
    await e2ee.initiateHandshake(
      chatId: _chatId,
      theirPublicKeyBase64: partnerPublicKey,
      theirEdPublicKeyBase64: edPubB64,
    );
    final ({String dhPubB64, String edPubB64, List<int> signature}) msg =
        await e2ee.createHandshakeMessage(_chatId);
    await sendHandshakeMessage(
      dhPubB64: msg.dhPubB64,
      edPubB64: msg.edPubB64,
      signature: msg.signature,
    );
    debugPrint('[backend_chat_provider.dart] E2EE handshake auto-initiated for chat $_chatId');
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

    merged.sort(_compareMessages);
    final List<ApiMessage> decrypted = await _decryptE2eeMessages(merged);
    state = AsyncData<List<ApiMessage>>(decrypted);
    await _saveToCache(decrypted);
    return added;
  }

  Future<void> markRead() async {
    try {
      await ref.read(chatRepositoryProvider).markRead(_chatId);
      final int myUserId = ref.read(authProvider).session?.userId ?? -1;
      ref.read(chatsProvider.notifier)._handleReadPush(_chatId, myUserId);
    } catch (e) { debugPrint('[backend_chat_provider.dart] Error: $e'); }
  }

  Future<void> send(String content,
      {int? replyToId,
      String? uploadId,
      String msgType = 'text',
      String? localId,
      String? e2eePlaintext,
      String? e2eeFileKey}) async {
    final String trimmed = content.trim();
    if (trimmed.isEmpty && (uploadId == null || uploadId.trim().isEmpty)) {
      return;
    }

    // Try to parse localId to an integer if it's already there
    final int tempId;
    if (localId != null) {
      tempId = int.tryParse(localId) ?? -(DateTime.now().millisecondsSinceEpoch + _sendCounter++);
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
    if (chat?.isSecret == true &&
        chat?.partnerPublicKey != null &&
        e2eePlain.isNotEmpty) {
      try {
        final e2eeService = ref.read(e2eeServiceProvider);
        final session = await e2eeService.getOrCreateSession(
          chatId: _chatId,
          theirPublicKeyBase64: chat!.partnerPublicKey!,
        );
        if (session != null) {
          e2eeContent = await e2eeService.encryptE2EEMessageDR(
            plaintext: e2eePlain,
            chatId: _chatId,
          );
        } else {
          e2eeContent = await e2eeService.encryptE2EEMessage(
            plaintext: e2eePlain,
            chatId: _chatId,
            theirPublicKeyBase64: chat.partnerPublicKey!,
          );
        }
        isE2ee = true;
      } catch (e) {
        debugPrint('[backend_chat_provider.dart] E2EE encrypt failed: $e');
      }
    }

    final ApiMessage optimisticMessage = ApiMessage(
      id: tempId,
      chatId: _chatId,
      senderId: myUserId,
      senderUsername: myUsername,
      senderDisplayName: myUsername.isEmpty ? 'Я' : myUsername,
      senderBadges: const [],
      content: (isE2ee && uploadId != null) ? '' : trimmed,
      msgType: uploadId != null ? msgType : 'text',
      replyToId: replyToId,
      mediaUrl: uploadId != null ? 'local://$localId' : null, // placeholder indicating local file being sent
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
      List<ApiMessage> next = List<ApiMessage>.from(current)..add(optimisticMessage);
      next.sort(_compareMessages);
      state = AsyncData<List<ApiMessage>>(next);
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

      if (isE2ee) {
        sent = sent.copyWith(content: trimmed, e2eeFileKey: e2eeFileKey);
      }

      current = state.value ?? const <ApiMessage>[];
      List<ApiMessage> next = List<ApiMessage>.from(current)
        ..removeWhere((ApiMessage message) => message.id == tempId)
        ..removeWhere((ApiMessage message) => message.id == sent.id)
        ..add(sent)
        ..sort(_compareMessages);

      state = AsyncData<List<ApiMessage>>(next);
      await _saveToCache(next);
      ref.read(chatsProvider.notifier)._handleNewMessagePush(sent);
      await _playNotificationSound(volume: 0.65);
    } catch (e) {
      current = state.value ?? const <ApiMessage>[];
      List<ApiMessage> next = List<ApiMessage>.from(current);
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
      await ref.read(chatRepositoryProvider).sendMessage(
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
      List<ApiMessage> next = List<ApiMessage>.from(current)..add(msg);
      next.sort(_compareMessages);
      state = AsyncData<List<ApiMessage>>(next);
    }
  }

  void markLocalMessageFailed(String localId) {
    final int tempId = int.tryParse(localId) ?? 0;
    if (tempId == 0) return;
    List<ApiMessage> current = state.value ?? const <ApiMessage>[];
    final int index = current.indexWhere((m) => m.id == tempId);
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
    if (index != -1) {
      List<ApiMessage> next = List<ApiMessage>.from(current);
      next[index] = next[index].copyWith(isSending: true, isFailed: false);
      state = AsyncData<List<ApiMessage>>(next);
    }
  }

  void removeOptimisticMessage(int tempId) {
    if (tempId == 0) return;
    List<ApiMessage> current = state.value ?? const <ApiMessage>[];
    final List<ApiMessage> next = List<ApiMessage>.from(current)
      ..removeWhere((m) => m.id == tempId);
    state = AsyncData<List<ApiMessage>>(next);
    _saveToCache(next);
  }

  Future<void> editMessage(int messageId, String content) async {
    final String trimmed = content.trim();
    if (trimmed.isEmpty) return;

    final List<ApiMessage> current = state.value ?? const <ApiMessage>[];
    final ApiMessage target = current.firstWhere(
      (ApiMessage m) => m.id == messageId,
      orElse: () => ApiMessage(
        id: 0, chatId: 0, senderId: 0, senderUsername: '', senderDisplayName: '',
        senderBadges: const <ApiBadge>[], content: '', msgType: 'text', replyToId: null,
        mediaUrl: null, mediaType: null, mediaName: null, mediaSize: null,
        mediaDuration: null, commentsCount: 0, reactions: <String, int>{},
        sentAt: DateTime.fromMillisecondsSinceEpoch(0), editedAt: null, isDeleted: false,
      ),
    );

    if (target.id == 0) return;

    final ApiMessage optimisticEdited = target.copyWith(
      content: trimmed,
      editedAt: DateTime.now(),
    );
    final List<ApiMessage> optimisticNext = List<ApiMessage>.from(current)
      ..removeWhere((ApiMessage m) => m.id == messageId)
      ..add(optimisticEdited)
      ..sort(_compareMessages);
    state = AsyncData<List<ApiMessage>>(optimisticNext);

    try {
      final ApiMessage? edited = await ref
          .read(chatRepositoryProvider)
          .editMessage(_chatId, messageId, content: trimmed);

      if (edited != null) {
        final List<ApiMessage> confirmed = List<ApiMessage>.from(state.value ?? const <ApiMessage>[])
          ..removeWhere((ApiMessage m) => m.id == edited.id)
          ..add(edited)
          ..sort(_compareMessages);
        state = AsyncData<List<ApiMessage>>(confirmed);
        await _saveToCache(confirmed);
        ref.read(chatsProvider.notifier)._handleEditedPush(edited);
      }
    } catch (e) {
      final List<ApiMessage> latest = state.value ?? const <ApiMessage>[];
      final List<ApiMessage> reverted = latest.map((m) => m.id == messageId ? target : m).toList();
      state = AsyncData<List<ApiMessage>>(reverted);
    }
  }

  Future<void> deleteMessage(int messageId) async {
    final List<ApiMessage> current = state.value ?? const <ApiMessage>[];
    final ApiMessage? target = current.where((m) => m.id == messageId).firstOrNull;
    final List<ApiMessage> optimisticNext = List<ApiMessage>.from(current)
      ..removeWhere((ApiMessage m) => m.id == messageId);
    state = AsyncData<List<ApiMessage>>(optimisticNext);

    try {
      await ref.read(chatRepositoryProvider).deleteMessage(_chatId, messageId);
      await _saveToCache(optimisticNext);
      final ApiMessage deletedStub = _stubMessage(messageId, _chatId, isDeleted: true);
      ref.read(chatsProvider.notifier)._handleDeletedPush(deletedStub);
    } catch (e) {
      if (target != null) {
        final List<ApiMessage> latest = List<ApiMessage>.from(state.value ?? const <ApiMessage>[]);
        if (!latest.any((m) => m.id == messageId)) {
          latest.add(target);
          latest.sort((a, b) => a.id.compareTo(b.id));
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
      await ref.read(chatRepositoryProvider).sendCallbackQuery(_chatId, messageId, data);
    } catch (e) {
      debugPrint('[backend_chat_provider.dart] sendCallbackQuery error: $e');
    }
  }

  Future<void> toggleReaction(int messageId, String emoji) async {
    if (emoji.trim().isEmpty) return;

    final List<ApiMessage> current = state.value ?? const <ApiMessage>[];
    final ApiMessage? original = current.where((m) => m.id == messageId).firstOrNull;

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
      final ApiMessage? updatedMsg = optimisticNext.where((m) => m.id == messageId).firstOrNull;
      if (updatedMsg != null) {
        ref.read(chatsProvider.notifier)._handleEditedPush(updatedMsg);
      }
    } catch (e) {
      if (original != null) {
        final List<ApiMessage> latest = state.value ?? const <ApiMessage>[];
        final List<ApiMessage> reverted = latest.map((m) => m.id == messageId ? original : m).toList();
        state = AsyncData<List<ApiMessage>>(reverted);
      }
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
      ..sort(_compareMessages);

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
