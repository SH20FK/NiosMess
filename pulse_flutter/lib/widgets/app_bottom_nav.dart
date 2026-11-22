import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/motion/m3_motion.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/core/theme/app_typography.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

class AppBottomNav extends ConsumerStatefulWidget {
  const AppBottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.hapticsEnabled,
    this.onReselect,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Called when the active destination is tapped again. Returns whether the
  /// tap did anything; an idle tap gives no sound and no haptic.
  final bool Function(int index)? onReselect;
  final bool hapticsEnabled;

  @override
  ConsumerState<AppBottomNav> createState() => _AppBottomNavState();
}

class _AppBottomNavState extends ConsumerState<AppBottomNav> {
  DateTime _lastTapTime = DateTime.fromMillisecondsSinceEpoch(0);

  void _handleTap(int index) {
    final bool reselect = index == widget.currentIndex;
    if (reselect && !(widget.onReselect?.call(index) ?? false)) return;

    final DateTime now = DateTime.now();
    final feedback = now.difference(_lastTapTime).inMilliseconds >= 120;
    _lastTapTime = now;

    if (feedback && ref.read(uiSettingsProvider).soundEffects) {
      unawaited(ref.read(appSoundProvider).playUiTick());
    }
    if (feedback && widget.hapticsEnabled) {
      HapticService.tap();
    }
    if (!reselect) widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    final tier = ref.watch(adaptivePerformanceProvider.select((s) => s.tier));
    final bool animate = !context.reduceMotion;
    final scheme = Theme.of(context).colorScheme;
    final duration = animate
        ? (tier.isTierC ? M3Durations.short4 : M3Durations.medium2)
        : Duration.zero;
    final items = <_NavItem>[
      _NavItem(
        context.l10n.tabChats,
        Icons.chat_bubble_outline_rounded,
        Icons.chat_bubble_rounded,
        unread: true,
      ),
      _NavItem(
        context.l10n.tabNiosgram,
        Icons.grid_view_outlined,
        Icons.grid_view_rounded,
      ),
      _NavItem(
        context.l10n.tabSettings,
        Icons.settings_outlined,
        Icons.settings_rounded,
      ),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border(
          top: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.35),
            width: 0.7,
          ),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          navigationBarTheme: NavigationBarThemeData(
            // 80dp is the M3 navigation-bar height; `NavigationBar` adds the
            // system gesture inset on top of it (`maintainBottomViewPadding`).
            height: 80,
            elevation: 0,
            backgroundColor: scheme.surfaceContainer,
            // Solid tonal pill instead of a 16% primary wash: the selected
            // destination is the only state that must read at a glance.
            indicatorColor: scheme.secondaryContainer,
            indicatorShape: const StadiumBorder(),
            labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
              (states) => TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 11,
                fontWeight: states.contains(WidgetState.selected)
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: states.contains(WidgetState.selected)
                    ? scheme.onSurface
                    : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        child: NavigationBar(
          key: const ValueKey('main-bottom-navigation'),
          height: 80,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          animationDuration: duration,
          maintainBottomViewPadding: true,
          selectedIndex: widget.currentIndex,
          onDestinationSelected: _handleTap,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: List<Widget>.generate(items.length, (index) {
            final item = items[index];
            final selected = index == widget.currentIndex;
            final icon = TabMorphIcon(
              outlineIcon: item.icon,
              filledIcon: item.selectedIcon,
              isSelected: selected,
              color: selected
                  ? scheme.onSecondaryContainer
                  : scheme.onSurfaceVariant,
              animate: animate,
              duration: duration,
              size: 24,
            );
            return NavigationDestination(
              label: item.label,
              // M3 keeps the selected destination clean: the tonal pill and
              // the filled icon already carry the state, and a badge sitting
              // on top of the active icon was the unreadable case in the
              // audit screenshot.
              icon: item.unread && !selected
                  // The counter is watched here, not in `build`: a new
                  // message repaints one badge instead of the whole bar.
                  ? Consumer(
                      builder:
                          (BuildContext context, WidgetRef ref, Widget? child) {
                            return _destinationIcon(
                              scheme: scheme,
                              icon: child!,
                              count: ref.watch(totalUnreadCountProvider),
                            );
                          },
                      child: icon,
                    )
                  : icon,
            );
          }),
        ),
      ),
    );
  }

  /// Unread badge pinned to the icon's top-right corner.
  ///
  /// `Badge` centres a labelled pill on the top edge of its child, so the
  /// offset is tuned against the 24dp icon: `dy -9` makes the ~13dp pill
  /// straddle the icon's top-right corner instead of painting over the glyph,
  /// `dx 2` pushes it just past the corner and `99+` is the widest label,
  /// which keeps every count inside the destination slot.
  Widget _destinationIcon({
    required ColorScheme scheme,
    required Widget icon,
    required int count,
  }) {
    if (count <= 0) return icon;
    return Badge(
      backgroundColor: scheme.primary,
      textColor: scheme.onPrimary,
      alignment: AlignmentDirectional.topEnd,
      offset: const Offset(2, -9),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
      textStyle: TextStyle(
        fontFamily: AppFonts.ui,
        fontSize: 10,
        height: 1,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
      label: Text(count > 99 ? '99+' : '$count'),
      child: icon,
    );
  }
}

class _NavItem {
  const _NavItem(
    this.label,
    this.icon,
    this.selectedIcon, {
    this.unread = false,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Whether this destination carries the total unread counter.
  final bool unread;
}

class TabMorphIcon extends StatefulWidget {
  const TabMorphIcon({
    required this.outlineIcon,
    required this.filledIcon,
    required this.isSelected,
    required this.color,
    required this.animate,
    required this.duration,
    this.size = 24.0,
    super.key,
  });

  final IconData outlineIcon;
  final IconData filledIcon;
  final bool isSelected;
  final Color color;
  final bool animate;
  final Duration duration;
  final double size;

  @override
  State<TabMorphIcon> createState() => _TabMorphIconState();
}

class _TabMorphIconState extends State<TabMorphIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: widget.isSelected ? 1.0 : 0.0,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: M3SpringCurves.expressiveDecel,
      reverseCurve: M3SpringCurves.expressiveAccel,
    );
  }

  @override
  void didUpdateWidget(covariant TabMorphIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (!widget.animate) {
      _controller.value = widget.isSelected ? 1 : 0;
      return;
    }
    if (oldWidget.isSelected != widget.isSelected) {
      if (widget.animate) {
        _controller.animateTo(
          widget.isSelected ? 1.0 : 0.0,
          duration: widget.duration,
          curve: Curves.linear,
        );
      } else {
        _controller.value = widget.isSelected ? 1.0 : 0.0;
      }
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (BuildContext context, _) {
        final double t = _animation.value;
        final pulse = math.sin(math.pi * _controller.value);
        final double scale = 1.0 + 0.16 * pulse;

        return Transform.translate(
          offset: Offset(0, -3.5 * pulse),
          child: Transform.scale(
            scale: scale,
            child: SizedBox.square(
              dimension: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Opacity(
                    opacity: (1.0 - t).clamp(0.0, 1.0),
                    child: Icon(
                      widget.outlineIcon,
                      size: widget.size,
                      color: widget.color,
                    ),
                  ),
                  Opacity(
                    opacity: t.clamp(0.0, 1.0),
                    child: Icon(
                      widget.filledIcon,
                      size: widget.size,
                      color: widget.color,
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
