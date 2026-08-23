import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';

class ChatDetailScrollToBottomFAB extends StatelessWidget {
  const ChatDetailScrollToBottomFAB({
    super.key,
    required this.show,
    required this.onPressed,
    required this.chatId,
    this.unreadCount = 0,
  });

  final bool show;
  final VoidCallback onPressed;
  final int chatId;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 16, bottom: 8),
        child: IgnorePointer(
          ignoring: !show,
          child: RepaintBoundary(
            child: AnimatedOpacity(
              opacity: show ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: AnimatedScale(
                scale: show ? 1.0 : 0.7,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                child: Badge(
                  isLabelVisible: unreadCount > 0,
                  label: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                  backgroundColor: scheme.primary,
                  textColor: scheme.onPrimary,
                  offset: const Offset(-2, -2),
                  child: FloatingActionButton.small(
                    onPressed: show ? onPressed : null,
                    heroTag: 'scroll_down_$chatId',
                    tooltip: context.l10n.chatScrollToBottom,
                    backgroundColor: scheme.surfaceContainerHigh,
                    foregroundColor: scheme.onSurface,
                    elevation: 3,
                    child: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
