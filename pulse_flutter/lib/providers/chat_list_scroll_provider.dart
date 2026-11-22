import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bumped when the inbox should return to its first row: the active "Chats"
/// destination was tapped again.
class ChatListScrollToTopNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state++;
}

final chatListScrollToTopProvider =
    NotifierProvider<ChatListScrollToTopNotifier, int>(
      ChatListScrollToTopNotifier.new,
    );
