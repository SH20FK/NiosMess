import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/theme/app_colors.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/common/touch_container.dart';

enum ChatActionResult {
  markRead,
  leave,
}

/// Unified Material 3 Expressive context actions modal for chats.
/// Provides a cohesive, tonal surface across mobile bottom sheets and desktop dialogs.
class ChatActionsModal extends StatelessWidget {
  const ChatActionsModal({
    required this.chat,
    required this.avatarColor,
    this.isDesktop = false,
    super.key,
  });

  final ApiChatSummary chat;
  final Color avatarColor;
  final bool isDesktop;

  static Future<ChatActionResult?> show(
    BuildContext context, {
    required ApiChatSummary chat,
    required Color avatarColor,
  }) {
    final bool isWide =
        MediaQuery.sizeOf(context).width >= Breakpoints.medium;

    if (isWide) {
      return showDialog<ChatActionResult>(
        context: context,
        builder: (BuildContext ctx) => Dialog(
          backgroundColor: Theme.of(ctx).colorScheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: Theme.of(ctx).colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          elevation: 0,
          child: SizedBox(
            width: 360,
            child: ChatActionsModal(
              chat: chat,
              avatarColor: avatarColor,
              isDesktop: true,
            ),
          ),
        ),
      );
    }

    return AppBottomSheets.show<ChatActionResult>(
      context: context,
      builder: (BuildContext ctx) => ChatActionsModal(
        chat: chat,
        avatarColor: avatarColor,
        isDesktop: false,
      ),
    );
  }

  String _subtitle(BuildContext context) {
    final String type = switch (chat.chatType) {
      'channel' => context.l10n.groupTypeChannel,
      'group' => context.l10n.groupTypeGroup,
      _ => context.l10n.chatListFilterDirect,
    };
    if (chat.unreadCount <= 0) return type;
    return '${context.l10n.chatListUnreadCount(chat.unreadCount)} • $type';
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return SafeArea(
      top: false,
      bottom: !isDesktop,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, isDesktop ? 16 : 8, 16, isDesktop ? 16 : 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Chat preview header row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDesktop
                    ? scheme.surfaceContainerHighest.withValues(alpha: 0.5)
                    : scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
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
                          _subtitle(context),
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
            ),
            const SizedBox(height: 12),

            // Actions list
            Container(
              decoration: BoxDecoration(
                color: isDesktop
                    ? scheme.surfaceContainerHighest.withValues(alpha: 0.3)
                    : scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.16),
                ),
              ),
              child: Column(
                children: <Widget>[
                  _ActionTile(
                    icon: Icons.done_all_rounded,
                    title: context.l10n.chatListMarkRead,
                    subtitle: context.l10n.chatListMarkReadSubtitle,
                    onTap: () => Navigator.of(context).pop(ChatActionResult.markRead),
                    scheme: scheme,
                    textTheme: textTheme,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Destructive action
            Container(
              decoration: BoxDecoration(
                color: scheme.errorContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: scheme.error.withValues(alpha: 0.2),
                ),
              ),
              child: _ActionTile(
                icon: Icons.delete_outline_rounded,
                title: context.l10n.chatListLeave,
                subtitle: context.l10n.chatListLeaveSubtitle,
                onTap: () => Navigator.of(context).pop(ChatActionResult.leave),
                scheme: scheme,
                textTheme: textTheme,
                isDestructive: true,
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
    required this.onTap,
    required this.scheme,
    required this.textTheme,
    this.subtitle,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final Color fg = isDestructive ? scheme.error : scheme.onSurface;
    final Color iconBg = isDestructive
        ? scheme.error.withValues(alpha: 0.14)
        : scheme.primary.withValues(alpha: 0.12);
    final Color iconColor = isDestructive ? scheme.error : scheme.primary;

    return TouchContainer(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
                if ((subtitle ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: textTheme.bodySmall?.copyWith(
                      color: isDestructive
                          ? scheme.error.withValues(alpha: 0.8)
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
