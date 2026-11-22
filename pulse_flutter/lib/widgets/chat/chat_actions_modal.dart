import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/modal/app_modal.dart';
import 'package:pulse_flutter/core/theme/app_colors.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/chat_productivity.dart';
import 'package:pulse_flutter/widgets/chat/custom_emoji_text.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';

enum ChatActionResult { markRead, toggleMute, addToFolder, select, leave }

/// Unified descriptor for actions inside [ChatActionsModal].
class ChatActionDescriptor {
  const ChatActionDescriptor({
    required this.result,
    required this.label,
    required this.icon,
    this.enabled = true,
    this.isDestructive = false,
  });

  final ChatActionResult result;
  final String label;
  final IconData icon;
  final bool enabled;
  final bool isDestructive;
}

/// Unified Material 3 Expressive context actions modal for chats.
/// Strictly delegates presentation to [AppModal.showActions], providing
/// a consistent content contract across mobile sheets and desktop dialogs.
class ChatActionsModal {
  ChatActionsModal._();

  /// The sheet a long press opens (a centred dialog on wide windows). A right
  /// click gets a menu at the cursor instead; the inbox screen owns that one.
  static Future<ChatActionResult?> show(
    BuildContext context, {
    required ApiChatSummary chat,
    required Color avatarColor,
    bool isMuted = false,
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    final String type = chat.isSecret
        ? context.l10n.secretTitle
        : chat.isBotChat || chat.chatType == 'bot'
        ? context.l10n.chatListFilterBots
        : switch (chat.chatType) {
            'channel' => context.l10n.groupTypeChannel,
            'group' => context.l10n.groupTypeGroup,
            _ => context.l10n.chatListFilterDirect,
          };
    final String subtitle = chat.unreadCount <= 0
        ? type
        : '${context.l10n.chatListUnreadCount(chat.unreadCount)} • $type';

    // AppModal already insets the content by 16dp: the header adds none, so the
    // avatar starts at x=16 and the name at 16 + 44 + 12 = x=72 — the same line
    // as the action labels.
    final Widget header = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: <Widget>[
          PulseAvatar(
            radius: 22,
            name: chat.name,
            id: chat.id.toString(),
            avatarUrl: chat.avatarUrl,
            fallbackColor: avatarColor,
            textColor: AppColors.avatarTextColorFor(avatarColor, scheme),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  chat.name,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // "Mark read" stays in the list even when there is nothing to read: the
    // menu must not change height or shift the destructive row under the
    // cursor, so it renders disabled instead of being filtered out.
    final List<ChatActionDescriptor> descriptors = <ChatActionDescriptor>[
      ChatActionDescriptor(
        result: ChatActionResult.markRead,
        label: context.l10n.chatListMarkRead,
        icon: Icons.done_all_rounded,
        enabled: chat.unreadCount > 0,
      ),
      ChatActionDescriptor(
        result: ChatActionResult.toggleMute,
        label: isMuted
            ? context.l10n.profileUnmuteNotifications
            : context.l10n.profileMuteNotifications,
        icon: isMuted
            ? Icons.notifications_active_rounded
            : Icons.notifications_off_rounded,
      ),
      ChatActionDescriptor(
        result: ChatActionResult.addToFolder,
        label: context.l10n.inboxAddToFolder,
        icon: Icons.folder_outlined,
      ),
      // Starts multi-select with this chat already picked.
      ChatActionDescriptor(
        result: ChatActionResult.select,
        label: context.l10n.inboxSelect,
        icon: Icons.check_circle_outline_rounded,
      ),
    ];

    final List<Widget> actions = <Widget>[
      for (final ChatActionDescriptor descriptor in descriptors)
        _ChatActionRow(
          key: ValueKey<ChatActionResult>(descriptor.result),
          descriptor: descriptor,
          onSelected: () => Navigator.of(context).pop(descriptor.result),
        ),
    ];

    final bool isDirect = chat.chatType != 'group' && chat.chatType != 'channel';
    final Widget destructiveTile = _ChatActionRow(
      descriptor: ChatActionDescriptor(
        result: ChatActionResult.leave,
        label: isDirect ? context.l10n.chatDelete : context.l10n.chatListLeave,
        icon: isDirect ? Icons.delete_outline_rounded : Icons.logout_rounded,
        isDestructive: true,
      ),
      onSelected: () => Navigator.of(context).pop(ChatActionResult.leave),
    );

    return AppModal.showActions<ChatActionResult>(
      context: context,
      header: header,
      actions: <Widget>[
        ...actions,
        // Separates the safe actions from the destructive one without a second
        // container: 1dp outline at 22%, inset 12 to align with the labels.
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Divider(
            height: 1,
            thickness: 1,
            indent: 12,
            endIndent: 12,
            color: scheme.outlineVariant.withValues(alpha: 0.22),
          ),
        ),
      ],
      destructiveAction: destructiveTile,
    );
  }

  /// Folder picker for one chat. Returns the folder whose own list the chat
  /// is added to or taken out of.
  ///
  /// A folder that takes the chat by a type rule is listed checked and
  /// disabled: the rule puts the chat there, not the list.
  static Future<ChatFolder?> pickFolder(
    BuildContext context, {
    required ApiChatSummary chat,
    required List<ChatFolder> folders,
  }) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String type = chat.isBotChat ? 'bot' : chat.chatType;

    return AppModal.showActions<ChatFolder>(
      context: context,
      header: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Text(
          context.l10n.inboxAddToFolder,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      actions: <Widget>[
        for (final ChatFolder folder in folders)
          Builder(
            key: ValueKey<String>('chat-folder-pick-${folder.id}'),
            builder: (BuildContext _) {
              final bool listed = folder.chatIds.contains(chat.id);
              final bool byRule = !listed && folder.types.contains(type);
              return _ChatActionRow(
                descriptor: ChatActionDescriptor(
                  result: ChatActionResult.addToFolder,
                  label: folder.title,
                  icon: listed || byRule
                      ? Icons.check_circle_rounded
                      : Icons.folder_outlined,
                  enabled: !byRule,
                ),
                title: CustomEmojiText(folder.title, maxLines: 1),
                onSelected: () => Navigator.of(context).pop(folder),
              );
            },
          ),
      ],
    );
  }
}

/// One 48dp menu row: `labelLarge` copy, 20dp leading glyph, [AppShape.control]
/// corners, a press layer instead of fills. Destructive rows are error-tinted
/// only — no error container and no outline.
class _ChatActionRow extends StatelessWidget {
  const _ChatActionRow({
    required this.descriptor,
    required this.onSelected,
    this.title,
    super.key,
  });

  final ChatActionDescriptor descriptor;
  final VoidCallback onSelected;

  /// Shown instead of the plain label, in the same style: a folder title may
  /// carry custom emoji.
  final Widget? title;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final Color accent = descriptor.isDestructive
        ? scheme.error
        : scheme.onSurface;
    final Color foreground = descriptor.enabled
        ? accent
        : accent.withValues(alpha: 0.38);
    // One typeface for every row: labelLarge everywhere.
    final TextStyle labelStyle = (textTheme.labelLarge ?? const TextStyle())
        .copyWith(color: foreground);
    final Widget? title = this.title;

    return Semantics(
      button: true,
      enabled: descriptor.enabled,
      child: InkWell(
        customBorder: AppShape.controlBorder(),
        canRequestFocus: descriptor.enabled,
        onTap: descriptor.enabled ? onSelected : null,
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: <Widget>[
                Icon(descriptor.icon, size: 20, color: foreground),
                const SizedBox(width: 12),
                Expanded(
                  child: title != null
                      ? DefaultTextStyle.merge(
                          style: labelStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          child: title,
                        )
                      : Text(
                          descriptor.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: labelStyle,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
