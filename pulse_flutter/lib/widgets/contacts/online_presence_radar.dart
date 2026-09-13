import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/core/services/favorite_contacts_service.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';

/// Horizontal radar carousel showing active and recent contacts with online presence
class OnlinePresenceRadar extends ConsumerWidget {
  const OnlinePresenceRadar({
    required this.directChats,
    super.key,
  });

  final List<ApiChatSummary> directChats;

  void _showContactQuickActions(
    BuildContext context,
    WidgetRef ref,
    ApiChatSummary chat,
  ) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isFav =
        ref.read(favoriteContactsProvider).contains(chat.id);

    AppBottomSheets.show<void>(
      context: context,
      builder: (BuildContext ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Contact header
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: PulseAvatar(
                  radius: 22,
                  name: chat.name,
                  avatarUrl: chat.avatarUrl,
                ),
                title: Text(
                  chat.name,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: chat.username != null && chat.username!.isNotEmpty
                    ? Text('@${chat.username}')
                    : null,
                trailing: IconButton(
                  onPressed: () {
                    ref
                        .read(favoriteContactsProvider.notifier)
                        .toggleFavorite(chat.id);
                    Navigator.of(ctx).pop();
                  },
                  icon: Icon(
                    isFav ? Icons.star_rounded : Icons.star_border_rounded,
                    color: isFav ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                  tooltip: isFav
                      ? 'Удалить из избранных'
                      : 'Добавить в избранное',
                ),
              ),
              const Divider(height: 16),

              // Action buttons
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.chat_bubble_outline_rounded,
                      color: scheme.primary, size: 20),
                ),
                title: const Text('Открыть чат'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.push('/chat/${chat.id}');
                },
              ),
              if (chat.username != null && chat.username!.isNotEmpty) ...<Widget>[
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.phone_rounded,
                        color: scheme.primary, size: 20),
                  ),
                  title: const Text('Голосовой вызов'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    context.push('/call/dm/${chat.username}?isVideo=0');
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.videocam_rounded,
                        color: scheme.secondary, size: 20),
                  ),
                  title: const Text('Видеозвонок'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    context.push('/call/dm/${chat.username}?isVideo=1');
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.person_outline_rounded,
                        color: scheme.onSurfaceVariant, size: 20),
                  ),
                  title: const Text('Информация о контакте'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    context.push('/contact/${chat.username}');
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    // Filter active contacts (exclude bots)
    final List<ApiChatSummary> activeContacts = directChats
        .where((ApiChatSummary c) => !c.isBotChat)
        .take(15)
        .toList(growable: false);

    if (activeContacts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.history_rounded,
                size: 17,
                color: scheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Недавние диалоги',
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${activeContacts.length}',
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 98,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            scrollDirection: Axis.horizontal,
            itemCount: activeContacts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (BuildContext context, int index) {
              final ApiChatSummary chat = activeContacts[index];

              return InkWell(
                onTap: () {
                  if (ref.read(uiSettingsProvider).haptics) {
                    HapticService.tap();
                  }
                  context.push('/chat/${chat.id}');
                },
                onLongPress: () {
                  if (ref.read(uiSettingsProvider).haptics) {
                    HapticService.confirm();
                  }
                  _showContactQuickActions(context, ref, chat);
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // Avatar with optional unread indicator
                      Stack(
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: scheme.primary.withValues(alpha: 0.25),
                                width: 1.5,
                              ),
                            ),
                            child: PulseAvatar(
                              radius: 24,
                              name: chat.name,
                              avatarUrl: chat.avatarUrl,
                            ),
                          ),
                          if (chat.unreadCount > 0)
                            Positioned(
                              right: -1,
                              top: -1,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.primary,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: scheme.surface,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  chat.unreadCount > 99
                                      ? '99+'
                                      : '${chat.unreadCount}',
                                  style: TextStyle(
                                    color: scheme.onPrimary,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // First name or short title
                      SizedBox(
                        width: 66,
                        child: Text(
                          chat.name.split(' ').first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
