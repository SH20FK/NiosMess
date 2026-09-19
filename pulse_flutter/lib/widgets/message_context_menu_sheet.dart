import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/tri_sync.dart';
import 'package:pulse_flutter/core/utils/datetime_helpers.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/widgets/common/touch_container.dart';

enum MessageActionType {
  react,
  showAllReactions,
  reply,
  copy,
  forward,
  comments,
  edit,
  delete,
  report,
}

class MessageActionResult {
  const MessageActionResult(this.type, {this.emoji});

  final MessageActionType type;
  final String? emoji;
}

/// Unified Material 3 Expressive message context actions modal.
/// Single surface, flat action list, real media/sticker thumbnails, and zero flower-clip noise.
class MessageContextMenuSheet extends StatelessWidget {
  const MessageContextMenuSheet({
    required this.message,
    required this.isMine,
    required this.isChannel,
    required this.amAdminOrOwner,
    this.onReact,
    this.onShowAllReactions,
    this.onReply,
    this.onCopy,
    this.onForward,
    this.onComments,
    this.onEdit,
    this.onDelete,
    this.onReport,
    this.isSecret = false,
    super.key,
  });

  final ApiMessage message;
  final bool isMine;
  final bool isChannel;
  final bool amAdminOrOwner;
  final void Function(String emoji)? onReact;
  final VoidCallback? onShowAllReactions;
  final VoidCallback? onReply;
  final VoidCallback? onCopy;
  final VoidCallback? onForward;
  final VoidCallback? onComments;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;
  final bool isSecret;

  static const List<_QuickReaction> _quickReactions = <_QuickReaction>[
    _QuickReaction(emoji: '👍'),
    _QuickReaction(emoji: '❤️'),
    _QuickReaction(emoji: '🔥'),
    _QuickReaction(emoji: '😂'),
    _QuickReaction(emoji: '🎉'),
    _QuickReaction(emoji: '👎'),
  ];

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      bottom: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // 1. Compact Message Preview with real thumbnail
            _MessagePreviewCard(message: message, isMine: isMine),
            const SizedBox(height: 10),

            // 2. Horizontal Quick Reactions (clean circles, no flower clips)
            _ReactionsRow(
              scheme: scheme,
              onReact: onReact,
              onShowAllReactions: onShowAllReactions,
            ),
            const SizedBox(height: 10),
            Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.2)),
            const SizedBox(height: 4),

            // 3. Flat Action List
            ..._buildStandardActions(context, scheme),

            // 4. Destructive Action (separate last row on error tonal background)
            ..._buildDestructiveActions(context, scheme),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStandardActions(BuildContext context, ColorScheme scheme) {
    final List<Widget> list = <Widget>[];

    // Reply
    list.add(_ActionListTile(
      icon: Icons.reply_rounded,
      title: context.l10n.chatReply,
      onTap: () {
        Navigator.of(context).pop(const MessageActionResult(MessageActionType.reply));
        onReply?.call();
      },
    ));

    // Copy text
    if (message.content.trim().isNotEmpty && !message.isDeleted) {
      list.add(_ActionListTile(
        icon: Icons.copy_rounded,
        title: context.l10n.chatCopyText,
        onTap: () {
          Navigator.of(context).pop(const MessageActionResult(MessageActionType.copy));
          onCopy?.call();
        },
      ));
    }

    // Forward
    if (!isSecret) {
      list.add(_ActionListTile(
        icon: Icons.forward_rounded,
        title: context.l10n.chatResendTo,
        onTap: () {
          Navigator.of(context).pop(const MessageActionResult(MessageActionType.forward));
          onForward?.call();
        },
      ));
    }

    // Comments for channel
    if (isChannel) {
      list.add(_ActionListTile(
        icon: Icons.forum_outlined,
        title: context.l10n.commentsTitle,
        onTap: () {
          Navigator.of(context).pop(const MessageActionResult(MessageActionType.comments));
          onComments?.call();
        },
      ));
    }

    // Edit (mine & text message)
    if (isMine && !message.isDeleted && message.content.trim().isNotEmpty) {
      list.add(_ActionListTile(
        icon: Icons.edit_outlined,
        title: context.l10n.chatEdit,
        onTap: () {
          Navigator.of(context).pop(const MessageActionResult(MessageActionType.edit));
          onEdit?.call();
        },
      ));
    }

    return list;
  }

  List<Widget> _buildDestructiveActions(BuildContext context, ColorScheme scheme) {
    final List<Widget> list = <Widget>[];

    if (isMine || amAdminOrOwner) {
      list.add(Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Container(
          decoration: BoxDecoration(
            color: scheme.errorContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.error.withValues(alpha: 0.2)),
          ),
          child: _ActionListTile(
            icon: Icons.delete_outline_rounded,
            title: context.l10n.chatDelete,
            color: scheme.error,
            onTap: () {
              Navigator.of(context).pop(const MessageActionResult(MessageActionType.delete));
              onDelete?.call();
            },
          ),
        ),
      ));
    } else {
      list.add(Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Container(
          decoration: BoxDecoration(
            color: scheme.errorContainer.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.error.withValues(alpha: 0.15)),
          ),
          child: _ActionListTile(
            icon: Icons.flag_outlined,
            title: context.l10n.reportMessage,
            color: scheme.error,
            onTap: () {
              Navigator.of(context).pop(const MessageActionResult(MessageActionType.report));
              onReport?.call();
            },
          ),
        ),
      ));
    }

    return list;
  }
}

