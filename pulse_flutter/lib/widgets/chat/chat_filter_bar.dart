import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/chat_productivity.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/chat_filter_provider.dart';
import 'package:pulse_flutter/providers/chat_muted_provider.dart';
import 'package:pulse_flutter/providers/chat_productivity_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/chat/custom_emoji_text.dart';
import 'package:pulse_flutter/widgets/chat_productivity.dart'
    show openChatFolders;

/// Inbox scope strip: exactly one 40 dp row.
///
/// Two axes used to compete for the same space (chat types and folders), which
/// produced a duplicated, jittery pair of rows. The strip now has a single row
/// and one trailing "⋯" menu:
///
/// * folders configured → `[Все] [folder…] [⋯]`, chat types live in the menu;
/// * no folders → `[Все] [Непрочитанные] [Группы] [⋯]`, the remaining types
///   (channels / direct / bots) live in the menu.
///
/// "Все" resets both axes (folder + type), so it can never advertise a wider
/// result set than the list actually shows.
class ChatFilterBar extends ConsumerWidget {
  const ChatFilterBar({super.key, this.compact = false});

  /// Compact density (`UiSettingsState.compactMode`): 36 dp control height.
  final bool compact;

  /// Distance between two pills (M3 chip gap).
  static const double _pillGap = 8;

  /// Horizontal inset of the strip. The screen no longer pads the row from the
  /// outside: containers start at x = 16, matching the app bar title column.
  static const double _rowInset = 16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final ChatFilter filter = ref.watch(chatFilterProvider);
    final AsyncValue<List<ChatFolder>> foldersValue = ref.watch(
      chatFoldersProvider,
    );
    final List<ChatFolder> folders = foldersValue.value ?? const <ChatFolder>[];
    final String? selectedFolderId = ref.watch(selectedChatFolderProvider);
    final bool hasFolders = folders.isNotEmpty;

    // Chat data is only needed for the per-folder unread badge; without folders
    // the strip must not subscribe to the chat list at all.
    final List<ApiChatSummary> chats = hasFolders
        ? ref.watch(chatsProvider).value ?? const <ApiChatSummary>[]
        : const <ApiChatSummary>[];
    final Set<int> mutedChats = hasFolders
        ? ref.watch(chatMuteHubProvider).value ?? const <int>{}
        : const <int>{};

    final bool haptics = ref.read(uiSettingsProvider).haptics;

    void selectFilter(ChatFilter value) {
      if (value == filter) return;
      if (haptics) HapticService.tap();
      ref.read(chatFilterProvider.notifier).updateFilter(value);
    }

    void selectFolder(String? id) {
      if (haptics) HapticService.tap();
      ref.read(selectedChatFolderProvider.notifier).select(id);
    }

    void resetAll() {
      if (filter == ChatFilter.all && selectedFolderId == null) return;
      if (haptics) HapticService.tap();
      ref.read(chatFilterProvider.notifier).updateFilter(ChatFilter.all);
      ref.read(selectedChatFolderProvider.notifier).select(null);
    }

    final double rowHeight = _resolveRowHeight(context);

    final List<Widget> items = <Widget>[
      _FilterPill(
        key: const ValueKey<String>('chat-filter-all'),
        label: Text(l.chatListFilterAll),
        selected: filter == ChatFilter.all && selectedFolderId == null,
        minHeight: rowHeight,
        onTap: resetAll,
      ),
      if (hasFolders)
        for (final ChatFolder folder in folders)
          _buildFolderPill(
            folder: folder,
            selected: selectedFolderId == folder.id,
            minHeight: rowHeight,
            unread: _folderUnread(
              folder: folder,
              chats: chats,
              muted: mutedChats,
            ),
            onTap: () =>
                selectFolder(selectedFolderId == folder.id ? null : folder.id),
            onLongPress: () => openChatFolders(context),
          )
      else ...<Widget>[
        _FilterPill(
          key: const ValueKey<String>('chat-filter-unread'),
          label: Text(l.chatListFilterUnread),
          selected: filter == ChatFilter.unread,
          minHeight: rowHeight,
          onTap: () => selectFilter(ChatFilter.unread),
        ),
        _FilterPill(
          key: const ValueKey<String>('chat-filter-groups'),
          label: Text(l.chatListFilterGroups),
          selected: filter == ChatFilter.groups,
          minHeight: rowHeight,
          onTap: () => selectFilter(ChatFilter.groups),
        ),
      ],
      _FilterMenu(
        key: const ValueKey<String>('chat-filter-more'),
        current: filter,
        minHeight: rowHeight,
        // A menu-only type is active: show a dot so the row never silently
        // disagrees with the list.
        highlight: switch (filter) {
          ChatFilter.all => false,
          ChatFilter.unread || ChatFilter.groups => hasFolders,
          ChatFilter.channels || ChatFilter.direct || ChatFilter.bots => true,
        },
        onSelect: selectFilter,
        onManageFolders: () => openChatFolders(context),
      ),
    ];

