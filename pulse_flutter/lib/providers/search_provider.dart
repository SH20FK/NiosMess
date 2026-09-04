import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/models/api/search_models.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/repositories/search_repository.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';

class DebouncedSearchNotifier extends AsyncNotifier<ApiSearchResult> {
  Timer? _debounce;
  int _seq = 0;

  @override
  ApiSearchResult build() {
    ref.onDispose(() {
      _debounce?.cancel();
    });
    return const ApiSearchResult.empty();
  }

  void search(String query) {
    _debounce?.cancel();
    final String trimmed = query.trim();
    if (trimmed.isEmpty) {
      state = const AsyncData<ApiSearchResult>(ApiSearchResult.empty());
      return;
    }

    final chatsAsync = ref.read(chatsProvider);
    final List<ApiChatSummary> localChats = chatsAsync.value ?? [];
    final String lowerQuery = trimmed.toLowerCase();

    final List<ApiSearchChat> localMatchingChats = <ApiSearchChat>[];
    final List<ApiSearchUser> localMatchingUsers = <ApiSearchUser>[];
    final List<ApiSearchMessage> localMatchingMessages = <ApiSearchMessage>[];

    for (final ApiChatSummary chat in localChats) {
      final String name = chat.name;
      final String? username = chat.username;
      final String? lastMsg = chat.lastMessage?.content;

      final bool nameMatch = name.toLowerCase().contains(lowerQuery);
      final bool userMatch =
          username != null && username.toLowerCase().contains(lowerQuery);
      final bool msgMatch =
          lastMsg != null && lastMsg.toLowerCase().contains(lowerQuery);

      if (nameMatch || userMatch) {
        localMatchingChats.add(ApiSearchChat(
          id: chat.id,
          chatType: chat.chatType,
          name: chat.name,
          username: chat.username,
          avatarUrl: chat.avatarUrl,
          membersCount: chat.membersCount,
        ));
      }

      if (chat.chatType == 'direct' && (nameMatch || userMatch)) {
        localMatchingUsers.add(ApiSearchUser(
          id: chat.id,
          username: username ?? '',
          displayName: name,
          avatarUrl: chat.avatarUrl,
          bio: chat.description,
          badges: chat.partnerBadges,
        ));
      }

      if (msgMatch && chat.lastMessage != null) {
        localMatchingMessages.add(ApiSearchMessage(
          id: chat.lastMessage!.id,
          chatId: chat.id,
          content: chat.lastMessage!.content,
          senderDisplayName: chat.name,
          senderUsername: chat.username,
        ));
      }
    }

    // Update state instantly with local matches so the user sees results immediately
    state = AsyncData<ApiSearchResult>(ApiSearchResult(
      users: localMatchingUsers,
      chats: localMatchingChats,
      messages: localMatchingMessages,
    ));

    // Debounce the backend request
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _executeSearch(
        trimmed,
        localMatchingChats,
        localMatchingUsers,
        localMatchingMessages,
      );
    });
  }

  Future<void> _executeSearch(
    String query,
    List<ApiSearchChat> localChats,
    List<ApiSearchUser> localUsers,
    List<ApiSearchMessage> localMessages,
  ) async {
    final int seq = ++_seq;
    try {
      final ApiSearchResult backendResult = await ref
          .read(searchRepositoryProvider)
          .search(query);

      final Map<int, ApiSearchChat> mergedChats = <int, ApiSearchChat>{
        for (final c in localChats) c.id: c,
      };
      for (final c in backendResult.chats) {
        mergedChats[c.id] = c;
      }

      final Map<String, ApiSearchUser> mergedUsers = <String, ApiSearchUser>{
        for (final u in localUsers)
          if (u.username.isNotEmpty) u.username.toLowerCase(): u,
      };
      for (final u in backendResult.users) {
        if (u.username.isNotEmpty) {
          mergedUsers[u.username.toLowerCase()] = u;
        } else {
          mergedUsers['id_${u.id}'] = u;
        }
      }

      final Map<int, ApiSearchMessage> mergedMessages = <int, ApiSearchMessage>{
        for (final m in localMessages) m.id: m,
      };
      for (final m in backendResult.messages) {
        mergedMessages[m.id] = m;
      }

      final ApiSearchResult finalResult = ApiSearchResult(
        users: mergedUsers.values.toList(),
        chats: mergedChats.values.toList(),
        messages: mergedMessages.values.toList(),
      );

      if (seq == _seq) {
        state = AsyncData<ApiSearchResult>(finalResult);
      }
    } on Object {
      if (seq == _seq) {
        state = AsyncData<ApiSearchResult>(ApiSearchResult(
          users: localUsers,
          chats: localChats,
          messages: localMessages,
        ));
      }
    }
  }

  void clear() {
    _debounce?.cancel();
    _seq++;
    state = const AsyncData<ApiSearchResult>(ApiSearchResult.empty());
  }
}

final AsyncNotifierProvider<DebouncedSearchNotifier, ApiSearchResult>
debouncedSearchProvider =
    AsyncNotifierProvider<DebouncedSearchNotifier, ApiSearchResult>(
      DebouncedSearchNotifier.new,
    );

final AsyncNotifierProvider<DebouncedSearchNotifier, ApiSearchResult>
chatListSearchProvider =
    AsyncNotifierProvider<DebouncedSearchNotifier, ApiSearchResult>(
      DebouncedSearchNotifier.new,
    );

