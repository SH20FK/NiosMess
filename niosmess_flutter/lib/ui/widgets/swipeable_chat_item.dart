import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../core/theme.dart';
import '../../core/focus_mode_provider.dart';

/// Swipeable chat list item with Telegram-style actions
class SwipeableChatItem extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onPin;
  final VoidCallback? onRead;
  final VoidCallback? onMute;
  final VoidCallback? onDelete;
  final bool isPinned;
  final bool isRead;
  final bool isMuted;

  const SwipeableChatItem({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.onPin,
    this.onRead,
    this.onMute,
    this.onDelete,
    this.isPinned = false,
    this.isRead = false,
    this.isMuted = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Slidable(
      key: ValueKey(key),
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        children: [
          // Pin/Read actions on right swipe
          if (onPin != null)
            CustomSlidableAction(
              onPressed: (_) => onPin!(),
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.primary,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPinned ? 'Открепить' : 'Закрепить',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          if (onRead != null)
            CustomSlidableAction(
              onPressed: (_) => onRead!(),
              backgroundColor: colorScheme.secondaryContainer,
              foregroundColor: colorScheme.secondary,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isRead ? Icons.mark_email_unread : Icons.mark_email_read,
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isRead ? 'Не прочитано' : 'Прочитано',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        children: [
          // Mute/Delete actions on left swipe
          if (onMute != null)
            CustomSlidableAction(
              onPressed: (_) => onMute!(),
              backgroundColor: colorScheme.tertiaryContainer,
              foregroundColor: colorScheme.tertiary,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isMuted ? Icons.notifications_off : Icons.notifications,
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isMuted ? 'Включить' : 'Без звука',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          if (onDelete != null)
            CustomSlidableAction(
              onPressed: (_) => onDelete!(),
              backgroundColor: colorScheme.errorContainer,
              foregroundColor: colorScheme.error,
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_outline, size: 24),
                  SizedBox(height: 4),
                  Text('Удалить', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: child,
        ),
      ),
    );
  }
}

/// Focus Mode toggle button for chat list header
class FocusModeToggle extends StatelessWidget {
  final FocusModeType mode;
  final VoidCallback onToggle;

  const FocusModeToggle({
    super.key,
    required this.mode,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    IconData icon;
    String label;
    Color color;

    switch (mode) {
      case FocusModeType.all:
        icon = Icons.all_inclusive;
        label = 'Все';
        color = colorScheme.onSurfaceVariant;
        break;
      case FocusModeType.work:
        icon = Icons.work_outline;
        label = 'Работа';
        color = colorScheme.primary;
        break;
      case FocusModeType.personal:
        icon = Icons.people_outline;
        label = 'Личное';
        color = colorScheme.tertiary;
        break;
    }

    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: mode == FocusModeType.all 
              ? colorScheme.surfaceContainerHighest 
              : color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: mode == FocusModeType.all 
                ? colorScheme.outline 
                : color,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Double check read indicator (Telegram style)
class ReadChecks extends StatelessWidget {
  final bool isRead;
  final Color? color;
  final double size;

  const ReadChecks({
    super.key,
    required this.isRead,
    this.color,
    this.size = 14,
  });

  @override
  Widget build(BuildContext context) {
    final defaultColor = color ?? Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: size * 1.5,
      height: size,
      child: Stack(
        children: [
          // First check (always visible)
          Positioned(
            left: 0,
            child: Icon(
              Icons.check,
              size: size,
              color: isRead ? defaultColor : defaultColor.withOpacity(0.5),
            ),
          ),
          // Second check (offset, only visible when read)
          Positioned(
            left: size * 0.35,
            child: Icon(
              Icons.check,
              size: size,
              color: isRead ? defaultColor : Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}

/// Muted blue unread badge (Telegram style - not bright red)
class MutedUnreadBadge extends StatelessWidget {
  final int count;
  final double minWidth;

  const MutedUnreadBadge({
    super.key,
    required this.count,
    this.minWidth = 22,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayCount = count > 99 ? '99+' : count.toString();

    return Container(
      constraints: BoxConstraints(
        minWidth: minWidth,
        minHeight: minWidth * 0.7,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.85),
        borderRadius: BorderRadius.circular(minWidth / 2),
      ),
      child: Text(
        displayCount,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Online status indicator with cutout style (Telegram style)
class OnlineStatusIndicator extends StatelessWidget {
  final bool isOnline;
  final double size;
  final double borderWidth;

  const OnlineStatusIndicator({
    super.key,
    required this.isOnline,
    this.size = 14,
    this.borderWidth = 2.5,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOnline) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50), // Telegram green
        shape: BoxShape.circle,
        border: Border.all(
          color: colorScheme.surface,
          width: borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}
