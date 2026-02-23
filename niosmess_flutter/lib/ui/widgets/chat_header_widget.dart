import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../nios_ui.dart';

class ChatHeaderWidget extends StatelessWidget {
  final String title;
  final String? status;
  final String? chatType;
  final String? chatUsername;
  final Uint8List? avatarBytes;
  final String? badgeText;
  final String? badgeIcon;
  final int? queueCount;
  final bool? networkOnline;
  final bool reduceMotion;
  final String? heroTag;
  final VoidCallback onBack;
  final VoidCallback onSearch;
  final VoidCallback onCall;
  final VoidCallback onMenu;
  final VoidCallback? onAvatarTap;

  const ChatHeaderWidget({
    super.key,
    required this.title,
    this.status,
    this.chatType,
    this.chatUsername,
    this.avatarBytes,
    this.badgeText,
    this.badgeIcon,
    this.queueCount,
    this.networkOnline,
    this.reduceMotion = false,
    this.heroTag,
    required this.onBack,
    required this.onSearch,
    required this.onCall,
    required this.onMenu,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showAvatar = chatType == 'user';

    return Material(
      color: scheme.surface,
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: scheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Назад',
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: showAvatar ? onAvatarTap : null,
                borderRadius: BorderRadius.circular(24),
                child: Hero(
                  tag: heroTag ?? 'chat_avatar_$chatUsername',
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: scheme.surfaceVariant,
                    child: showAvatar &&
                            avatarBytes != null &&
                            avatarBytes!.isNotEmpty
                        ? ClipOval(
                            child: Image.memory(avatarBytes!,
                                fit: BoxFit.cover, width: 40, height: 40))
                        : Text(
                            title.characters.isNotEmpty
                                ? title.characters.first.toUpperCase()
                                : '?',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: showAvatar ? onAvatarTap : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if ((badgeText ?? '').isNotEmpty ||
                              (badgeIcon ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: NiosBadge(
                                icon: badgeIcon ?? '🦊',
                                tooltip: badgeText ??
                                    'Этот человек связан с разработкой',
                                size: 20,
                                reduceMotion: reduceMotion,
                              ),
                            ),
                        ],
                      ),
                      if (status != null && status!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          status!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: onSearch,
                icon: const Icon(Icons.search),
                tooltip: 'Поиск',
              ),
              IconButton(
                onPressed: onCall,
                icon: const Icon(Icons.phone),
                tooltip: 'Звонок',
              ),
              IconButton(
                onPressed: onMenu,
                icon: const Icon(Icons.more_vert),
                tooltip: 'Меню',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