    return SizedBox(
      height: rowHeight,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: _rowInset),
        child: Row(
          children: <Widget>[
            for (int i = 0; i < items.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: _pillGap),
              items[i],
            ],
          ],
        ),
      ),
    );
  }

  /// 40 dp (36 dp compact), growing only when the text scale needs it.
  double _resolveRowHeight(BuildContext context) {
    final double base = compact ? 36 : 40;
    final double scaledLabel = MediaQuery.textScalerOf(context).scale(20);
    return math.max(base, scaledLabel + 8);
  }

  Widget _buildFolderPill({
    required ChatFolder folder,
    required bool selected,
    required double minHeight,
    required ({int unread, bool alert}) unread,
    required VoidCallback onTap,
    required VoidCallback onLongPress,
  }) {
    return _FilterPill(
      key: ValueKey<String>('chat-filter-folder-${folder.id}'),
      label: CustomEmojiText(folder.title, maxLines: 1),
      selected: selected,
      minHeight: minHeight,
      badgeCount: unread.unread,
      badgeAlert: unread.alert,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }

  /// Unread total of a folder plus whether any unread chat is not muted.
  ///
  /// VK-style pill: the badge is tinted `primary` only when a muted chat is not
  /// the sole reason for the count.
  ({int unread, bool alert}) _folderUnread({
    required ChatFolder folder,
    required List<ApiChatSummary> chats,
    required Set<int> muted,
  }) {
    int unread = 0;
    bool alert = false;
    for (final ApiChatSummary chat in chats) {
      if (chat.unreadCount <= 0 || !folder.includes(chat)) continue;
      unread += chat.unreadCount;
      if (!muted.contains(chat.id)) alert = true;
    }
    return (unread: unread, alert: alert);
  }
}

