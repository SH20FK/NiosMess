import 'package:flutter/material.dart';

class MessageActionSheet extends StatelessWidget {
  const MessageActionSheet({
    super.key,
    required this.preview,
    required this.reactions,
    required this.quickActions,
    required this.ownActions,
    required this.dangerActions,
    this.reduceMotion = false,
  });

  final String preview;
  final Widget reactions;
  final List<MessageActionItem> quickActions;
  final List<MessageActionItem> ownActions;
  final List<MessageActionItem> dangerActions;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: scheme.outlineVariant,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          if (preview.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          const SizedBox(height: 12),
          reactions,
          const SizedBox(height: 12),
          _Section(title: 'Действия', items: quickActions),
          if (ownActions.isNotEmpty) ...[
            const SizedBox(height: 6),
            _Section(title: 'Сообщение', items: ownActions),
          ],
          if (dangerActions.isNotEmpty) ...[
            const SizedBox(height: 6),
            _Section(title: 'Опасные', items: dangerActions, isDanger: true),
          ],
        ],
      ),
    );

    if (reduceMotion) return content;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.95, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      builder: (context, value, child) => Transform.scale(
        scale: value,
        child: Opacity(opacity: value, child: child),
      ),
      child: content,
    );
  }
}

class MessageActionItem {
  const MessageActionItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.items,
    this.isDanger = false,
  });

  final String title;
  final List<MessageActionItem> items;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ),
          ),
          ...items.map((item) {
            final color = item.danger || isDanger ? scheme.error : scheme.onSurface;
            return ListTile(
              dense: true,
              leading: Icon(item.icon, color: color),
              title: Text(item.label, style: TextStyle(color: color)),
              onTap: item.onTap,
            );
          }).toList(),
        ],
      ),
    );
  }
}
