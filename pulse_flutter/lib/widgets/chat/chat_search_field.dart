import 'package:flutter/material.dart';
import 'package:pulse_flutter/features/chats/presentation/inbox_search_launcher.dart';

export 'package:pulse_flutter/features/chats/presentation/inbox_search_launcher.dart';
export 'package:pulse_flutter/widgets/chat/chat_search_bar.dart';

/// Expressive inbox search launcher maintaining backwards compatibility.
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
    return InboxSearchLauncher(
      onTap: onAvatarTap,
      hintText: hintText,
    );
  }
}
