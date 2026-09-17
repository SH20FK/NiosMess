import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/motion/tri_sync.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/core/utils/datetime_helpers.dart';
import 'package:pulse_flutter/widgets/common/touch_container.dart';

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
    required this.onReport,
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
  final VoidCallback onReport;
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
            const SizedBox(height: 16),
            Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.3)),
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
              onReport: onReport,
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
    String previewText = message.content.trim();
    if (previewText.isEmpty) {
      if (message.isSticker) {
        final String emoji = message.sticker?.emoji.trim() ?? '';
        previewText = emoji.isNotEmpty ? '🖼️ Стикер $emoji' : '🖼️ Стикер';
      } else if (message.msgType == 'voice' ||
          (message.mediaType ?? '').toLowerCase().startsWith('audio/')) {
        previewText = '🎤 Голосовое сообщение';
      } else if (message.msgType == 'circle' ||
          message.msgType == 'circle_video' ||
          message.msgType == 'video_note') {
        previewText = '📹 Видеосообщение';
      } else if (message.hasMedia) {
        final String name = (message.mediaName ?? '').trim();
        previewText = name.isNotEmpty ? '📎 $name' : '📎 Вложение';
      }
    }

    final Widget? mediaIcon = message.isSticker
        ? Icon(Icons.emoji_emotions_rounded, size: 20, color: scheme.primary)
        : (message.mediaType != null && message.mediaType!.isNotEmpty)
            ? Icon(
                message.msgType == 'voice' ||
                        (message.mediaType ?? '')
                            .toLowerCase()
                            .startsWith('audio/')
                    ? Icons.mic_rounded
                    : message.msgType == 'circle'
                        ? Icons.videocam_rounded
                        : (message.msgType == 'image' ||
                                (message.mediaType ?? '').startsWith('image/'))
                            ? Icons.image_rounded
                            : (message.msgType == 'video' ||
                                    (message.mediaType ?? '')
                                        .startsWith('video/'))
                                ? Icons.videocam_rounded
                                : Icons.insert_drive_file_rounded,
                size: 18,
                color: scheme.primary,
              )
            : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
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
                if (previewText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      previewText,
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
          if (mediaIcon != null)
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: mediaIcon,
            ),
        ],
      ),
    );
  }
}

class _ReactionsRow extends ConsumerWidget {
  const _ReactionsRow({
    required this.scheme,
    required this.onReact,
    required this.onShowAllReactions,
  });

  final ColorScheme scheme;
  final void Function(String emoji) onReact;
  final VoidCallback onShowAllReactions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                TriSync.reaction(ref: ref, context: context);
                Navigator.of(context).pop();
                onReact(reaction.emoji);
              },
            ),
          ],
          _ReactionAddButton(scheme: scheme, onTap: () {
            TriSync.pop(ref: ref, context: context);
            Navigator.of(context).pop();
            onShowAllReactions();
          }),
        ],
      ),
    );
  }
}

class _ReactionButton extends StatefulWidget {
  const _ReactionButton({
    required this.emoji,
    required this.scheme,
    required this.onTap,
  });

  final String emoji;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  State<_ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<_ReactionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: M3Durations.short4,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.28).animate(
      CurvedAnimation(
        parent: _animController,
        curve: M3SpringCurves.bouncy,
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: TouchContainer(
        onTap: () {
          _animController.forward().then((_) {
            if (mounted) _animController.reverse();
          });
          widget.onTap();
        },
        borderRadius: BorderRadius.circular(22),
        width: 44,
        height: 44,
        scaleDown: 0.88,
        releaseCurve: M3SpringCurves.bouncy,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            ClipPath(
              clipper: M3Clipper(Shapes.flower),
              child: Container(
                width: 44,
                height: 44,
                color: widget.scheme.surfaceContainerHighest,
              ),
            ),
            Center(
              child: Text(widget.emoji, style: const TextStyle(fontSize: 22)),
            ),
          ],
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
    return TouchContainer(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      width: 44,
      height: 44,
      scaleDown: 0.88,
      releaseCurve: M3SpringCurves.bouncy,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          ClipPath(
            clipper: M3Clipper(Shapes.c9_sided_cookie),
            child: Container(
              width: 44,
              height: 44,
              color: scheme.primaryContainer,
            ),
          ),
          Center(
            child: Icon(Icons.add_rounded, size: 22, color: scheme.primary),
          ),
        ],
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
    required this.onReport,
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
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final List<_CompactAction> standardActions = _buildStandardActions(context);
    final List<_CompactAction> destructiveActions = _buildDestructiveActions(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (standardActions.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(6),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: standardActions
                  .map((a) => _CompactActionTile(action: a, scheme: scheme))
                  .toList(),
            ),
          ),
        if (destructiveActions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(6),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: destructiveActions
                  .map((a) => _CompactActionTile(
                        action: a,
                        scheme: scheme,
                        isDestructive: true,
                      ))
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }

  List<_CompactAction> _buildStandardActions(BuildContext context) {
    final List<_CompactAction> list = <_CompactAction>[];

    list.add(_CompactAction(
      icon: Icons.reply_rounded,
      label: context.l10n.chatReply,
      onTap: () {
        Navigator.of(context).pop();
        onReply();
      },
    ));

    if (message.content.trim().isNotEmpty && !message.isDeleted) {
      list.add(_CompactAction(
        icon: Icons.copy_rounded,
        label: context.l10n.chatCopyText,
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

    if (isMine &&
        !message.isDeleted &&
        (message.msgType == 'text' || message.content.trim().isNotEmpty)) {
      list.add(_CompactAction(
        icon: Icons.edit_rounded,
        label: context.l10n.chatEdit,
        onTap: () {
          Navigator.of(context).pop();
          onEdit();
        },
      ));
    }

    return list;
  }

  List<_CompactAction> _buildDestructiveActions(BuildContext context) {
    final List<_CompactAction> list = <_CompactAction>[];

    if (isMine || (amAdminOrOwner && !message.isDeleted)) {
      list.add(_CompactAction(
        icon: Icons.delete_outline_rounded,
        label: context.l10n.chatDelete,
        color: scheme.error,
        onTap: () {
          Navigator.of(context).pop();
          onDelete();
        },
      ));
    }

    if (!isMine && !message.isDeleted) {
      list.add(_CompactAction(
        icon: Icons.flag_rounded,
        label: context.l10n.reportAction,
        color: scheme.error,
        onTap: () {
          Navigator.of(context).pop();
          onReport();
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
  const _CompactActionTile({
    required this.action,
    required this.scheme,
    this.isDestructive = false,
  });

  final _CompactAction action;
  final ColorScheme scheme;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final Color effectiveColor =
        action.color ?? (isDestructive ? scheme.error : scheme.onSurface);
    final Color containerColor = isDestructive
        ? scheme.errorContainer.withValues(alpha: 0.35)
        : scheme.surfaceContainerHigh;
    final bool hasLabel = action.label != null;

    return TouchContainer(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(12),
      color: containerColor,
      padding: EdgeInsets.symmetric(
        horizontal: hasLabel ? 12 : 10,
        vertical: 8,
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
    );
  }
}
