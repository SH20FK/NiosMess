import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';

class ChatDetailScrollToBottomFAB extends StatelessWidget {
  const ChatDetailScrollToBottomFAB({
    super.key,
    required this.show,
    required this.onPressed,
    required this.chatId,
  });

  final bool show;
  final VoidCallback onPressed;
  final int chatId;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 8,
      child: RepaintBoundary(
        child: AnimatedOpacity(
          opacity: show ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: AnimatedScale(
            scale: show ? 1.0 : 0.7,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: FloatingActionButton.small(
              onPressed: show ? onPressed : null,
              heroTag: 'scroll_down_$chatId',
              tooltip: context.l10n.chatScrollToBottom,
              child: const Icon(Icons.keyboard_arrow_down_rounded),
            ),
          ),
        ),
      ),
    );
  }
}
