import 'package:flutter/material.dart';
import '../../core/models/reaction.dart';

class ReactionBar extends StatelessWidget {
  final List<ReactionGroup> reactions;
  final Function(String) onReactionTap;
  final VoidCallback onShowMore;

  const ReactionBar({
    super.key,
    required this.reactions,
    required this.onReactionTap,
    required this.onShowMore,
  });

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: reactions.map((reaction) {
        return _ReactionChip(
          reaction: reaction,
          onTap: () => onReactionTap(reaction.emoji),
        );
      }).toList(),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  final ReactionGroup reaction;
  final VoidCallback onTap;

  const _ReactionChip({
    required this.reaction,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = getReactionColor(reaction.emoji);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: reaction.isCurrentUser
                ? color.withValues(alpha: 0.15)
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: reaction.isCurrentUser
                  ? color.withValues(alpha: 0.5)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                reaction.emoji,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(width: 2),
              Text(
                '${reaction.count}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: reaction.isCurrentUser ? FontWeight.w600 : FontWeight.normal,
                  color: reaction.isCurrentUser ? color : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Панель выбора реакций (появляется при долгом нажатии)
class ReactionPicker extends StatelessWidget {
  final Function(String) onReactionSelected;
  final VoidCallback onClose;

  const ReactionPicker({
    super.key,
    required this.onReactionSelected,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: availableReactions.map((emoji) {
          return _ReactionButton(
            emoji: emoji,
            onTap: () {
              onReactionSelected(emoji);
              onClose();
            },
          );
        }).toList(),
      ),
    );
  }
}

class _ReactionButton extends StatefulWidget {
  final String emoji;
  final VoidCallback onTap;

  const _ReactionButton({
    required this.emoji,
    required this.onTap,
  });

  @override
  State<_ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<_ReactionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.all(8),
              child: Text(
                widget.emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          );
        },
      ),
    );
  }
}
