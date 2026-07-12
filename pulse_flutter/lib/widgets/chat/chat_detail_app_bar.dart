import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
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
    required this.onBack,
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
  final VoidCallback onBack;

  bool get _showOverflowMenu => isGroup || isChannel;

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
            context.push('/profile/$directUsername');
          } else if (isGroup || isChannel) {
            context.push('/chat/$chatId/profile');
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
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(999),
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
                    Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
        if (_showOverflowMenu)
          PopupMenuButton<String>(
            onSelected: (String action) {
              switch (action) {
                case 'members':
                  context.push('/chat/$chatId/members');
                case 'manage':
                  context.push('/chat/$chatId/manage');
              }
            },
            itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'members',
                child: Row(
                  children: <Widget>[
                    Icon(Icons.people_rounded),
                    SizedBox(width: 8),
                    Text(context.l10n.chatMembers),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'manage',
                child: Row(
                  children: <Widget>[
                    Icon(Icons.settings_rounded),
                    SizedBox(width: 8),
                    Text(context.l10n.chatManage),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}
