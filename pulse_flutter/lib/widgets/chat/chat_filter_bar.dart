import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/widgets/motion/m3_selection_motion.dart';
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
      Key? key,
    }) => M3SelectionMotion(key: key, selected: selected, child: child);

    Widget chip(ChatFilter value, String label) => animatedChip(
      key: ValueKey('chat-filter-${value.name}'),
      selected: filter == value,
      child: FilterChip(
        label: Text(label),
        color: WidgetStateProperty.resolveWith<Color>(
          (states) => states.contains(WidgetState.selected)
              ? scheme.secondaryContainer
              : Colors.transparent,
        ),
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelPadding: const EdgeInsets.symmetric(horizontal: 5),
        selected: filter == value,
        showCheckmark: false,
        onSelected: (_) => select(value),
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: SingleChildScrollView(
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
                child: FilterChip(
                  tooltip: l.inboxChatType,
                  color: WidgetStateProperty.resolveWith<Color>(
                    (states) => states.contains(WidgetState.selected)
                        ? scheme.secondaryContainer
                        : Colors.transparent,
                  ),
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 5),
                  label: types.containsKey(filter)
                      ? Text(types[filter]!)
                      : const Icon(Icons.tune_rounded, size: 20),
                  selected: types.containsKey(filter),
                  showCheckmark: false,
                  onSelected: (_) => controller.isOpen
                      ? controller.close()
                      : controller.open(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
