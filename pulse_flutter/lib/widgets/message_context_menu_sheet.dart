import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/tri_sync.dart';
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

/// Message context actions: quick reactions and a flat action list.
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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 2. Horizontal Quick Reactions (48dp touch targets, semantics, clean circles)
          _ReactionsRow(
            scheme: scheme,
            onReact: onReact,
            onShowAllReactions: onShowAllReactions,
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),

          // 3. Flat Action List
          ..._buildStandardActions(context, scheme),

          // 4. Destructive Action (separate last row on error tonal background)
          ..._buildDestructiveActions(context, scheme),
        ],
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

    // Copy text (with honest secret chat explanation if disabled)
    if (message.content.trim().isNotEmpty && !message.isDeleted) {
      if (isSecret) {
        list.add(_ActionListTile(
          icon: Icons.copy_rounded,
          title: context.l10n.chatCopyText,
          subtitle: 'Запрещено политикой секретного чата',
          enabled: false,
          onTap: () {},
        ));
      } else {
        list.add(_ActionListTile(
          icon: Icons.copy_rounded,
          title: context.l10n.chatCopyText,
          onTap: () {
            Navigator.of(context).pop(const MessageActionResult(MessageActionType.copy));
            onCopy?.call();
          },
        ));
      }
    }

    // Forward (with honest secret chat explanation if disabled)
    if (isSecret) {
      list.add(_ActionListTile(
        icon: Icons.forward_rounded,
        title: context.l10n.chatResendTo,
        subtitle: 'Пересылка недоступна в секретном чате',
        enabled: false,
        onTap: () {},
      ));
    } else {
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
      list.add(_ActionListTile(
            icon: Icons.delete_outline_rounded,
            title: context.l10n.chatDelete,
            color: scheme.error,
            onTap: () {
              Navigator.of(context).pop(const MessageActionResult(MessageActionType.delete));
              onDelete?.call();
            },
          ));
    } else {
      list.add(_ActionListTile(
            icon: Icons.flag_outlined,
            title: context.l10n.reportMessage,
            color: scheme.error,
            onTap: () {
              Navigator.of(context).pop(const MessageActionResult(MessageActionType.report));
              onReport?.call();
            },
          ));
    }

    return list;
  }
}

class _QuickReaction {
  const _QuickReaction({required this.emoji});
  final String emoji;
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
    return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          for (final reaction in MessageContextMenuSheet._quickReactions)
            Semantics(
              button: true,
              label: 'Реакция ${reaction.emoji}',
              child: TouchContainer(
                onTap: () {
                  TriSync.reaction(ref: ref, context: context);
                  Navigator.of(context).pop(MessageActionResult(MessageActionType.react, emoji: reaction.emoji));
                  onReact?.call(reaction.emoji);
                },
                borderRadius: BorderRadius.circular(24),
                width: 48,
                height: 48,
                child: Center(
                  child: Text(reaction.emoji, style: const TextStyle(fontSize: 22)),
                ),
              ),
            ),
          Semantics(
            button: true,
            label: 'Выбрать реакцию',
            child: TouchContainer(
              onTap: () {
                TriSync.pop(ref: ref, context: context);
                Navigator.of(context).pop(const MessageActionResult(MessageActionType.showAllReactions));
                onShowAllReactions?.call();
              },
              borderRadius: BorderRadius.circular(24),
              width: 48,
              height: 48,
              child: Center(
                child: Icon(Icons.add_rounded, size: 22, color: scheme.primary),
              ),
            ),
          ),
        ],
    );
  }
}

class _ActionListTile extends StatelessWidget {
  const _ActionListTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
    this.subtitle,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;
  final String? subtitle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color fg = !enabled
        ? scheme.onSurface.withValues(alpha: 0.38)
        : (color ?? scheme.onSurface);

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
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                fontSize: 11,
              ),
            )
          : null,
      enabled: enabled,
      visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: enabled
          ? () {
              HapticService.tap();
              onTap();
            }
          : null,
    );
  }
}