class _QuickReaction {
  const _QuickReaction({required this.emoji});
  final String emoji;
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
        previewText = emoji.isNotEmpty ? 'Стикер $emoji' : 'Стикер';
      } else if (message.msgType == 'voice' ||
          (message.mediaType ?? '').toLowerCase().startsWith('audio/')) {
        previewText = 'Голосовое сообщение';
      } else if (message.msgType == 'circle' ||
          message.msgType == 'circle_video' ||
          message.msgType == 'video_note') {
        previewText = 'Видеосообщение';
      } else if (message.hasMedia) {
        final String name = (message.mediaName ?? '').trim();
        previewText = name.isNotEmpty ? name : 'Вложение';
      }
    }

    // Resolve real thumbnail for sticker or image
    Widget? thumbnail;
    if (message.isSticker && message.sticker?.resolvedUrl != null) {
      thumbnail = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: message.sticker!.resolvedUrl,
          width: 38,
          height: 38,
          fit: BoxFit.contain,
          errorWidget: (_, _, _) => Icon(Icons.sticky_note_2_rounded, size: 20, color: scheme.primary),
        ),
      );
    } else if (message.hasMedia &&
        message.mediaUrl != null &&
        (message.msgType == 'image' || (message.mediaType ?? '').startsWith('image/'))) {
      thumbnail = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: message.mediaUrl!,
          width: 38,
          height: 38,
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => Icon(Icons.image_rounded, size: 20, color: scheme.primary),
        ),
      );
    } else if (message.hasMedia) {
      final IconData iconData = message.msgType == 'voice' ||
              (message.mediaType ?? '').startsWith('audio/')
          ? Icons.mic_rounded
          : message.msgType == 'video' || (message.mediaType ?? '').startsWith('video/')
              ? Icons.videocam_rounded
              : Icons.insert_drive_file_rounded;
      thumbnail = Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Icon(iconData, size: 20, color: scheme.primary),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 3,
            height: 32,
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
                  Text(
                    previewText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  formatMessageTime(message.resolvedSentAt),
                  style: textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          if (thumbnail != null) ...<Widget>[
            const SizedBox(width: 8),
            thumbnail,
          ],
        ],
      ),
    );
  }
}

class _ReactionsRow extends ConsumerWidget {
  const _ReactionsRow({
    required this.scheme,
    this.onReact,
    this.onShowAllReactions,
  });

  final ColorScheme scheme;
  final void Function(String emoji)? onReact;
  final VoidCallback? onShowAllReactions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          for (final reaction in MessageContextMenuSheet._quickReactions)
            TouchContainer(
              onTap: () {
                TriSync.reaction(ref: ref, context: context);
                Navigator.of(context).pop(MessageActionResult(MessageActionType.react, emoji: reaction.emoji));
                onReact?.call(reaction.emoji);
              },
              borderRadius: BorderRadius.circular(18),
              width: 38,
              height: 38,
              child: Center(
                child: Text(reaction.emoji, style: const TextStyle(fontSize: 20)),
              ),
            ),
          TouchContainer(
            onTap: () {
              TriSync.pop(ref: ref, context: context);
              Navigator.of(context).pop(const MessageActionResult(MessageActionType.showAllReactions));
              onShowAllReactions?.call();
            },
            borderRadius: BorderRadius.circular(18),
            width: 38,
            height: 38,
            child: Center(
              child: Icon(Icons.add_rounded, size: 20, color: scheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionListTile extends StatelessWidget {
  const _ActionListTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color fg = color ?? scheme.onSurface;

    return ListTile(
      leading: Icon(icon, color: fg, size: 20),
      title: Text(
        title,
        style: TextStyle(
          color: fg,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: () {
        HapticService.tap();
        onTap();
      },
    );
  }
}
