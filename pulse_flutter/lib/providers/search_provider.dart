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
    
    final List<ApiSearchUser> localUsers = [];
    
    for (final chat in localChats) {
      if (chat.chatType == 'direct' && chat.username != null) {
        final String username = chat.username!;
        final String name = chat.name;
        final bool isMatch = username.toLowerCase().contains(lowerQuery) || name.toLowerCase().contains(lowerQuery);
            
        if (isMatch) {
          localUsers.add(ApiSearchUser(
            id: chat.id,
            username: username,
            displayName: name,
            avatarUrl: chat.avatarUrl,
            bio: chat.description,
            badges: chat.partnerBadges,
          ));
        }
      }
    }

    // Update state instantly with local matches so the user sees results immediately
    state = AsyncData<ApiSearchResult>(ApiSearchResult(
      users: localUsers,
      chats: [],
      messages: [],
    ));

    // Debounce the backend request
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _executeSearch(trimmed, localUsers);
    });
  }

  Future<void> _executeSearch(String query, List<ApiSearchUser> localUsers) async {
    final int seq = ++_seq;
    // We do not emit AsyncLoading here to preserve the instant local results on the UI.
    try {
      final ApiSearchResult backendResult = await ref
          .read(searchRepositoryProvider)
          .search(query);

      final Map<String, ApiSearchUser> mergedUsers = {
        for (final u in localUsers) u.username.toLowerCase(): u,
      };
      for (final u in backendResult.users) {
        mergedUsers[u.username.toLowerCase()] = u;
      }

      List<ApiSearchUser> finalUsers = mergedUsers.values.toList();

      List<ApiSearchChat> finalChats = backendResult.chats;

      final ApiSearchResult finalResult = ApiSearchResult(
        users: finalUsers,
        chats: finalChats,
        messages: backendResult.messages,
      );

      if (seq == _seq) {
        state = AsyncData<ApiSearchResult>(finalResult);
      }
    } on Object {
      if (seq == _seq) {
        state = AsyncData<ApiSearchResult>(ApiSearchResult(
          users: localUsers,
          chats: [],
          messages: [],
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

