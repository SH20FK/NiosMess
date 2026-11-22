import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/motion/m3_motion.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/features/chats/application/inbox_search_controller.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';

/// Whether the inbox list is scrolled past the header scrim threshold.
///
/// A dedicated flag instead of `chatListFabVisibleProvider`: the FAB hides
/// after 28 dp of travel, so reusing it would leave the header un-scrimmed
/// while the list is scrolled and vice versa.
class ChatListScrolledNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setScrolled(bool value) {
    if (state != value) state = value;
  }
}

final chatListScrolledProvider =
    NotifierProvider<ChatListScrolledNotifier, bool>(
      ChatListScrolledNotifier.new,
    );

const ValueKey<String> _kTitleBarKey = ValueKey<String>('inbox-title-bar');
const ValueKey<String> _kSearchBarKey = ValueKey<String>('inbox-search-bar');

/// Inbox app bar: 64 dp (56 dp compact), 16 dp title column, and a scrim that
/// fades in once the list moves under the bar.
///
/// The search action turns the bar into a search field in place; the results
/// replace the chat list below it, so search never leaves the inbox.
class ChatListHeader extends ConsumerWidget implements PreferredSizeWidget {
  const ChatListHeader({super.key});

  /// Scroll distance after which the bar paints its scrim.
  static const double scrimOffset = 8;

  static const Duration _scrimDuration = Duration(milliseconds: 200);

  /// Vertical room around the scaled title line box (16 dp top + 16 bottom).
  static const double _titleVerticalRoom = 32;

  /// Height of the bar for the current text scale.
  ///
  /// The single source of truth for the height: [PreferredSize] cannot read the
  /// widget tree, so the screen asks this method once and wraps the header in a
  /// `PreferredSize` of exactly that height. The header then fills the slot it
  /// is given (see [build]) — no second, drifting formula.
  static double heightFor(BuildContext context, {bool compact = false}) {
    if (compact) return AppHeights.lg;
    final TextStyle? titleStyle = Theme.of(context).textTheme.headlineSmall;
    final double fontSize = titleStyle?.fontSize ?? 24;
    final double lineHeight = (titleStyle?.height ?? 1.33) * fontSize;
    final double scaledTitle = MediaQuery.textScalerOf(
      context,
    ).scale(lineHeight);
    return math.max(AppHeights.xl, scaledTitle + _titleVerticalRoom);
  }

  /// Base height used when the header is mounted without an explicit
  /// `PreferredSize` slot (previews, widget tests). Real heights come from
  /// [heightFor].
  @override
  Size get preferredSize => const Size.fromHeight(AppHeights.xl);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final l10n = context.l10n;
    final bool scrolled = ref.watch(chatListScrolledProvider);
    final bool searching = ref.watch(
      inboxSearchProvider.select((InboxSearchState s) => s.active),
    );
    final bool reduceMotion = context.reduceMotion;

