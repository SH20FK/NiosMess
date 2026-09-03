import 'package:flutter/material.dart';
import 'package:pulse_flutter/widgets/chat/chat_filter_bar.dart';

export 'package:pulse_flutter/widgets/chat/chat_filter_bar.dart';

/// Legacy alias for [ChatFilterBar] maintaining backwards compatibility.
class ChatListFilterBar extends StatelessWidget {
  const ChatListFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    return const ChatFilterBar();
  }
}
