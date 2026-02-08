import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ghost_mode_provider.dart';

/// Overlay widget for Ghost Mode reading
class GhostModeOverlay extends ConsumerWidget {
  final Widget child;
  final String chatId;

  const GhostModeOverlay({
    super.key,
    required this.child,
    required this.chatId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ghostMode = ref.watch(ghostModeProvider);

    if (!ghostMode.isActive) return child;

    return Stack(
      children: [
        child,
        // Ghost Mode indicator
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Режим призрака',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => ref.read(ghostModeProvider.notifier).endGhostPeek(),

                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Выйти',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Button to activate Ghost Mode
class GhostModeButton extends ConsumerWidget {
  final String chatId;

  const GhostModeButton({
    super.key,
    required this.chatId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ghostMode = ref.watch(ghostModeProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return IconButton(
      onPressed: () {
        if (ghostMode.isActive) {
          ref.read(ghostModeProvider.notifier).endGhostPeek();
        } else {
          ref.read(ghostModeProvider.notifier).startGhostPeek(chatId, '');
        }
      },

      icon: Icon(
        ghostMode.isActive ? Icons.visibility_off : Icons.visibility,
        color: ghostMode.isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
      ),
      tooltip: ghostMode.isActive ? 'Выйти из режима призрака' : 'Режим призрака',
    );
  }
}

/// Widget for peeking at chat without opening it (long press preview)
class GhostPeekView extends StatelessWidget {
  final String chatName;
  final String? lastMessage;
  final int unreadCount;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  const GhostPeekView({
    super.key,
    required this.chatName,
    this.lastMessage,
    required this.unreadCount,
    required this.onOpen,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        color: Colors.black.withOpacity(0.7),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ghost icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.visibility_off,
                    size: 30,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  chatName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Режим призрака - чтение без отметки',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 20),
                if (lastMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      lastMessage!,
                      style: const TextStyle(fontSize: 14),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                if (unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '$unreadCount непрочитанных',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onDismiss,
                        child: const Text('Закрыть'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: onOpen,
                        child: const Text('Открыть чат'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
