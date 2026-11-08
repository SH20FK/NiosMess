import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/chat_filter_provider.dart';
import 'package:pulse_flutter/providers/chat_productivity_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/motion/m3_selection_motion.dart';

/// Unified single-row Material 3 Expressive Morphing Tab Bar.
///
/// Features soft squircle pill capsules with spatial spring animation,
/// full-width touch targets, and seamlessly integrated category menus.
class ChatFilterBar extends ConsumerWidget {
  const ChatFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(chatFilterProvider);
    final folders = ref.watch(chatFoldersProvider).value ?? [];
    final selectedFolder = ref.watch(selectedChatFolderProvider);
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final types = <ChatFilter, String>{
      ChatFilter.direct: l.chatListFilterDirect,
      ChatFilter.channels: l.chatListFilterChannels,
      ChatFilter.bots: l.chatListFilterBots,
    };

    void select(ChatFilter value) {
      if (value == filter && selectedFolder == null) return;
      if (ref.read(uiSettingsProvider.select((s) => s.haptics))) {
        HapticService.selection();
      }
      ref.read(selectedChatFolderProvider.notifier).select(null);
      ref.read(chatFilterProvider.notifier).updateFilter(value);
    }

    void selectFolder(String folderId) {
      if (selectedFolder == folderId) return;
      if (ref.read(uiSettingsProvider.select((s) => s.haptics))) {
        HapticService.selection();
      }
      ref.read(chatFilterProvider.notifier).updateFilter(ChatFilter.all);
      ref.read(selectedChatFolderProvider.notifier).select(folderId);
    }

    Widget animatedChip({
      required bool selected,
      required Widget child,
      Key? key,
    }) => M3SelectionMotion(
      key: key,
      selected: selected,
      child: child,
    );

    Widget chip(ChatFilter value, String label) {
      final isSelected = filter == value && selectedFolder == null;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: animatedChip(
          key: ValueKey('chat-filter-${value.name}'),
          selected: isSelected,
          child: FilterChip(
            label: Text(label),
            showCheckmark: false,
            selected: isSelected,
            onSelected: (_) => select(value),
            color: WidgetStateProperty.resolveWith<Color?>((states) {
              if (states.contains(WidgetState.selected)) {
                return scheme.primaryContainer;
              }
              return scheme.surfaceContainerLow.withValues(alpha: 0.6);
            }),
            labelStyle: textTheme.labelLarge?.copyWith(
              color: isSelected
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
            side: BorderSide(
              color: isSelected
                  ? scheme.primary.withValues(alpha: 0.4)
                  : scheme.outlineVariant.withValues(alpha: 0.25),
              width: 1.0,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          ),
        ),
      );
    }

    final isTypeSelected = types.containsKey(filter);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Row(
        children: [
          chip(ChatFilter.all, l.chatListFilterAll),
          chip(ChatFilter.unread, l.chatListFilterUnread),
          chip(ChatFilter.groups, l.chatListFilterGroups),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: MenuAnchor(
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
                selected: isTypeSelected,
                child: FilterChip(
                  tooltip: l.inboxChatType,
                  showCheckmark: false,
                  selected: isTypeSelected,
                  onSelected: (_) {
                    if (controller.isOpen) {
                      controller.close();
                    } else {
                      controller.open();
                    }
                  },
                  color: WidgetStateProperty.resolveWith<Color?>((states) {
                    if (states.contains(WidgetState.selected)) {
                      return scheme.primaryContainer;
                    }
                    return scheme.surfaceContainerLow.withValues(alpha: 0.6);
                  }),
                  labelStyle: textTheme.labelLarge?.copyWith(
                    color: isTypeSelected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                    fontWeight: isTypeSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  side: BorderSide(
                    color: isTypeSelected
                        ? scheme.primary.withValues(alpha: 0.4)
                        : scheme.outlineVariant.withValues(alpha: 0.25),
                    width: 1.0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        types[filter] ?? l.inboxChatType,
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 18,
                        color: isTypeSelected
                            ? scheme.onPrimaryContainer
                            : scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // User Folders seamlessly integrated in the same row
          for (final folder in folders)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: animatedChip(
                key: ValueKey('chat-filter-folder-${folder.id}'),
                selected: selectedFolder == folder.id,
                child: FilterChip(
                  showCheckmark: false,
                  selected: selectedFolder == folder.id,
                  onSelected: (_) => selectFolder(folder.id),
                  avatar: Icon(
                    Icons.folder_rounded,
                    size: 16,
                    color: selectedFolder == folder.id
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                  color: WidgetStateProperty.resolveWith<Color?>((states) {
                    if (states.contains(WidgetState.selected)) {
                      return scheme.primaryContainer;
                    }
                    return scheme.surfaceContainerLow.withValues(alpha: 0.6);
                  }),
                  labelStyle: textTheme.labelLarge?.copyWith(
                    color: selectedFolder == folder.id
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                    fontWeight: selectedFolder == folder.id ? FontWeight.w700 : FontWeight.w500,
                  ),
                  side: BorderSide(
                    color: selectedFolder == folder.id
                        ? scheme.primary.withValues(alpha: 0.4)
                        : scheme.outlineVariant.withValues(alpha: 0.25),
                    width: 1.0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  label: Text(folder.title),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
