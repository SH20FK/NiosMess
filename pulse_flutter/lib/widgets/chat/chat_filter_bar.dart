import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/chat_filter_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

/// Common filters stay visible; less frequent categories live in one menu.
/// Wrap keeps targets readable with large accessibility fonts.
class ChatFilterBar extends ConsumerWidget {
  const ChatFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(chatFilterProvider);
    final l = context.l10n;
    final types = <ChatFilter, String>{
      ChatFilter.direct: l.chatListFilterDirect,
      ChatFilter.groups: l.chatListFilterGroups,
      ChatFilter.channels: l.chatListFilterChannels,
      ChatFilter.bots: l.chatListFilterBots,
    };
    void select(ChatFilter value) {
      if (value == filter) return;
      if (ref.read(uiSettingsProvider.select((s) => s.haptics))) {
        HapticService.tap();
      }
      ref.read(chatFilterProvider.notifier).updateFilter(value);
    }

    Widget chip(ChatFilter value, String label) => FilterChip(
      label: Text(label),
      selected: filter == value,
      showCheckmark: false,
      onSelected: (_) => select(value),
    );

    return Wrap(
      spacing: 8,
      children: [
        chip(ChatFilter.all, l.chatListFilterAll),
        chip(ChatFilter.unread, l.chatListFilterUnread),
        MenuAnchor(
          menuChildren: [
            for (final entry in types.entries)
              MenuItemButton(
                leadingIcon: Icon(
                  filter == entry.key
                      ? Icons.check_rounded
                      : switch (entry.key) {
                          ChatFilter.direct => Icons.person_outline_rounded,
                          ChatFilter.groups => Icons.groups_outlined,
                          ChatFilter.channels => Icons.campaign_outlined,
                          _ => Icons.smart_toy_outlined,
                        },
                ),
                onPressed: () => select(entry.key),
                child: Text(entry.value),
              ),
          ],
          builder: (context, controller, child) => FilterChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(types[filter] ?? l.inboxChatType),
                const SizedBox(width: 2),
                const Icon(Icons.expand_more_rounded, size: 18),
              ],
            ),
            selected: types.containsKey(filter),
            showCheckmark: false,
            onSelected: (_) =>
                controller.isOpen ? controller.close() : controller.open(),
          ),
        ),
      ],
    );
  }
}
