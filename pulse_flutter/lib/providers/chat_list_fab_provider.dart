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

final chatListFabVisibleProvider =
    NotifierProvider<ChatListFabVisibleNotifier, bool>(
  ChatListFabVisibleNotifier.new,
);
