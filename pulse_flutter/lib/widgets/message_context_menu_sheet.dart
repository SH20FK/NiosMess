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
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _MessagePreviewCard(message: message, isMine: isMine),
            const SizedBox(height: 12),
            _ReactionsRow(
              scheme: scheme,
              onReact: onReact,
              onShowAllReactions: onShowAllReactions,
            ),
            const SizedBox(height: 12),
            _ActionsCompact(
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 3,
            height: 42,
            decoration: BoxDecoration(
              color: isMine ? scheme.primary : scheme.secondary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (hasText)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      message.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(height: 1.3),
                    ),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      isMine ? Icons.check_rounded : Icons.person_rounded,
                      size: 11,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      formatMessageTime(message.resolvedSentAt),
                      style: textTheme.labelSmall?.copyWith(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (message.mediaType != null && message.mediaType!.isNotEmpty)
            Container(
              width: 36,
              height: 36,
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
                size: 18,
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          for (final reaction in MessageContextMenuSheet._quickReactions) ...<Widget>[
            _ReactionButton(
              emoji: reaction.emoji,
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
    required this.scheme,
    required this.onTap,
  });

  final String emoji;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.surfaceContainerHighest,
        ),
        child: Center(
          child: Text(emoji, style: const TextStyle(fontSize: 18)),
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
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.primaryContainer.withValues(alpha: 0.4),
        ),
        child: Icon(Icons.add_rounded, size: 20, color: scheme.primary),
      ),
    );
  }
}

class _ActionsCompact extends StatelessWidget {
  const _ActionsCompact({
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
    final List<_CompactAction> actions = _buildActions(context);

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: actions.map((a) => _CompactActionTile(action: a, scheme: scheme)).toList(),
        ),
      ),
    );
  }

  List<_CompactAction> _buildActions(BuildContext context) {
    final List<_CompactAction> list = <_CompactAction>[];

    list.add(_CompactAction(
      icon: Icons.reply_rounded,
      label: context.l10n.chatReply,
      onTap: () {
        Navigator.of(context).pop();
        onReply();
      },
    ));

    if (message.msgType == 'text' && !message.isDeleted) {
      list.add(_CompactAction(
        icon: Icons.copy_rounded,
        label: null,
        onTap: () {
          Navigator.of(context).pop();
          onCopy();
        },
      ));
    }

    if (!isSecret) {
      list.add(_CompactAction(
        icon: Icons.forward_rounded,
        label: context.l10n.chatResendTo,
        onTap: () {
          Navigator.of(context).pop();
          onForward();
        },
      ));
    }

    if (isChannel) {
      list.add(_CompactAction(
        icon: Icons.forum_outlined,
        label: context.l10n.chatComments,
        subtitle: message.commentsCount > 0
            ? context.l10n.chatCommentsCount(message.commentsCount)
            : null,
        onTap: () {
          Navigator.of(context).pop();
          onComments();
        },
      ));
    }

    if (isMine && message.msgType == 'text' && !message.isDeleted) {
      list.add(_CompactAction(
        icon: Icons.edit_rounded,
        label: context.l10n.chatEdit,
        onTap: () {
          Navigator.of(context).pop();
          onEdit();
        },
      ));
    }

    if (isMine || (amAdminOrOwner && !message.isDeleted)) {
      list.add(_CompactAction(
        icon: Icons.delete_outline_rounded,
        label: null,
        color: scheme.error,
        onTap: () {
          Navigator.of(context).pop();
          onDelete();
        },
      ));
    }

    return list;
  }
}

class _CompactAction {
  const _CompactAction({
    required this.icon,
    this.label,
    this.subtitle,
    this.color,
    required this.onTap,
  });

  final IconData icon;
  final String? label;
  final String? subtitle;
  final Color? color;
  final VoidCallback onTap;
}

class _CompactActionTile extends StatelessWidget {
  const _CompactActionTile({required this.action, required this.scheme});

  final _CompactAction action;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final Color effectiveColor = action.color ?? scheme.onSurface;
    final bool hasLabel = action.label != null;

    return InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: hasLabel ? 12 : 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: effectiveColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(action.icon, size: 20, color: effectiveColor),
            if (hasLabel) ...[
              const SizedBox(width: 6),
              Text(
                action.label!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: effectiveColor,
                ),
              ),
            ],
            if (action.subtitle != null && hasLabel) ...[
              const SizedBox(width: 4),
              Text(
                action.subtitle!,
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
