import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/providers/chat_filter_provider.dart';

class ChatListFilterBar extends ConsumerWidget {
  const ChatListFilterBar({super.key});

  IconData _filterIcon(ChatFilter value) {
    return switch (value) {
      ChatFilter.all => Icons.inbox_rounded,
      ChatFilter.unread => Icons.mark_chat_unread_rounded,
      ChatFilter.groups => Icons.groups_rounded,
      ChatFilter.channels => Icons.campaign_rounded,
      ChatFilter.direct => Icons.person_rounded,
      ChatFilter.bots => Icons.smart_toy_rounded,
    };
  }

  String _filterLabel(BuildContext context, ChatFilter value) {
    return switch (value) {
      ChatFilter.all => context.l10n.chatListFilterAll,
      ChatFilter.unread => context.l10n.chatListFilterUnread,
      ChatFilter.groups => context.l10n.chatListFilterGroups,
      ChatFilter.channels => context.l10n.chatListFilterChannels,
      ChatFilter.direct => context.l10n.chatListFilterDirect,
      ChatFilter.bots => context.l10n.chatListFilterBots,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ChatFilter currentFilter = ref.watch(chatFilterProvider);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: ChatFilter.values.map((ChatFilter filter) {
          final bool selected = filter == currentFilter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(_filterLabel(context, filter)),
              selected: selected,
              onSelected: (_) {
                ref.read(chatFilterProvider.notifier).updateFilter(filter);
              },
              avatar: Icon(
                _filterIcon(filter),
                size: 18,
              ),
              showCheckmark: false,
              selectedColor: scheme.primaryContainer,
              checkmarkColor: scheme.onPrimaryContainer,
              labelStyle: TextStyle(
                color: selected
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
              side: BorderSide(
                color: selected
                    ? scheme.primary.withValues(alpha: 0.28)
                    : scheme.outlineVariant.withValues(alpha: 0.22),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
