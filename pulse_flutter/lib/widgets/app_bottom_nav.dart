import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/core/theme/app_typography.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

/// Animated squash-and-stretch pill indicator that travels horizontally
/// between navigation slots with M3 Expressive spatial spring physics.
class TravelingNavIndicator extends StatefulWidget {
  const TravelingNavIndicator({
    required this.index,
    required this.count,
    required this.color,
    required this.animate,
    this.stretch = 0.34,
    this.duration = M3Durations.medium2,
    this.pillHeight = 34.0,
    this.maxPillWidth = 72.0,
    super.key,
  });

  final int index;
  final int count;
  final Color color;
  final bool animate;
  final double stretch;
  final Duration duration;
  final double pillHeight;
  final double maxPillWidth;

  @override
  State<TravelingNavIndicator> createState() => _TravelingNavIndicatorState();
}

class _TravelingNavIndicatorState extends State<TravelingNavIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _spatial;
  double _from = 0.0;

  @override
  void initState() {
    super.initState();
    _from = widget.index.toDouble();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..value = 1.0;
    _spatial = CurvedAnimation(
      parent: _controller,
      curve: M3SpringCurves.spatial,
    );
  }

  @override
  void didUpdateWidget(covariant TravelingNavIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.index == widget.index) return;
    if (_controller.isAnimating) {
      final double currentT = _spatial.value;
      _from = ui.lerpDouble(_from, oldWidget.index.toDouble(), currentT) ??
          oldWidget.index.toDouble();
    } else {
      _from = oldWidget.index.toDouble();
    }
    if (widget.animate) {
      _controller.forward(from: 0.0);
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (widget.count <= 0 || constraints.maxWidth <= 0) {
          return const SizedBox.shrink();
        }
        final double slot = constraints.maxWidth / widget.count;
        final double baseWidth =
            (slot * 0.62).clamp(48.0, widget.maxPillWidth);
        final double travel =
            ((widget.index.toDouble() - _from).abs() / widget.count)
                .clamp(0.0, 1.0);

        double slotCenterX(double i) => (i + 0.5) * slot;

        return AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) {
            final double t = _spatial.value;
            // Squash and stretch: computed from linear time _controller.value
            // to ensure peak at midpoint and settling at 1.0 without negative jerk.
            final double wobble =
                math.sin(math.pi * _controller.value.clamp(0.0, 1.0)) * travel;
            final double pillW = baseWidth * (1.0 + widget.stretch * wobble);
            final double pillH = widget.pillHeight * (1.0 - 0.16 * wobble);
            final double fromX = slotCenterX(_from);
            final double toX = slotCenterX(widget.index.toDouble());
            final double currentCenterX = ui.lerpDouble(fromX, toX, t)!;
            final double left = currentCenterX - pillW / 2;
            final double top = (constraints.maxHeight - pillH) / 2;

            const List<Shapes> tabShapes = <Shapes>[
              Shapes.gem,
              Shapes.c9_sided_cookie,
              Shapes.burst,
              Shapes.flower,
            ];
            final Shapes fromShape =
                tabShapes[_from.round().clamp(0, tabShapes.length - 1)];
            final Shapes toShape =
                tabShapes[widget.index.clamp(0, tabShapes.length - 1)];

            return Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned(
                  left: left,
                  top: top,
                  width: pillW,
                  height: pillH,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      DecoratedBox(
                        decoration: ShapeDecoration(
                          color: widget.color,
                          shape: const StadiumBorder(),
                        ),
                        child: const SizedBox.expand(),
                      ),
                      // MOM-5: Expressive brand shape morphing between tabs
                      Opacity(
                        opacity: (1.0 - wobble * 0.7).clamp(0.0, 1.0),
                        child: ClipPath(
                          clipper: M3Clipper(t < 0.5 ? fromShape : toShape),
                          child: Container(
                            width: pillH * 0.80,
                            height: pillH * 0.80,
                            color: widget.color.withValues(alpha: 0.30),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class AppBottomNav extends ConsumerWidget {
  const AppBottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.hapticsEnabled,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool hapticsEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int totalUnread = ref.watch(
      totalUnreadCountProvider.select((int c) => c > 99 ? 99 : c),
    );
    final bool isFloating = ref.watch(
      uiSettingsProvider.select((s) => s.navBarFloating),
    );
    final PerformanceTier tier = ref.watch(
      adaptivePerformanceProvider.select((s) => s.tier),
    );
    final bool animate =
        !tier.isTierC && !MediaQuery.disableAnimationsOf(context);

    final List<_NavItem> items = <_NavItem>[
      _NavItem(
        context.l10n.tabChats,
        Icons.chat_bubble_outline_rounded,
        Icons.chat_bubble_rounded,
        badge: totalUnread,
      ),
      _NavItem(
        context.l10n.tabContacts,
        Icons.people_outline_rounded,
        Icons.people_rounded,
      ),
      _NavItem(
        context.l10n.tabNiosgram,
        Icons.grid_view_rounded,
        Icons.grid_view_rounded,
      ),
      _NavItem(
        context.l10n.tabProfile,
        Icons.person_outline_rounded,
        Icons.person_rounded,
      ),
    ];

    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Duration duration =
        tier.isTierA ? M3Durations.medium2 : M3Durations.medium1;
    final double stretch = tier.isTierA
        ? 0.34
        : tier.isTierB
            ? 0.18
            : 0.0;

    final Widget navBarContent = SizedBox(
      height: 80,
      child: Stack(
        children: <Widget>[
          // Traveling squash-and-stretch pill indicator behind the active slot icon
          Positioned(
            top: 13,
            left: 0,
            right: 0,
            height: 34,
            child: TravelingNavIndicator(
              index: currentIndex,
              count: items.length,
              color: scheme.secondaryContainer,
              animate: animate,
              stretch: stretch,
              duration: duration,
            ),
          ),
          // Interactive slots row
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List<Widget>.generate(items.length, (int index) {
              final _NavItem item = items[index];
              final bool isSelected = index == currentIndex;

              final Widget iconWidget = AnimatedSwitcher(
                duration: animate ? duration : Duration.zero,
                switchInCurve: M3SpringCurves.spatial,
                switchOutCurve: M3SpringCurves.spatial,
                transitionBuilder: (Widget child, Animation<double> anim) {
                  return FadeTransition(opacity: anim, child: child);
                },
                child: TweenAnimationBuilder<Color?>(
                  key: ValueKey<bool>(isSelected),
                  duration: animate ? duration : Duration.zero,
                  curve: M3SpringCurves.spatial,
                  tween: ColorTween(
                    begin: isSelected
                        ? scheme.onSurfaceVariant
                        : scheme.onSecondaryContainer,
                    end: isSelected
                        ? scheme.onSecondaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                  builder: (BuildContext context, Color? color, Widget? _) {
                    return Icon(
                      isSelected ? item.selectedIcon : item.icon,
                      size: 24,
                      color: color,
                      key: ValueKey<IconData>(
                        isSelected ? item.selectedIcon : item.icon,
                      ),
                    );
                  },
                ),
              );

              final Widget badgedIcon = item.badge > 0
                  ? Badge(
                      label: item.badge < 100
                          ? AnimatedSwitcher(
                              duration: duration,
                              transitionBuilder:
                                  (Widget child, Animation<double> anim) =>
                                      ScaleTransition(
                                scale: anim,
                                child: child,
                              ),
                              child: Text(
                                '${item.badge}',
                                key: ValueKey<int>(item.badge),
                                style: const TextStyle(
                                  fontFamily: AppFonts.ui,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : const Text(
                              '99+',
                              style: TextStyle(
                                fontFamily: AppFonts.ui,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                      child: iconWidget,
                    )
                  : iconWidget;

              final Widget animatedIcon = animate
                  ? AnimatedScale(
                      duration: duration,
                      curve: M3SpringCurves.bouncy,
                      scale: isSelected ? (tier.isTierA ? 1.12 : 1.05) : 1.0,
                      child: AnimatedSlide(
                        duration: duration,
                        curve: M3SpringCurves.spatial,
                        offset: Offset(0.0, isSelected ? -0.06 : 0.0),
                        child: badgedIcon,
                      ),
                    )
                  : badgedIcon;

              final Widget labelWidget = AnimatedDefaultTextStyle(
                duration: animate ? duration : Duration.zero,
                curve: M3SpringCurves.spatial,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'Onest',
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? scheme.onSecondaryContainer
                      : scheme.onSurfaceVariant,
                  letterSpacing: 0.1,
                ),
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );

              return Expanded(
                child: Semantics(
                  label: item.label,
                  selected: isSelected,
                  button: true,
                  child: InkResponse(
                    onTap: () {
                      if (ref.read(uiSettingsProvider).soundEffects) {
                        unawaited(ref.read(appSoundProvider).playUiTick());
                      }
                      if (hapticsEnabled && index != currentIndex) {
                        HapticService.tap();
                      }
                      onTap(index);
                    },
                    radius: 36,
                    splashColor: scheme.primary.withValues(alpha: 0.12),
                    highlightColor: Colors.transparent,
                    containedInkWell: true,
                    customBorder: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        SizedBox(
                          height: 34,
                          child: Center(child: animatedIcon),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 18,
                          child: Center(child: labelWidget),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );

    if (isFloating) {
      final double bottomInset = MediaQuery.viewPaddingOf(context).bottom;
      return Padding(
        padding: EdgeInsets.fromLTRB(10, 0, 10, 12 + bottomInset),
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.28),
              width: 1.0,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            clipBehavior: Clip.hardEdge,
            child: Material(
              color: Colors.transparent,
              child: navBarContent,
            ),
          ),
        ),
      );
    } else {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          border: Border(
            top: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.22),
              width: 0.8,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Material(
            color: Colors.transparent,
            child: navBarContent,
          ),
        ),
      );
    }
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon, this.selectedIcon, {this.badge = 0});

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final int badge;
}
