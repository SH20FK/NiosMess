import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/providers/chat_filter_provider.dart';

class ChatListFilterBar extends ConsumerStatefulWidget {
  const ChatListFilterBar({super.key});

  @override
  ConsumerState<ChatListFilterBar> createState() => _ChatListFilterBarState();
}

class _ChatListFilterBarState extends ConsumerState<ChatListFilterBar>
    with SingleTickerProviderStateMixin {
  late final TabController _filterController;

  @override
  void initState() {
    super.initState();
    _filterController = TabController(
      length: ChatFilter.values.length,
      vsync: this,
    );
    _filterController.index = ref.read(chatFilterProvider).index;
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

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

  String _filterShortLabel(BuildContext context, ChatFilter value) {
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: 48,
      child: TabBar(
        controller: _filterController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        onTap: (int index) {
          ref.read(chatFilterProvider.notifier).updateFilter(
              ChatFilter.values[index]);
        },
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(28),
        ),
        labelColor: scheme.onPrimaryContainer,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 14),
        splashBorderRadius: BorderRadius.circular(28),
        tabs: ChatFilter.values
            .map(
              (ChatFilter value) => Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(_filterIcon(value), size: 18),
                    const SizedBox(width: 7),
                    Text(_filterShortLabel(context, value)),
                  ],
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}
