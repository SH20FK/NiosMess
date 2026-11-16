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

/// Inbox scope strip: exactly one 40 dp row, no overflow menu.
///
/// The row shows every folder immediately (horizontally scrollable), so the
/// user never has to open a menu to reach a folder:
///
/// * folders configured → `[Все] [Непрочитанные] [folder…]`;
/// * no folders → `[Все] [Непрочитанные] [Группы] [Каналы] [Личные] [Боты]`.
///
/// "Все" resets both axes (folder + type), so it can never advertise a wider
/// result set than the list actually shows. Long-press on "Все" (or on any
/// folder) opens folder management, which replaces the old menu entry.
class ChatFilterBar extends ConsumerWidget {
  const ChatFilterBar({super.key, this.compact = false});

  /// Compact density (`UiSettingsState.compactMode`): 32 dp segments.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final ColorScheme scheme = Theme.of(context).colorScheme;
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

    final double segmentHeight = _resolveRowHeight(context);
    final double trackHeight = segmentHeight + 8;

    final List<Widget> items = <Widget>[
      _FilterPill(
        key: const ValueKey<String>('chat-filter-all'),
        label: Text(l.chatListFilterAll),
        selected: filter == ChatFilter.all && selectedFolderId == null,
        minHeight: segmentHeight,
        onTap: resetAll,
        // Folder management lives behind a long-press on "Все" once the
        // overflow menu is gone.
        onLongPress: () => openChatFolders(context),
      ),
      _FilterPill(
        key: const ValueKey<String>('chat-filter-unread'),
        label: Text(l.chatListFilterUnread),
        selected: filter == ChatFilter.unread,
        minHeight: segmentHeight,
        onTap: () => selectFilter(ChatFilter.unread),
      ),
      if (hasFolders)
        for (final ChatFolder folder in folders)
          _buildFolderPill(
            folder: folder,
            selected: selectedFolderId == folder.id,
            minHeight: segmentHeight,
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
          key: const ValueKey<String>('chat-filter-groups'),
          label: Text(l.chatListFilterGroups),
          selected: filter == ChatFilter.groups,
          minHeight: segmentHeight,
          onTap: () => selectFilter(ChatFilter.groups),
        ),
        _FilterPill(
          key: const ValueKey<String>('chat-filter-channels'),
          label: Text(l.chatListFilterChannels),
          selected: filter == ChatFilter.channels,
          minHeight: segmentHeight,
          onTap: () => selectFilter(ChatFilter.channels),
        ),
        _FilterPill(
          key: const ValueKey<String>('chat-filter-direct'),
          label: Text(l.chatListFilterDirect),
          selected: filter == ChatFilter.direct,
          minHeight: segmentHeight,
          onTap: () => selectFilter(ChatFilter.direct),
        ),
        _FilterPill(
          key: const ValueKey<String>('chat-filter-bots'),
          label: Text(l.chatListFilterBots),
          selected: filter == ChatFilter.bots,
          minHeight: segmentHeight,
          onTap: () => selectFilter(ChatFilter.bots),
        ),
      ],
    ];

    return Container(
      height: trackHeight,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: ShapeDecoration(
        color: scheme.surfaceContainerLow,
        shape: StadiumBorder(
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.28),
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(trackHeight),
        child: ShaderMask(
          // Soft right-edge fade so a scrolled row reads as "more to the
          // right" instead of a chopped pill.
          shaderCallback: (Rect bounds) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: const <Color>[Colors.white, Colors.white, Colors.transparent],
            stops: const <double>[0.0, 0.92, 1.0],
          ).createShader(bounds),
          blendMode: BlendMode.dstIn,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Row(
              children: <Widget>[
                for (int i = 0; i < items.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: 2),
                  items[i],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 36 dp segment (32 dp compact) inside a 44 dp rail; grows with text scale.
  double _resolveRowHeight(BuildContext context) {
    final double base = compact ? 32 : 36;
    final double scaledLabel = MediaQuery.textScalerOf(context).scale(18);
    return math.max(base, scaledLabel + 6);
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
          constraints: BoxConstraints.tightFor(height: minHeight),
          padding: EdgeInsets.only(
            left: 14,
            right: showBadge ? 10 : 14,
            top: 3,
            bottom: 3,
          ),
          decoration: ShapeDecoration(
            color: selected ? scheme.secondaryContainer : Colors.transparent,
            shape: const StadiumBorder(),
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