/// Stadium pill used for every control in the inbox scope strip.
///
/// The weight is fixed at `w600` on purpose: swapping 500 ↔ 700 on selection
/// changes the intrinsic width and makes the whole row jump sideways.
class _FilterPill extends StatelessWidget {
  const _FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.minHeight,
    required this.onTap,
    this.onLongPress,
    this.badgeCount,
    this.badgeAlert = false,
  });

  final Widget label;
  final bool selected;
  final double minHeight;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final int? badgeCount;
  final bool badgeAlert;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final int? count = badgeCount;
    final bool showBadge = count != null && count > 0;

    final TextStyle textStyle =
        (theme.textTheme.labelLarge ??
                const TextStyle(fontSize: 14, letterSpacing: 0.1))
            .copyWith(
              fontWeight: FontWeight.w600,
              color: selected
                  ? scheme.onSecondaryContainer
                  : scheme.onSurfaceVariant,
            );

    return Semantics(
      button: true,
      selected: selected,
      container: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 200),
          curve: M3SpringCurves.gentle,
          constraints: BoxConstraints(minHeight: minHeight),
          padding: EdgeInsets.only(
            left: 16,
            right: showBadge ? 10 : 16,
            top: 4,
            bottom: 4,
          ),
          decoration: ShapeDecoration(
            color: selected
                ? scheme.secondaryContainer
                : scheme.surfaceContainerLow,
            shape: StadiumBorder(
              side: BorderSide(
                color: selected
                    ? Colors.transparent
                    : scheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DefaultTextStyle.merge(
                style: textStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: label,
              ),
              if (showBadge) ...<Widget>[
                const SizedBox(width: 6),
                _PillBadge(count: count, alert: badgeAlert),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact unread counter inside a folder pill (VK model).
class _PillBadge extends StatelessWidget {
  const _PillBadge({required this.count, required this.alert});

  final int count;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: alert ? scheme.primary : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        maxLines: 1,
        style:
            (theme.textTheme.labelSmall ??
                    const TextStyle(fontSize: 11, letterSpacing: 0.5))
                .copyWith(
                  fontWeight: FontWeight.w600,
                  color: alert ? scheme.onPrimary : scheme.onSurfaceVariant,
                ),
      ),
    );
  }
}

/// The trailing "⋯" pill: every chat type plus folder management.
class _FilterMenu extends StatelessWidget {
  const _FilterMenu({
    super.key,
    required this.current,
    required this.minHeight,
    required this.highlight,
    required this.onSelect,
    required this.onManageFolders,
  });

  final ChatFilter current;
  final double minHeight;
  final bool highlight;
  final ValueChanged<ChatFilter> onSelect;
  final VoidCallback onManageFolders;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

    final List<({ChatFilter value, String label, IconData icon})> types =
        <({ChatFilter value, String label, IconData icon})>[
          (
            value: ChatFilter.all,
            label: l.chatListFilterAll,
            icon: Icons.forum_outlined,
          ),
          (
            value: ChatFilter.unread,
            label: l.chatListFilterUnread,
            icon: Icons.mark_email_unread_outlined,
          ),
          (
            value: ChatFilter.groups,
            label: l.chatListFilterGroups,
            icon: Icons.groups_outlined,
          ),
          (
            value: ChatFilter.channels,
            label: l.chatListFilterChannels,
            icon: Icons.campaign_outlined,
          ),
          (
            value: ChatFilter.direct,
            label: l.chatListFilterDirect,
            icon: Icons.person_outline_rounded,
          ),
          (
            value: ChatFilter.bots,
            label: l.chatListFilterBots,
            icon: Icons.smart_toy_outlined,
          ),
        ];

    return MenuAnchor(
      menuChildren: <Widget>[
        for (final entry in types)
          MenuItemButton(
            leadingIcon: Icon(
              current == entry.value ? Icons.check_rounded : entry.icon,
              size: 20,
              color: current == entry.value ? scheme.primary : null,
            ),
            onPressed: () => onSelect(entry.value),
            child: Text(entry.label),
          ),
        const Divider(height: 9, indent: 12, endIndent: 12),
        MenuItemButton(
          leadingIcon: const Icon(Icons.folder_outlined, size: 20),
          onPressed: onManageFolders,
          child: Text(l.inboxFolders),
        ),
      ],
      builder:
          (BuildContext context, MenuController controller, Widget? child) {
            final bool open = controller.isOpen;
            return Semantics(
              button: true,
              label: l.inboxChatType,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => open ? controller.close() : controller.open(),
                child: AnimatedContainer(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                  curve: M3SpringCurves.gentle,
                  // Square target: the overflow control must read as a control,
                  // not as a text pill.
                  constraints: BoxConstraints.tightFor(
                    width: minHeight,
                    height: minHeight,
                  ),
                  decoration: ShapeDecoration(
                    color: open
                        ? scheme.secondaryContainer
                        : scheme.surfaceContainerLow,
                    shape: StadiumBorder(
                      side: BorderSide(
                        color: open
                            ? Colors.transparent
                            : scheme.outlineVariant.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: <Widget>[
                      Icon(
                        Icons.more_horiz_rounded,
                        size: 20,
                        color: open
                            ? scheme.onSecondaryContainer
                            : scheme.onSurfaceVariant,
                      ),
                      if (highlight)
                        Positioned(
                          // Inside the pill: the 40 dp row clips anything that
                          // paints above it.
                          right: 5,
                          top: 5,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
    );
  }
}
