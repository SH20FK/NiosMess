import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/widgets/motion/m3_selection_motion.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/chat_filter_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

/// Common filters stay visible; less frequent categories live in one menu.
/// Horizontal scrolling keeps targets readable with large accessibility fonts.
class ChatFilterBar extends ConsumerWidget {
  const ChatFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(chatFilterProvider);
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final types = <ChatFilter, String>{
      ChatFilter.direct: l.chatListFilterDirect,
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

    Widget animatedChip({
      required bool selected,
      required Widget child,
      required VoidCallback onTap,
      Key? key,
    }) => M3SelectionMotion(
      key: key,
      selected: selected,
      child: GestureDetector(
        // The underline lives inside the chip's column, so the tap target must
        // cover both the chip and the 3dp indicator below it.
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            child,
            AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : M3Durations.short4,
              curve: M3SpringCurves.gentle,
              width: selected ? 30 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ),
    );

    Widget chip(ChatFilter value, String label) => animatedChip(
      key: ValueKey('chat-filter-${value.name}'),
      selected: filter == value,
      onTap: () => select(value),
      child: FilterChip(
        label: Text(label),
        color: const WidgetStatePropertyAll<Color>(Colors.transparent),
        labelStyle: TextStyle(
          color: filter == value ? scheme.primary : scheme.onSurfaceVariant,
          fontWeight: filter == value ? FontWeight.w700 : FontWeight.w500,
        ),
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelPadding: const EdgeInsets.symmetric(horizontal: 5),
        selected: filter == value,
        showCheckmark: false,
        onSelected: (_) => select(value),
      ),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          chip(ChatFilter.all, l.chatListFilterAll),
          chip(ChatFilter.unread, l.chatListFilterUnread),
          chip(ChatFilter.groups, l.chatListFilterGroups),
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
            builder: (context, controller, child) => animatedChip(
              key: const ValueKey('chat-filter-type'),
              selected: types.containsKey(filter),
              onTap: () =>
                  controller.isOpen ? controller.close() : controller.open(),
              child: FilterChip(
                tooltip: l.inboxChatType,
                color: const WidgetStatePropertyAll<Color>(Colors.transparent),
                labelStyle: TextStyle(
                  color: types.containsKey(filter)
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                  fontWeight: types.containsKey(filter)
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
                side: BorderSide.none,
                shape: const StadiumBorder(),
                labelPadding: const EdgeInsets.symmetric(horizontal: 5),
                // Keep "Chat type" in the label even when a category is
                // selected: an icon-only or category-only chip hides what the
                // menu actually does.
                label: Text(
                  types.containsKey(filter)
                      ? '${l.inboxChatType} · ${types[filter]}'
                      : l.inboxChatType,
                ),
                selected: types.containsKey(filter),
                showCheckmark: false,
                onSelected: (_) =>
                    controller.isOpen ? controller.close() : controller.open(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
