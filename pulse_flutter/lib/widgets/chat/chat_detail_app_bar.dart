import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/widgets/profile/responsive_profile_sheet.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';

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
                  Hero(
                    tag: 'chat_avatar_$chatId',
                    child: PulseAvatar(
                      radius: 19,
                      name: title,
                      avatarUrl: avatarUrl,
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
                          color: const Color(0xFF4CAF50),
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
                        if (isVerified ||
                            directUsername?.toLowerCase() == 'support' ||
                            title.toLowerCase() == 'support') ...<Widget>[
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
          IconButton(
            onPressed: onSecurityTap,
            icon: Icon(
              Icons.security_rounded,
              color: scheme.primary,
            ),
            tooltip: context.l10n.e2eeEncryptionTitle,
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
            menuChildren: <Widget>[
              if (isGroup || isChannel) ...<Widget>[
                MenuItemButton(
                  leadingIcon: const Icon(Icons.people_rounded),
                  onPressed: () => context.push('/chat/$chatId/members'),
                  child: Text(context.l10n.chatMembers),
                ),
                MenuItemButton(
                  leadingIcon: const Icon(Icons.settings_rounded),
                  onPressed: () => context.push('/chat/$chatId/manage'),
                  child: Text(context.l10n.chatManage),
                ),
              ],
              MenuItemButton(
                leadingIcon: const Icon(Icons.texture_rounded),
                onPressed: () => context.push(
                  '/settings/wallpaper?chatId=$chatId&chatTitle=${Uri.encodeComponent(title)}',
                ),
                child: const Text('Обои чата'),
              ),
            ],
          ),
      ],
    );
  }
}
