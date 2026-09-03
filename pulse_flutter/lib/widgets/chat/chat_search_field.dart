import 'package:flutter/material.dart';
import 'package:pulse_flutter/widgets/chat/chat_search_bar.dart';

export 'package:pulse_flutter/widgets/chat/chat_search_bar.dart';

/// Legacy alias for [ChatSearchBar] maintaining backwards compatibility.
class ChatSearchField extends StatelessWidget {
  const ChatSearchField({
    super.key,
    this.onAvatarTap,
    this.hintText,
  });

  final VoidCallback? onAvatarTap;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return ChatSearchBar(
      onAvatarTap: onAvatarTap,
      hintText: hintText,
    );
  }
}
