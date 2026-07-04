import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ChatFilter { all, unread, groups, channels, direct, bots }

class ChatFilterNotifier extends Notifier<ChatFilter> {
  @override
  ChatFilter build() => ChatFilter.all;

  void updateFilter(ChatFilter filter) {
    state = filter;
  }
}

final chatFilterProvider = NotifierProvider<ChatFilterNotifier, ChatFilter>(ChatFilterNotifier.new);
