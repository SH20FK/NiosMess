import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/motion/m3_motion.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/features/chats/application/inbox_search_controller.dart';
import 'package:pulse_flutter/models/chat_productivity.dart';
import 'package:pulse_flutter/providers/chat_filter_provider.dart';
import 'package:pulse_flutter/providers/chat_productivity_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/chat/custom_emoji_text.dart';
import 'package:pulse_flutter/widgets/chat_productivity.dart'
    show openChatFolders;

/// Inbox scope strip: one 48 dp rail on a tonal backdrop, no overflow menu.
/// Pills are 36 dp tall inside a 48 dp touch target; the mouse wheel scrolls
/// the rail sideways.
///
/// The row shows every folder immediately (horizontally scrollable), so the
/// user never has to open a menu to reach a folder:
///
/// * folders configured → `[Все] [Непрочитанные] [folder…]`;
/// * no folders → `[Все] [Непрочитанные] [Группы] [Каналы] [Личные] [Боты]`.
///
/// "Все" resets both axes (folder + type), so it can never advertise a wider
/// result set than the list actually shows. The trailing folders chip opens
/// folder management; a long-press on "Все" or on a folder is the shortcut to
/// the same screen.
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
    // While the header is a search field, the same rail scopes the results.
    final (bool searching, InboxSearchScope scope) = ref.watch(
      inboxSearchProvider.select((InboxSearchState s) => (s.active, s.scope)),
    );

    // Unread badges are watched by each folder pill: the strip itself never
    // subscribes to the chat list.

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
    final double trackHeight = segmentHeight + 2 * _kPillTouchInset;

    final List<Widget> filterItems = <Widget>[
      _FilterPill(
        key: const ValueKey<String>('chat-filter-all'),
        label: Text(l.chatListFilterAll),
        selected: filter == ChatFilter.all && selectedFolderId == null,
        minHeight: segmentHeight,
        onTap: resetAll,
        // Shortcut to folder management; the visible entry is the trailing
        // chip.
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
          _FolderPill(
            key: ValueKey<String>('chat-filter-folder-${folder.id}'),
            folder: folder,
            selected: selectedFolderId == folder.id,
            minHeight: segmentHeight,
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
      Tooltip(
        message: l.inboxFolders,
        child: _FilterPill(
          key: const ValueKey<String>('chat-filter-folders'),
          label: Icon(
            Icons.create_new_folder_outlined,
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
          selected: false,
          minHeight: segmentHeight,
          onTap: () {
            if (haptics) HapticService.tap();
            openChatFolders(context);
          },
        ),
      ),
    ];
    final List<Widget> items = !searching
        ? filterItems
        : <Widget>[
            for (final (InboxSearchScope value, String label)
                in <(InboxSearchScope, String)>[
                  (InboxSearchScope.all, l.chatListFilterAll),
                  (InboxSearchScope.chats, l.tabChats),
                  (InboxSearchScope.messages, l.noticeMessages),
                  (InboxSearchScope.people, l.inboxSearchPeople),
                ])
              _FilterPill(
                key: ValueKey<String>('inbox-search-scope-${value.name}'),
                label: Text(label),
                selected: scope == value,
                minHeight: segmentHeight,
                onTap: () {
                  if (scope == value) return;
                  if (haptics) HapticService.tap();
                  ref.read(inboxSearchProvider.notifier).setScope(value);
                },
              ),
          ];

    return Container(
      height: trackHeight,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: ShapeDecoration(
        // One clear step above the pane backdrop, so the rail reads as a
        // single control; the selected pill sits on it in `secondaryContainer`.
        color: scheme.surfaceContainerHigh,
        shape: const StadiumBorder(),
      ),
      child: _FilterRail(
        // Filters and search scopes swap inside the same rail.
        child: AnimatedSwitcher(
          duration: context.reduceMotion ? Duration.zero : M3Durations.short4,
          switchInCurve: M3SpringCurves.expressiveDecel,
          switchOutCurve: M3SpringCurves.expressiveAccel,
          layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
            alignment: AlignmentDirectional.centerStart,
            children: <Widget>[...previous, ?current],
          ),
          child: Row(
            key: ValueKey<bool>(searching),
            children: <Widget>[
              for (int i = 0; i < items.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: 2),
                items[i],
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 36 dp segment (32 dp compact) inside a 48 dp rail; grows with text scale.
  double _resolveRowHeight(BuildContext context) {
    final double base = compact ? 32 : 36;
    final double scaledLabel = MediaQuery.textScalerOf(context).scale(18);
    return math.max(base, scaledLabel + 6);
  }
}

/// Room above and below a pill that still belongs to its touch target: a
/// 36 dp pill is tapped through 48 dp.
const double _kPillTouchInset = 6;

/// Scrolling body of the rail.
///
/// The mouse wheel scrolls it sideways until it reaches an edge, and the end
/// edge fades only while more pills wait past it, so the last chip of a rail
/// scrolled to its end is shown whole.
class _FilterRail extends StatefulWidget {
  const _FilterRail({required this.child});

  final Widget child;

  @override
  State<_FilterRail> createState() => _FilterRailState();
}

class _FilterRailState extends State<_FilterRail> {
  final ScrollController _controller = ScrollController();
  final ValueNotifier<bool> _moreAhead = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _controller.dispose();
    _moreAhead.dispose();
    super.dispose();
  }

  bool _onMetrics(ScrollMetrics metrics) {
    if ((metrics.extentAfter > 1) != _moreAhead.value) {
      // Metrics also change during layout; the rebuild waits for it to end.
      scheduleMicrotask(() {
        if (!mounted || !_controller.hasClients) return;
        _moreAhead.value = _controller.position.extentAfter > 1;
      });
    }
    // The rail's scrolling is not the chat list's: the screen above must not
    // take it for a list scroll and raise the header scrim.
    return true;
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_controller.hasClients) return;
    final Offset delta = event.scrollDelta;
    // A sideways wheel or a trackpad already scrolls the rail by itself.
    if (delta.dx != 0 || delta.dy == 0) return;
    final ScrollPosition position = _controller.position;
    final double target = (position.pixels + delta.dy).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    // Nothing left in that direction: the wheel goes to the chat list.
    if (target == position.pixels) return;
    GestureBinding.instance.pointerSignalResolver.register(
      event,
      (PointerSignalEvent _) => position.pointerScroll(delta.dy),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only the alpha matters for dstIn; any opaque tone works.
    final Color mask = Theme.of(context).colorScheme.surface;
    final TextDirection direction = Directionality.of(context);

    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(999)),
      child: ValueListenableBuilder<bool>(
        valueListenable: _moreAhead,
        builder: (BuildContext context, bool more, Widget? child) => ShaderMask(
          shaderCallback: (Rect bounds) => LinearGradient(
            begin: AlignmentDirectional.centerStart,
            end: AlignmentDirectional.centerEnd,
            colors: <Color>[
              mask,
              mask,
              more ? mask.withValues(alpha: 0) : mask,
            ],
            stops: const <double>[0.0, 0.92, 1.0],
          ).createShader(bounds, textDirection: direction),
          blendMode: BlendMode.dstIn,
          child: child,
        ),
        child: Listener(
          onPointerSignal: _onPointerSignal,
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (ScrollMetricsNotification n) =>
                _onMetrics(n.metrics),
            child: NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification n) => _onMetrics(n.metrics),
              child: SingleChildScrollView(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                // 8 margin + 4 rail + 4 here: pills start on the 16 dp column.
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Folder pill with its own unread counter subscription: a new message in a
/// folder rebuilds this pill, not the whole strip.
class _FolderPill extends ConsumerWidget {
  const _FolderPill({
    super.key,
    required this.folder,
    required this.selected,
    required this.minHeight,
    required this.onTap,
    required this.onLongPress,
  });

  final ChatFolder folder;
  final bool selected;
  final double minHeight;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ChatFolderUnread unread = ref.watch(
      chatFolderUnreadProvider(folder.id),
    );
    return _FilterPill(
      label: CustomEmojiText(folder.title, maxLines: 1),
      selected: selected,
      minHeight: minHeight,
      badgeCount: unread.unread,
      badgeAlert: unread.alert,
      onTap: onTap,
      onLongPress: onLongPress,
    );
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
    final bool reduceMotion = context.reduceMotion;
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
              : M3Durations.short4,
          curve: M3SpringCurves.effectsDefault,
          constraints: BoxConstraints.tightFor(height: minHeight),
          // Outside the painted pill, inside the gesture: the touch target.
          margin: const EdgeInsets.symmetric(vertical: _kPillTouchInset),
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
