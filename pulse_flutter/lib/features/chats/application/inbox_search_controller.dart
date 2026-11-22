import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/models/api/search_models.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/repositories/search_repository.dart';

enum InboxSearchScope { all, chats, messages, people }

/// Search that lives inside the inbox: the header turns into a field and the
/// chat list is replaced by results once there is a query.
@immutable
class InboxSearchState {
  const InboxSearchState({
    this.active = false,
    this.query = '',
    this.scope = InboxSearchScope.all,
    this.loading = false,
    this.failed = false,
    this.result,
  });

  final bool active;

  /// Trimmed query. Empty while the field is open but nothing is typed: the
  /// regular chat list stays on screen in that case.
  final String query;
  final InboxSearchScope scope;
  final bool loading;
  final bool failed;

  /// Server matches for [query]; `null` until the first response.
  final ApiSearchResult? result;

  bool get hasQuery => active && query.isNotEmpty;
}

class InboxSearchController extends Notifier<InboxSearchState> {
  static const Duration _debounceDelay = Duration(milliseconds: 220);

  Timer? _debounce;
  int _generation = 0;

  @override
  InboxSearchState build() {
    // Results belong to one account: switching it closes the search.
    ref.watch(
      authProvider.select(
        (AuthState s) => (s.session?.userId, s.session?.accessToken),
      ),
    );
    _cancel();
    ref.onDispose(_cancel);
    return const InboxSearchState();
  }

  void open() {
    if (!state.active) state = const InboxSearchState(active: true);
  }

  void close() {
    _cancel();
    if (state.active) state = const InboxSearchState();
  }

  void setScope(InboxSearchScope scope) {
    if (!state.active || state.scope == scope) return;
    state = InboxSearchState(
      active: true,
      query: state.query,
      scope: scope,
      loading: state.loading,
      failed: state.failed,
      result: state.result,
    );
  }

  void setQuery(String raw) {
    final String query = raw.trim();
    if (!state.active || query == state.query) return;
    _start(query);
  }

  void retry() {
    if (state.hasQuery) _start(state.query);
  }

  void _start(String query) {
    _cancel();
    if (query.isEmpty) {
      state = InboxSearchState(active: true, scope: state.scope);
      return;
    }
    state = InboxSearchState(
      active: true,
      query: query,
      scope: state.scope,
      loading: true,
    );
    final int generation = _generation;
    _debounce = Timer(_debounceDelay, () => unawaited(_run(query, generation)));
  }

  void _cancel() {
    _generation++;
    _debounce?.cancel();
    _debounce = null;
  }

  (int?, String?) _account() {
    final session = ref.read(authProvider).session;
    return (session?.userId, session?.accessToken);
  }

  Future<void> _run(String query, int generation) async {
    final (int?, String?) account = _account();
    ApiSearchResult? result;
    try {
      result = await ref.read(searchRepositoryProvider).search(query);
    } catch (_) {
      result = null;
    }
    // A newer query, a closed search or another account owns the state now.
    // The account is compared too: the provider rebuilds lazily after a
    // switch, so the generation alone can still be the old one.
    if (!ref.mounted || generation != _generation || account != _account()) {
      return;
    }
    state = InboxSearchState(
      active: true,
      query: query,
      scope: state.scope,
      failed: result == null,
      result: result,
    );
  }
}

final inboxSearchProvider =
    NotifierProvider<InboxSearchController, InboxSearchState>(
      InboxSearchController.new,
    );
