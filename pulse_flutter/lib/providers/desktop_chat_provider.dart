import 'package:flutter_riverpod/flutter_riverpod.dart';

class DesktopChatNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void setSelectedChat(int? chatId) {
    state = chatId;
  }
}

final NotifierProvider<DesktopChatNotifier, int?> desktopSelectedChatProvider =
    NotifierProvider<DesktopChatNotifier, int?>(
      DesktopChatNotifier.new,
    );
