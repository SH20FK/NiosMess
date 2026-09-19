import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/modal/app_modal.dart';
import 'package:pulse_flutter/core/theme/app_colors.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';

enum ChatActionResult {
  markRead,
  toggleMute,
  pin,
  archive,
  leave,
}

/// Unified Material 3 Expressive context actions modal for chats.
/// Strictly delegates presentation to [AppModal.showActions], providing
/// a consistent content contract across mobile sheets and desktop dialogs.
class ChatActionsModal {
  ChatActionsModal._();

  static Future<ChatActionResult?> show(
    BuildContext context, {
    required ApiChatSummary chat,
    required Color avatarColor,
    bool isMuted = false,
    bool isPinned = false,
    bool isArchived = false,
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    final String type = switch (chat.chatType) {
      'channel' => context.l10n.groupTypeChannel,
      'group' => context.l10n.groupTypeGroup,
      _ => context.l10n.chatListFilterDirect,
    };
    final String subtitle = chat.unreadCount <= 0
        ? type
        : '${context.l10n.chatListUnreadCount(chat.unreadCount)} • $type';

    final Widget header = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: <Widget>[
          PulseAvatar(
            radius: 22,
            name: chat.name,
            id: chat.id.toString(),
            avatarUrl: chat.avatarUrl,
            fallbackColor: avatarColor,
            textColor: AppColors.avatarTextColorFor(
              avatarColor,
              scheme,
            ),
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

    final List<Widget> actions = <Widget>[
      ListTile(
        leading: const Icon(Icons.done_all_rounded),
        title: Text(context.l10n.chatListMarkRead),
        onTap: () => Navigator.of(context).pop(ChatActionResult.markRead),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      ListTile(
        leading: Icon(isMuted
            ? Icons.notifications_active_rounded
            : Icons.notifications_off_rounded),
        title: Text(isMuted
            ? context.l10n.profileUnmuteNotifications
            : context.l10n.profileMuteNotifications),
        onTap: () => Navigator.of(context).pop(ChatActionResult.toggleMute),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      ListTile(
        leading: Icon(isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded),
        title: Text(isPinned ? 'Открепить чат' : 'Закрепить чат'),
        onTap: () => Navigator.of(context).pop(ChatActionResult.pin),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      ListTile(
        leading: Icon(isArchived ? Icons.unarchive_rounded : Icons.archive_rounded),
        title: Text(isArchived ? 'Извлечь из архива' : 'В архив'),
        onTap: () => Navigator.of(context).pop(ChatActionResult.archive),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ];

    final Widget destructiveTile = Container(
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.error.withValues(alpha: 0.2),
        ),
      ),
      child: ListTile(
        leading: Icon(Icons.delete_outline_rounded, color: scheme.error),
        title: Text(
          context.l10n.chatListLeave,
          style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600),
        ),
        onTap: () => Navigator.of(context).pop(ChatActionResult.leave),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    return AppModal.showActions<ChatActionResult>(
      context: context,
      header: header,
      actions: actions,
      destructiveAction: destructiveTile,
    );
  }
}
