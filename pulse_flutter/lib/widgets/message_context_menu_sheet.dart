import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/models/api/message_model.dart';

class MessageContextMenuSheet extends StatelessWidget {
  const MessageContextMenuSheet({
    required this.message,
    required this.isMine,
    required this.isChannel,
    required this.amAdminOrOwner,
    required this.onReact,
    required this.onReply,
    required this.onForward,
    required this.onComments,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final ApiMessage message;
  final bool isMine;
  final bool isChannel;
  final bool amAdminOrOwner;
  final void Function(String emoji) onReact;
  final VoidCallback onReply;
  final VoidCallback onForward;
  final VoidCallback onComments;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Reactions Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <String>['👍', '❤️', '🔥', '😂', '🎉', '👎']
                    .map(
                      (String emoji) => GestureDetector(
                        onTap: () {
                          HapticService.tap();
                          Navigator.of(context).pop();
                          onReact(emoji);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: scheme.surfaceContainerHighest,
                          ),
                          child: Text(emoji, style: const TextStyle(fontSize: 24)),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
            const SizedBox(height: 16),
            // Actions
            Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.2),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _ActionTile(
                      icon: Icons.reply_rounded,
                      title: context.l10n.chatReply,
                      onTap: () {
                        Navigator.of(context).pop();
                        onReply();
                      },
                    ),
                    const Divider(height: 1),
                    _ActionTile(
                      icon: Icons.forward_rounded,
                      title: context.l10n.chatResendTo,
                      onTap: () {
                        Navigator.of(context).pop();
                        onForward();
                      },
                    ),
                    if (isChannel) ...<Widget>[
                      const Divider(height: 1),
                      _ActionTile(
                        icon: Icons.forum_outlined,
                        title: context.l10n.chatComments,
                        subtitle: message.commentsCount > 0
                            ? context.l10n.chatCommentsCount(message.commentsCount)
                            : null,
                        onTap: () {
                          Navigator.of(context).pop();
                          onComments();
                        },
                      ),
                    ],
                    if (isMine && message.msgType == 'text' && !message.isDeleted) ...<Widget>[
                      const Divider(height: 1),
                      _ActionTile(
                        icon: Icons.edit_rounded,
                        title: context.l10n.chatEdit,
                        onTap: () {
                          Navigator.of(context).pop();
                          onEdit();
                        },
                      ),
                    ],
                    if (isMine || (amAdminOrOwner && !message.isDeleted)) ...<Widget>[
                      const Divider(height: 1),
                      _ActionTile(
                        icon: Icons.delete_outline_rounded,
                        title: context.l10n.chatDelete,
                        color: scheme.error,
                        onTap: () {
                          Navigator.of(context).pop();
                          onDelete();
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color effectiveColor = color ?? scheme.onSurface;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: <Widget>[
            Icon(icon, color: effectiveColor, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: textTheme.titleMedium?.copyWith(
                      color: effectiveColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
