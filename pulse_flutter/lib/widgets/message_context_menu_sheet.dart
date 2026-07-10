import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/core/utils/datetime_helpers.dart';

class MessageContextMenuSheet extends StatelessWidget {
  const MessageContextMenuSheet({
    required this.message,
    required this.isMine,
    required this.isChannel,
    required this.amAdminOrOwner,
    required this.onReact,
    required this.onShowAllReactions,
    required this.onReply,
    required this.onCopy,
    required this.onForward,
    required this.onComments,
    required this.onEdit,
    required this.onDelete,
    this.isSecret = false,
    super.key,
  });

  final ApiMessage message;
  final bool isMine;
  final bool isChannel;
  final bool amAdminOrOwner;
  final void Function(String emoji) onReact;
  final VoidCallback onShowAllReactions;
  final VoidCallback onReply;
  final VoidCallback onCopy;
  final VoidCallback onForward;
  final VoidCallback onComments;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isSecret;

  static const List<_QuickReaction> _quickReactions = <_QuickReaction>[
    _QuickReaction(emoji: '👍', icon: Icons.thumb_up_rounded),
    _QuickReaction(emoji: '❤️', icon: Icons.favorite_rounded),
    _QuickReaction(emoji: '🔥', icon: Icons.whatshot_rounded),
    _QuickReaction(emoji: '😂', icon: Icons.emoji_emotions_rounded),
    _QuickReaction(emoji: '🎉', icon: Icons.celebration_rounded),
    _QuickReaction(emoji: '👎', icon: Icons.thumb_down_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      bottom: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _MessagePreviewCard(message: message, isMine: isMine),
            const SizedBox(height: 16),
            _ReactionsRow(
              scheme: scheme,
              onReact: onReact,
              onShowAllReactions: onShowAllReactions,
            ),
            const SizedBox(height: 12),
            _ActionsList(
              message: message,
              isMine: isMine,
              isChannel: isChannel,
              amAdminOrOwner: amAdminOrOwner,
              isSecret: isSecret,
              scheme: scheme,
              onReply: onReply,
              onCopy: onCopy,
              onForward: onForward,
              onComments: onComments,
              onEdit: onEdit,
              onDelete: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickReaction {
  const _QuickReaction({required this.emoji, required this.icon});
  final String emoji;
  final IconData icon;
}

class _MessagePreviewCard extends StatelessWidget {
  const _MessagePreviewCard({required this.message, required this.isMine});

  final ApiMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool hasText = message.content.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              color: isMine ? scheme.primary : scheme.secondary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (hasText)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      message.content,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        height: 1.3,
                      ),
                    ),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      isMine ? Icons.check_rounded : Icons.person_rounded,
                      size: 12,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      formatMessageTime(message.resolvedSentAt),
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (message.mediaType != null && message.mediaType!.isNotEmpty)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(
                message.msgType == 'voice'
                    ? Icons.mic_rounded
                    : message.msgType == 'circle'
                        ? Icons.videocam_rounded
                        : message.msgType == 'image'
                            ? Icons.image_rounded
                            : Icons.insert_drive_file_rounded,
                size: 20,
                color: scheme.primary,
              ),
            ),
        ],
      ),
    );
  }
}

class _ReactionsRow extends StatelessWidget {
  const _ReactionsRow({
    required this.scheme,
    required this.onReact,
    required this.onShowAllReactions,
  });

  final ColorScheme scheme;
  final void Function(String emoji) onReact;
  final VoidCallback onShowAllReactions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          for (final reaction in MessageContextMenuSheet._quickReactions) ...<Widget>[
            _ReactionButton(
              emoji: reaction.emoji,
              icon: reaction.icon,
              scheme: scheme,
              onTap: () {
                HapticService.tap();
                Navigator.of(context).pop();
                onReact(reaction.emoji);
              },
            ),
          ],
          _ReactionAddButton(scheme: scheme, onTap: () {
            HapticService.tap();
            Navigator.of(context).pop();
            onShowAllReactions();
          }),
        ],
      ),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({
    required this.emoji,
    required this.icon,
    required this.scheme,
    required this.onTap,
  });

  final String emoji;
  final IconData icon;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.surfaceContainerHighest,
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.04),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Center(
          child: Text(emoji, style: const TextStyle(fontSize: 20)),
        ),
      ),
    );
  }
}

class _ReactionAddButton extends StatelessWidget {
  const _ReactionAddButton({required this.scheme, required this.onTap});

  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.primaryContainer.withValues(alpha: 0.5),
        ),
        child: Icon(Icons.add_rounded, size: 22, color: scheme.primary),
      ),
    );
  }
}

class _ActionsList extends StatelessWidget {
  const _ActionsList({
    required this.message,
    required this.isMine,
    required this.isChannel,
    required this.amAdminOrOwner,
    required this.isSecret,
    required this.scheme,
    required this.onReply,
    required this.onCopy,
    required this.onForward,
    required this.onComments,
    required this.onEdit,
    required this.onDelete,
  });

  final ApiMessage message;
  final bool isMine;
  final bool isChannel;
  final bool amAdminOrOwner;
  final bool isSecret;
  final ColorScheme scheme;
  final VoidCallback onReply;
  final VoidCallback onCopy;
  final VoidCallback onForward;
  final VoidCallback onComments;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final List<_ActionItem> actions = <_ActionItem>[
      _ActionItem(
        icon: Icons.reply_rounded,
        title: context.l10n.chatReply,
        onTap: () {
          Navigator.of(context).pop();
          onReply();
        },
      ),
      if (message.msgType == 'text' && !message.isDeleted)
        _ActionItem(
          icon: Icons.copy_rounded,
          title: context.l10n.chatCopyText,
          onTap: () {
            Navigator.of(context).pop();
            onCopy();
          },
        ),
      if (!isSecret)
        _ActionItem(
          icon: Icons.forward_rounded,
          title: context.l10n.chatResendTo,
          onTap: () {
            Navigator.of(context).pop();
            onForward();
          },
        ),
      if (isChannel)
        _ActionItem(
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
      if (isMine && message.msgType == 'text' && !message.isDeleted)
        _ActionItem(
          icon: Icons.edit_rounded,
          title: context.l10n.chatEdit,
          onTap: () {
            Navigator.of(context).pop();
            onEdit();
          },
        ),
      if (isMine || (amAdminOrOwner && !message.isDeleted))
        _ActionItem(
          icon: Icons.delete_outline_rounded,
          title: context.l10n.chatDelete,
          color: scheme.error,
          onTap: () {
            Navigator.of(context).pop();
            onDelete();
          },
        ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.15),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 0; i < actions.length; i++) ...<Widget>[
              _ActionTile(
                icon: actions[i].icon,
                title: actions[i].title,
                subtitle: actions[i].subtitle,
                color: actions[i].color,
                onTap: actions[i].onTap,
                scheme: scheme,
              ),
              if (i < actions.length - 1)
                Divider(
                  height: 1,
                  indent: 56,
                  endIndent: 16,
                  color: scheme.outlineVariant.withValues(alpha: 0.12),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionItem {
  const _ActionItem({
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
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.color,
    required this.onTap,
    required this.scheme,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? color;
  final VoidCallback onTap;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color effectiveColor = color ?? scheme.onSurface;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: effectiveColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: effectiveColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: textTheme.bodyLarge?.copyWith(
                      color: effectiveColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 1),
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
            Icon(
              Icons.chevron_right_rounded,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
