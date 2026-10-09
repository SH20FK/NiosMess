import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/theme/app_colors.dart';
import 'package:pulse_flutter/models/api/status_emoji_model.dart';
import 'package:pulse_flutter/widgets/common/app_action_menu_item.dart';
import 'package:pulse_flutter/widgets/profile/responsive_profile_sheet.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/status_emoji_badge.dart';
import 'package:pulse_flutter/widgets/chat/security_status_chip.dart';

class ChatDetailAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChatDetailAppBar({
    super.key,
    required this.chatId,
    required this.isDesktopSplit,
    required this.title,
    this.avatarUrl,
    required this.headerIcon,
    required this.typingSubtitle,
    this.directUsername,
    this.statusEmoji,
    this.isGroup = false,
    this.isChannel = false,
    this.isSecret = false,
    this.autoDeleteDuration,
    this.isVerified = false,
    this.isBot = false,
    this.isOnline = false,
    required this.onBack,
    this.onVoiceCall,
    this.onVideoCall,
    this.onSecurityTap,
    this.onAutoDeleteTap,
  });

  final int chatId;
  final bool isDesktopSplit;
  final String title;
  final String? avatarUrl;
  final IconData headerIcon;
  final Widget typingSubtitle;
  final String? directUsername;
  final ApiStatusEmoji? statusEmoji;
  final bool isGroup;
  final bool isChannel;
  final bool isSecret;
  final String? autoDeleteDuration;
  final bool isVerified;
  final bool isBot;
  final bool isOnline;
  final VoidCallback onBack;
  final VoidCallback? onVoiceCall;
  final VoidCallback? onVideoCall;
  final VoidCallback? onSecurityTap;
  final VoidCallback? onAutoDeleteTap;

  bool get _showCallButtons =>
      !isSecret &&
      !isChannel &&
      !isBot &&
      (onVoiceCall != null || onVideoCall != null);
  bool get _showOverflowMenu => true;

  @override
  Size get preferredSize => Size.fromHeight(isSecret ? 80 : kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return AppBar(
      backgroundColor: scheme.surfaceContainerLow.withValues(alpha: 0.92),
      elevation: 0,
      scrolledUnderElevation: 0,

      automaticallyImplyLeading: false,
      centerTitle: false,
      leadingWidth: 48,
      toolbarHeight: isSecret ? 80 : kToolbarHeight,
      leading: isDesktopSplit
          ? null
          : IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
      titleSpacing: isDesktopSplit ? NavigationToolbar.kMiddleSpacing : 0,
      title: InkWell(
        onTap: () {
          if (directUsername != null) {
            openResponsiveProfile(context, username: directUsername!);
          } else if (isGroup || isChannel) {
            openResponsiveGroupProfile(context, chatId: chatId);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Row(
            children: <Widget>[
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  HeroMode(
                    enabled: !isDesktopSplit,
                    child: Hero(
                      tag: 'chat_avatar_$chatId',
                      child: PulseAvatar(
                        radius: 19,
                        name: title,
                        id: chatId.toString(),
                        avatarUrl: avatarUrl,
                      ),
                    ),
                  ),
                  if (isOnline && !isGroup && !isChannel)
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.statusOnline,
                          shape: BoxShape.circle,
                          border: Border.all(color: scheme.surface, width: 2),
                        ),
                      ),
                    )
                  else
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 15,
                        height: 15,
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: scheme.surface, width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          headerIcon,
                          size: 11,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            title,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: isSecret ? 1.2 : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (statusEmoji != null) ...<Widget>[
                          StatusEmojiBadge(emoji: statusEmoji!, size: 16),
                        ],
                        if (isVerified) ...<Widget>[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.verified_rounded,
                            size: 16,
                            color: scheme.primary,
                          ),
                        ],
                        if (!isSecret &&
                            autoDeleteDuration != null) ...<Widget>[
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: onAutoDeleteTap,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isSecret
                                    ? scheme.secondaryContainer.withValues(
                                        alpha: 0.7,
                                      )
                                    : scheme.primaryContainer.withValues(
                                        alpha: 0.7,
                                      ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    Icons.timer_outlined,
                                    size: 11,
                                    color: isSecret
                                        ? scheme.onSecondaryContainer
                                        : scheme.onPrimaryContainer,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    autoDeleteDuration!,
                                    style: textTheme.labelSmall?.copyWith(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isSecret
                                          ? scheme.onSecondaryContainer
                                          : scheme.onPrimaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (isSecret)
                      Text(
                        context.l10n.secretTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.2,
                        ),
                      )
                    else
                      typingSubtitle,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        if (isSecret)
          SecurityStatusChip(
            chatId: chatId,
            compact: true,
            onTap: onSecurityTap ?? () {},
          ),
        if (_showCallButtons) ...[
          IconButton(
            onPressed: onVoiceCall,
            icon: const Icon(Icons.phone_rounded),
            tooltip: context.l10n.callIncomingVoice,
          ),
          IconButton(
            onPressed: onVideoCall,
            icon: const Icon(Icons.videocam_rounded),
            tooltip: context.l10n.callIncomingVideo,
          ),
        ],
        if (_showOverflowMenu)
          MenuAnchor(
            crossAxisUnconstrained: false,
            style: MenuStyle(
              maximumSize: WidgetStatePropertyAll<Size>(
                Size(MediaQuery.sizeOf(context).width - 24, double.infinity),
              ),
            ),
            builder:
                (
                  BuildContext context,
                  MenuController controller,
                  Widget? child,
                ) {
                  return IconButton(
                    icon: const Icon(Icons.more_vert_rounded),
                    onPressed: () {
                      if (controller.isOpen) {
                        controller.close();
                      } else {
                        controller.open();
                      }
                    },
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).moreButtonTooltip,
                  );
                },
            menuChildren: AppActionMenuItem.buildItems(context, <
              AppActionMenuItem
            >[
              if (isSecret && !isBot && onVoiceCall != null)
                AppActionMenuItem(
                  label: context.l10n.chatVoiceCall,
                  icon: Icons.phone_rounded,
                  onPressed: onVoiceCall,
                ),
              if (isSecret && !isBot && onVideoCall != null)
                AppActionMenuItem(
                  label: context.l10n.chatVideoCall,
                  icon: Icons.videocam_rounded,
                  onPressed: onVideoCall,
                ),
              if (isSecret)
                AppActionMenuItem(
                  label: context.l10n.autoDeleteTitle,
                  icon: autoDeleteDuration == null
                      ? Icons.timer_outlined
                      : Icons.timer_rounded,
                  onPressed: onAutoDeleteTap,
                ),
              if (isGroup || isChannel) ...<AppActionMenuItem>[
                AppActionMenuItem(
                  label: context.l10n.chatMembers,
                  icon: Icons.people_rounded,
                  onPressed: () => context.push('/chat/$chatId/members'),
                ),
                AppActionMenuItem(
                  label: context.l10n.chatManage,
                  icon: Icons.settings_rounded,
                  onPressed: () => context.push('/chat/$chatId/manage'),
                ),
              ],
              AppActionMenuItem(
                label: context.l10n.chatWallpaperMenu,
                icon: Icons.texture_rounded,
                onPressed: () => context.push(
                  '/settings/wallpaper?chatId=$chatId&chatTitle=${Uri.encodeComponent(title)}',
                ),
              ),
            ]),
          ),
      ],
    );
  }
}