    final profile = ref.watch(authProvider.select((s) => s.profile));
    final sessionName = ref.watch(
      authProvider.select((s) => s.session?.displayName),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // The screen sizes the bar (text scale + compact density); fall back to
        // the base height when the parent gives no bounded slot.
        final double height =
            constraints.maxHeight.isFinite && constraints.maxHeight > 0
            ? constraints.maxHeight
            : AppHeights.xl;

        final Widget titleBar = AppBar(
          key: _kTitleBarKey,
          automaticallyImplyLeading: false,
          titleSpacing: 16,
          toolbarHeight: height,
          centerTitle: false,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          elevation: 0,
          title: Text(
            l10n.tabChats,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: <Widget>[
            IconButton(
              key: const ValueKey<String>('inbox-search-open'),
              tooltip: l10n.chatListSearchMessagesHint,
              onPressed: () => ref.read(inboxSearchProvider.notifier).open(),
              iconSize: 24,
              constraints: const BoxConstraints.tightFor(
                width: AppHeights.md,
                height: AppHeights.md,
              ),
              icon: const Icon(Icons.search_rounded),
            ),
            IconButton(
              key: const ValueKey('inbox-profile-settings'),
              tooltip: l10n.tabSettings,
              onPressed: () => context.go('/main/settings'),
              constraints: const BoxConstraints.tightFor(
                width: AppHeights.md,
                height: AppHeights.md,
              ),
              icon: PulseAvatar(
                avatarUrl: profile?.avatarUrl,
                name: profile?.displayName ?? sessionName ?? '',
                radius: 16,
              ),
            ),
            // 8 dp + the 8 dp the 48 dp target leaves around the 32 dp
            // avatar = the 16 dp right inset of the title column.
            const SizedBox(width: 8),
          ],
        );

        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: scrolled ? 1 : 0),
          duration: reduceMotion ? Duration.zero : _scrimDuration,
          curve: M3SpringCurves.effectsDefault,
          builder: (BuildContext context, double t, Widget? child) {
            return DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: t),
                border: Border(
                  bottom: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.22 * t),
                  ),
                ),
              ),
              child: child,
            );
          },
          // Title and search field trade places inside the same slot.
          child: AnimatedSwitcher(
            duration: reduceMotion ? Duration.zero : M3Durations.short4,
            switchInCurve: M3SpringCurves.expressiveDecel,
            switchOutCurve: M3SpringCurves.expressiveAccel,
            transitionBuilder: (Widget child, Animation<double> animation) =>
                FadeTransition(opacity: animation, child: child),
            layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
              fit: StackFit.expand,
              children: <Widget>[...previous, ?current],
            ),
            child: searching
                ? const _InboxSearchBar(key: _kSearchBarKey)
                : titleBar,
          ),
        );
      },
    );
  }
}

/// The header in search mode: a tonal pill with back, field and clear.
class _InboxSearchBar extends ConsumerStatefulWidget {
  const _InboxSearchBar({super.key});

  @override
  ConsumerState<_InboxSearchBar> createState() => _InboxSearchBarState();
}

class _InboxSearchBarState extends ConsumerState<_InboxSearchBar> {
  late final TextEditingController _controller = TextEditingController(
    text: ref.read(inboxSearchProvider).query,
  );
  final FocusNode _focusNode = FocusNode(debugLabel: 'inbox-search');

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _close() => ref.read(inboxSearchProvider.notifier).close();

  void _clear() {
    // `clear()` does not fire `onChanged`.
    _controller.clear();
    ref.read(inboxSearchProvider.notifier).setQuery('');
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final l10n = context.l10n;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): _close,
      },
      child: SafeArea(
        bottom: false,
        child: Padding(
          // 4 dp around the pill: 56 dp field in the 64 dp bar, 48 in compact.
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Material(
            color: scheme.surfaceContainerHigh,
            shape: const StadiumBorder(),
            child: Row(
              children: <Widget>[
                const SizedBox(width: 4),
                IconButton(
                  key: const ValueKey<String>('inbox-search-close'),
                  tooltip: l10n.commonBack,
                  onPressed: _close,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                Expanded(
                  child: TextField(
                    key: const ValueKey<String>('inbox-search-field'),
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: true,
                    maxLines: 1,
                    textInputAction: TextInputAction.search,
                    textAlignVertical: TextAlignVertical.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurface,
                    ),
                    onChanged: (String value) =>
                        ref.read(inboxSearchProvider.notifier).setQuery(value),
                    decoration: InputDecoration(
                      hintText: l10n.chatListSearchMessagesHint,
                      hintStyle: theme.textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      filled: false,
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  ),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (BuildContext context, TextEditingValue value, _) {
                    return AnimatedSwitcher(
                      duration: context.reduceMotion
                          ? Duration.zero
                          : M3Durations.short3,
                      switchInCurve: M3SpringCurves.expressiveDecel,
                      switchOutCurve: M3SpringCurves.expressiveAccel,
                      transitionBuilder:
                          (Widget child, Animation<double> animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  scale: animation,
                                  child: child,
                                ),
                              ),
                      child: value.text.isEmpty
                          ? const SizedBox(
                              key: ValueKey<String>('inbox-search-no-clear'),
                              width: AppHeights.md,
                            )
                          : IconButton(
                              key: const ValueKey<String>('inbox-search-clear'),
                              tooltip: l10n.pickerClearSearch,
                              onPressed: _clear,
                              icon: const Icon(Icons.close_rounded),
                            ),
                    );
                  },
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
