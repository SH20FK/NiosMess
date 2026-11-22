import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';

/// Chats picked in the inbox multi-select mode. An empty set means the mode
/// is off: unpicking the last chat leaves it.
class InboxSelectionNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() {
    // Another account has other chats: the selection does not carry over.
    ref.watch(authProvider.select((AuthState a) => a.session?.userId));
    return const <int>{};
  }

  void toggle(int chatId) {
    final Set<int> next = <int>{...state};
    if (!next.remove(chatId)) next.add(chatId);
    state = Set<int>.unmodifiable(next);
  }

  /// Drops picked chats that are no longer in the list.
  void retainAll(Set<int> existing) {
    if (state.isEmpty || state.every(existing.contains)) return;
    state = Set<int>.unmodifiable(state.where(existing.contains).toSet());
  }

  void clear() {
    if (state.isNotEmpty) state = const <int>{};
  }
}

final inboxSelectionProvider =
    NotifierProvider<InboxSelectionNotifier, Set<int>>(
      InboxSelectionNotifier.new,
    );
