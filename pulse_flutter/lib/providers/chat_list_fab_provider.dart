import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/features/chats/application/inbox_search_controller.dart';
import 'package:pulse_flutter/features/chats/application/inbox_selection_controller.dart';

class ChatListFabVisibleNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void show() {
    if (!state) {
      state = true;
    }
  }

  void hide() {
    if (state) {
      state = false;
    }
  }
}

final chatListFabVisibleProvider =
    NotifierProvider<ChatListFabVisibleNotifier, bool>(
  ChatListFabVisibleNotifier.new,
);

/// Whether the inbox composer button is on screen: not scrolled away, and
/// neither search nor multi-select has taken the inbox over. The button, the
/// scrim under it and the list's trailing room all follow this one answer.
final inboxComposerVisibleProvider = Provider<bool>((Ref ref) {
  return ref.watch(chatListFabVisibleProvider) &&
      !ref.watch(
        inboxSearchProvider.select((InboxSearchState s) => s.active),
      ) &&
      ref.watch(inboxSelectionProvider.select((Set<int> s) => s.isEmpty));
});
