import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class ChatListFabExpandedNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void expand() {
    if (!state) state = true;
  }

  void collapse() {
    if (state) state = false;
  }
}

final chatListFabExpandedProvider =
    NotifierProvider<ChatListFabExpandedNotifier, bool>(
  ChatListFabExpandedNotifier.new,
);

final chatListFabVisibleProvider =
    NotifierProvider<ChatListFabVisibleNotifier, bool>(
  ChatListFabVisibleNotifier.new,
);
