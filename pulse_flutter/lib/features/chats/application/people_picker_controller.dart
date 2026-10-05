import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/features/chats/domain/member_candidate.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/search_models.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/repositories/search_repository.dart';

enum PeoplePickerMode {
  direct,
  secret,
}

@immutable
class PeoplePickerKey {
  const PeoplePickerKey({
    required this.sessionId,
    this.mode = PeoplePickerMode.direct,
  });

  final String sessionId;
  final PeoplePickerMode mode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PeoplePickerKey &&
          runtimeType == other.runtimeType &&
          sessionId == other.sessionId &&
          mode == other.mode;

  @override
  int get hashCode => Object.hash(sessionId, mode);
}

@immutable
class PeoplePickerState {
  const PeoplePickerState({
    this.query = '',
    this.recentCandidates = const <MemberCandidate>[],
    this.searchResults = const <MemberCandidate>[],
    this.isSearching = false,
    this.resolvingHandle,
    this.errorMessage,
  });

  final String query;
  final List<MemberCandidate> recentCandidates;
  final List<MemberCandidate> searchResults;
  final bool isSearching;
  final String? resolvingHandle;
  final String? errorMessage;

  bool get hasQuery => query.trim().isNotEmpty;

  PeoplePickerState copyWith({
    String? query,
    List<MemberCandidate>? recentCandidates,
    List<MemberCandidate>? searchResults,
    bool? isSearching,
    String? resolvingHandle,
    String? errorMessage,
  }) {
    return PeoplePickerState(
      query: query ?? this.query,
      recentCandidates: recentCandidates ?? this.recentCandidates,
      searchResults: searchResults ?? this.searchResults,
      isSearching: isSearching ?? this.isSearching,
      resolvingHandle: resolvingHandle,
      errorMessage: errorMessage,
    );
  }
}

class PeoplePickerController extends Notifier<PeoplePickerState> {
  PeoplePickerController(this.arg);
  final PeoplePickerKey arg;

  Timer? _debounce;
  int _generation = 0;

  @override
  PeoplePickerState build() {
    ref.onDispose(() {
      _debounce?.cancel();
    });

    final chats = ref.watch(chatsProvider).value ?? <ApiChatSummary>[];
    final recent = chats
        .map(candidateFromDirectChat)
        .whereType<MemberCandidate>()
        .fold<Map<int, MemberCandidate>>(<int, MemberCandidate>{}, (map, candidate) {
          map[candidate.userId] = candidate;
          return map;
        })
        .values
        .toList(growable: false);

    return PeoplePickerState(recentCandidates: recent);
  }

  void setQuery(String raw) {
    final String q = raw.trim();
    _debounce?.cancel();
    final int generation = ++_generation;

    if (q.isEmpty) {
      state = state.copyWith(
        query: '',
        searchResults: const <MemberCandidate>[],
        isSearching: false,
        errorMessage: null,
      );
      return;
    }

    state = state.copyWith(
      query: q,
      isSearching: true,
      errorMessage: null,
    );

    _debounce = Timer(const Duration(milliseconds: 220), () {
      _executeSearch(q, generation);
    });
  }

  Future<void> _executeSearch(String query, int generation) async {
    final searchRepo = ref.read(searchRepositoryProvider);
    try {
      final ApiSearchResult result = await searchRepo.search(query);
      if (generation != _generation) return;

      final candidates = result.users
          .where((u) => u.id > 0)
          .map((u) => MemberCandidate.fromSearchUser(u))
          .toList(growable: false);

      state = state.copyWith(
        searchResults: candidates,
        isSearching: false,
      );
    } catch (_) {
      if (generation != _generation) return;
      state = state.copyWith(
        isSearching: false,
        errorMessage: 'Ошибка при поиске',
      );
    }
  }

  Future<MemberCandidate?> resolveHandle(String raw) async {
    final String handle = raw.trim().replaceFirst(RegExp(r'^@'), '');
    if (handle.isEmpty) return null;

    state = state.copyWith(resolvingHandle: handle);
    try {
      final searchRepo = ref.read(searchRepositoryProvider);
      final result = await searchRepo.search(handle);
      final matched = result.users
          .where((u) => u.username.toLowerCase() == handle.toLowerCase() && u.id > 0)
          .firstOrNull;

      state = state.copyWith(resolvingHandle: null);
      if (matched != null) {
        return MemberCandidate.fromSearchUser(
          matched,
          source: MemberCandidateSource.usernameLookup,
        );
      }
      return null;
    } catch (_) {
      state = state.copyWith(resolvingHandle: null);
      return null;
    }
  }
}

final peoplePickerControllerProvider =
    NotifierProvider.family<PeoplePickerController, PeoplePickerState, PeoplePickerKey>(
  PeoplePickerController.new,
);
