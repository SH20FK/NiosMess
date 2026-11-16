import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
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

/// Inbox app bar: 64 dp (56 dp compact), 16 dp title column, and a scrim that
/// fades in once the list moves under the bar.
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
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

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

        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: scrolled ? 1 : 0),
          duration: reduceMotion ? Duration.zero : _scrimDuration,
          curve: M3SpringCurves.gentle,
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
          child: AppBar(
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
                tooltip: l10n.chatListSearchMessagesHint,
                onPressed: () => context.push('/chats/search'),
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
          ),
        );
      },
    );
  }
}
