import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/theme/app_colors.dart';
import 'package:pulse_flutter/models/api/status_emoji_model.dart';
import 'package:pulse_flutter/services/e2ee_service.dart';
import 'package:pulse_flutter/widgets/common/app_action_menu_item.dart';
import 'package:pulse_flutter/widgets/profile/responsive_profile_sheet.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/status_emoji_badge.dart';

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

  bool get _showCallButtons =>
      !isChannel && !isBot && (onVoiceCall != null || onVideoCall != null);
  bool get _showOverflowMenu => true;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return AppBar(
      backgroundColor: scheme.surfaceContainerLow.withValues(alpha: 0.92),
      elevation: 0,
      scrolledUnderElevation: 0,

      leading: isDesktopSplit
          ? null
          : IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
      titleSpacing: isDesktopSplit
          ? NavigationToolbar.kMiddleSpacing
          : 0,
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
                          border: Border.all(
                            color: scheme.surface,
                            width: 2,
                          ),
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
                          border: Border.all(
                            color: scheme.surface,
                            width: 1.5,
                          ),
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
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSecret) ...<Widget>[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.lock_rounded,
                            size: 14,
                            color: scheme.tertiary,
                          ),
                        ],
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
                        if (autoDeleteDuration != null) ...<Widget>[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  scheme.primaryContainer.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  Icons.timer_outlined,
                                  size: 11,
                                  color: scheme.onPrimaryContainer,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  autoDeleteDuration!,
                                  style: textTheme.labelSmall?.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onPrimaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
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
          Consumer(
            builder: (BuildContext context, WidgetRef ref, _) {
              final E2eeService e2ee = ref.watch(e2eeServiceProvider);
              return ValueListenableBuilder<int>(
                valueListenable: e2ee.revision,
                builder: (BuildContext context, int _, Widget? child) {
                  final E2eeSessionStatus status = e2ee.getSessionStatus(chatId);
                  final bool isPeerVerified = e2ee.isPeerVerified(chatId);

                  Color iconColor;
                  IconData iconData;
                  String tooltip;

                  switch (status) {
                    case E2eeSessionStatus.compromised:
                      iconColor = scheme.error;
                      iconData = Icons.gpp_bad_rounded;
                      tooltip = 'Внимание: угроза безопасности!';
                      break;
                    case E2eeSessionStatus.connecting:
                      iconColor = scheme.primary;
                      iconData = Icons.sync_lock_rounded;
                      tooltip = 'Double Ratchet: установка...';
                      break;
                    case E2eeSessionStatus.secured:
                      if (isPeerVerified) {
                        iconColor = scheme.tertiary;
                        iconData = Icons.verified_user_rounded;
                        tooltip = 'Double Ratchet: верифицирован';
                      } else {
                        iconColor = scheme.primary;
                        iconData = Icons.security_rounded;
                        tooltip = 'Double Ratchet: защищено';
                      }
                      break;
                    case E2eeSessionStatus.none:
                      iconColor = scheme.onSurfaceVariant;
                      iconData = Icons.lock_clock_rounded;
                      tooltip = context.l10n.e2eeEncryptionTitle;
                      break;
                  }

                  return IconButton(
                    onPressed: onSecurityTap,
                    icon: Icon(iconData, color: iconColor),
                    tooltip: tooltip,
                  );
                },
              );
            },
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
            builder: (BuildContext context, MenuController controller, Widget? child) {
              return IconButton(
                icon: const Icon(Icons.more_vert_rounded),
                onPressed: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
                tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
              );
            },
            menuChildren: AppActionMenuItem.buildItems(
              context,
              <AppActionMenuItem>[
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
              ],
            ),
          ),
      ],
    );
  }
}
