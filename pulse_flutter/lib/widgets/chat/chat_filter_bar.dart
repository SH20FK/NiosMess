import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/chat_filter_provider.dart';

/// Clean pill-shaped horizontal filter chips with Google Messages tonal styling.
class ChatFilterBar extends ConsumerWidget {
  const ChatFilterBar({super.key});

  static const List<ChatFilter> _orderedFilters = <ChatFilter>[
    ChatFilter.all,
    ChatFilter.unread,
    ChatFilter.direct,
    ChatFilter.groups,
    ChatFilter.channels,
    ChatFilter.bots,
  ];

  IconData _filterIcon(ChatFilter value) {
    return switch (value) {
      ChatFilter.all => Icons.all_inbox_rounded,
      ChatFilter.unread => Icons.mark_chat_unread_rounded,
      ChatFilter.direct => Icons.person_rounded,
      ChatFilter.groups => Icons.groups_rounded,
      ChatFilter.channels => Icons.campaign_rounded,
      ChatFilter.bots => Icons.smart_toy_rounded,
    };
  }

  String _filterLabel(BuildContext context, ChatFilter value) {
    return switch (value) {
      ChatFilter.all => context.l10n.chatListFilterAll,
      ChatFilter.unread => context.l10n.chatListFilterUnread,
      ChatFilter.direct => context.l10n.chatListFilterDirect,
      ChatFilter.groups => context.l10n.chatListFilterGroups,
      ChatFilter.channels => context.l10n.chatListFilterChannels,
      ChatFilter.bots => context.l10n.chatListFilterBots,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ChatFilter currentFilter = ref.watch(chatFilterProvider);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AsyncValue<List<ApiChatSummary>> chatsAsync = ref.watch(chatsProvider);

    final int totalUnread = chatsAsync.maybeWhen(
      data: (List<ApiChatSummary> chats) =>
          chats.fold<int>(0, (int sum, ApiChatSummary c) => sum + c.unreadCount),
      orElse: () => 0,
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: _orderedFilters.map((ChatFilter filter) {
          final bool selected = filter == currentFilter;
          final bool isUnreadChip = filter == ChatFilter.unread;

          final Color chipBg = selected
              ? scheme.secondaryContainer
              : scheme.surfaceContainerLow;
          final Color chipFg = selected
              ? scheme.onSecondaryContainer
              : scheme.onSurfaceVariant;
          final Color borderColor = selected
              ? scheme.secondary.withValues(alpha: 0.35)
              : scheme.outlineVariant.withValues(alpha: 0.22);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(_filterLabel(context, filter)),
                  if (isUnreadChip && totalUnread > 0) ...<Widget>[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? scheme.onSecondaryContainer
                            : scheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        totalUnread > 99 ? '99+' : '$totalUnread',
                        style: TextStyle(
                          color: selected
                              ? scheme.secondaryContainer
                              : scheme.onPrimary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              selected: selected,
              onSelected: (_) {
                HapticService.tap();
                ref.read(chatFilterProvider.notifier).updateFilter(filter);
              },
              avatar: Icon(
                _filterIcon(filter),
                size: 18,
                color: chipFg,
              ),
              showCheckmark: false,
              backgroundColor: chipBg,
              selectedColor: chipBg,
              labelStyle: TextStyle(
                color: chipFg,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13.5,
              ),
              side: BorderSide(color: borderColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}
