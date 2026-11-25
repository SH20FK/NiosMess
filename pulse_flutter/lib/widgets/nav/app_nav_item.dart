import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/motion/m3_press_scale.dart';
import 'package:pulse_flutter/widgets/nav/app_nav_destination.dart';

/// Sizes of the M3 Expressive navigation bar and rail, from the Material
/// Components tokens (`m3_comp_nav_bar_*`, `m3_comp_nav_rail_*`).
abstract final class AppNavMetrics {
  /// Bar container and rail item height at the default text scale.
  static const double itemExtent = 64;
  static const double railWidth = 96;
  static const double indicatorWidth = 56;
  static const double indicatorHeight = 32;

  /// Indicator of a horizontal item (icon beside the label).
  static const double horizontalIndicatorHeight = 40;
  static const double iconSize = 24;
  static const double iconLabelGap = 4;

  /// Labels follow the system text size only up to this factor, as in the
  /// platform bar: beyond it the bar would crowd out the content.
  static const double maxLabelScale = 1.3;

  static const double _labelLine = 16;

  /// [itemExtent], grown by whatever the scaled label needs beyond 16 dp.
  static double itemExtentFor(BuildContext context) {
    final TextStyle? style = Theme.of(context).textTheme.labelMedium;
    final double fontSize = style?.fontSize ?? 12;
    final double line =
        MediaQuery.textScalerOf(
          context,
        ).clamp(maxScaleFactor: maxLabelScale).scale(fontSize) *
        (style?.height ?? _labelLine / 12);
    // Sub-pixel noise of the line-height maths must not move the bar.
    return line <= _labelLine + 0.05
        ? itemExtent
        : itemExtent + line - _labelLine;
  }
}

/// Tap handling shared by the bottom bar and the side rail: one cooldown for
/// the sound and the haptic, and silence when a reselect does nothing.
class AppNavTapController {
  static const Duration _feedbackCooldown = Duration(milliseconds: 120);

  DateTime _lastFeedback = DateTime.fromMillisecondsSinceEpoch(0);

  void handle(
    WidgetRef ref, {
    required int index,
    required int currentIndex,
    required ValueChanged<int> onTap,
    required bool haptics,
    bool Function(int index)? onReselect,
  }) {
    final bool reselect = index == currentIndex;
    if (reselect && !(onReselect?.call(index) ?? false)) return;

    final DateTime now = DateTime.now();
    if (now.difference(_lastFeedback) >= _feedbackCooldown) {
      _lastFeedback = now;
      if (ref.read(uiSettingsProvider).soundEffects) {
        unawaited(ref.read(appSoundProvider).playUiTick());
      }
      if (haptics) HapticService.tap();
    }
    if (!reselect) onTap(index);
  }
}

/// How a destination lays out its icon and label.
enum AppNavItemLayout {
  /// Icon above the label: the bottom bar on phones and the side rail.
  vertical,

  /// Icon beside the label, both inside the indicator: the bottom bar from
  /// 600 dp.
  horizontal,
}

/// One destination of the bottom bar or the side rail.
///
/// The indicator opens from its centre on a spatial spring and fades on an
/// effects curve; the icon morphs between its outline and filled glyphs.
class AppNavItem extends StatefulWidget {
  const AppNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
    required this.animate,
    required this.duration,
    this.layout = AppNavItemLayout.vertical,
    super.key,
  });

  final AppNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  /// `false` under reduced motion: every state change is instant.
  final bool animate;
  final Duration duration;
  final AppNavItemLayout layout;

  @override
  State<AppNavItem> createState() => _AppNavItemState();
}

class _AppNavItemState extends State<AppNavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _spread;
  late final CurvedAnimation _fade;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: widget.selected ? 1 : 0,
    );
    // The spatial spring may overshoot, so it only drives the width.
    _spread = CurvedAnimation(
      parent: _controller,
      curve: M3SpringCurves.spatialFast,
      reverseCurve: M3SpringCurves.expressiveAccel,
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: M3SpringCurves.effectsDefault,
      reverseCurve: M3SpringCurves.expressiveAccel,
    );
  }

  @override
  void didUpdateWidget(covariant AppNavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
    if (!widget.animate) {
      _controller.value = widget.selected ? 1 : 0;
      return;
    }
    if (oldWidget.selected == widget.selected) return;
    if (widget.selected) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _spread.dispose();
    _fade.dispose();
    _controller.dispose();
    super.dispose();
  }

  Widget _withIndicator(ColorScheme scheme, {required Widget child}) {
    return Stack(
      alignment: Alignment.center,
      // The unread badge hangs over the corner of the indicator.
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned.fill(
          child: FadeTransition(
            opacity: _fade,
            child: AnimatedBuilder(
              animation: _spread,
              builder: (BuildContext context, Widget? pill) => Transform.scale(
                scaleX: lerpDouble(0.5, 1, _spread.value),
                child: pill,
              ),
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: scheme.secondaryContainer,
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool horizontal = widget.layout == AppNavItemLayout.horizontal;
    final Color iconColor = widget.selected
        ? scheme.onSecondaryContainer
        : scheme.onSurfaceVariant;
    // Under the icon the active label is `secondary`. Beside the icon it sits
    // on the indicator itself and takes the on-container tone to stay legible.
    final Color labelColor = !widget.selected
        ? scheme.onSurfaceVariant
        : horizontal
        ? scheme.onSecondaryContainer
        : scheme.secondary;

    Widget icon = TabMorphIcon(
      outlineIcon: widget.destination.icon,
      filledIcon: widget.destination.selectedIcon,
      isSelected: widget.selected,
      color: iconColor,
      animate: widget.animate,
      duration: widget.duration,
      size: AppNavMetrics.iconSize,
    );
    if (widget.destination.showsUnread) {
      icon = Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          icon,
          PositionedDirectional(
            start: 14,
            top: -4,
            child: _NavUnreadBadge(animate: widget.animate),
          ),
        ],
      );
    }
    icon = M3PressScale(pressed: _pressed, scale: 0.9, child: icon);

    final Widget label = AnimatedDefaultTextStyle(
      // One weight for both states: a bolder active label changes its width
      // and nudges the neighbours.
      style:
          (theme.textTheme.labelMedium ??
                  const TextStyle(fontSize: 12, height: 16 / 12))
              .copyWith(color: labelColor),
      duration: widget.animate ? M3Durations.effectsDefault : Duration.zero,
      curve: M3SpringCurves.effectsDefault,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      child: Text(widget.destination.label(context)),
    );

    final Widget content = horizontal
        ? _withIndicator(
            scheme,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: AppNavMetrics.horizontalIndicatorHeight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    icon,
                    const SizedBox(width: AppNavMetrics.iconLabelGap),
                    Flexible(child: label),
                  ],
                ),
              ),
            ),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _withIndicator(
                scheme,
                child: SizedBox(
                  width: AppNavMetrics.indicatorWidth,
                  height: AppNavMetrics.indicatorHeight,
                  child: Center(child: icon),
                ),
              ),
              const SizedBox(height: AppNavMetrics.iconLabelGap),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: label,
              ),
            ],
          );

    // One node for the screen reader: label, unread count, selected state.
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: widget.selected,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (bool value) {
              if (mounted && value != _pressed) {
                setState(() => _pressed = value);
              }
            },
            customBorder: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            splashFactory: NoSplash.splashFactory,
            overlayColor: WidgetStateProperty.resolveWith<Color?>((
              Set<WidgetState> states,
            ) {
              if (states.contains(WidgetState.pressed) ||
                  states.contains(WidgetState.focused)) {
                return scheme.onSecondaryContainer.withValues(alpha: 0.10);
              }
              if (states.contains(WidgetState.hovered)) {
                return scheme.onSecondaryContainer.withValues(alpha: 0.08);
              }
              return null;
            }),
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: AppNavMetrics.maxLabelScale,
              child: Center(child: content),
            ),
          ),
        ),
      ),
    );
  }
}

/// Total unread counter on a destination icon: 16 dp, `error` tone, `99+` cap.
///
/// It watches the counter itself, so a new message repaints this badge and
/// nothing else in the bar or the rail.
class _NavUnreadBadge extends ConsumerWidget {
  const _NavUnreadBadge({required this.animate});

  final bool animate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int count = ref.watch(totalUnreadCountProvider);
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return AnimatedSwitcher(
      duration: animate ? M3Durations.short4 : Duration.zero,
      switchInCurve: M3SpringCurves.expressiveDecel,
      switchOutCurve: M3SpringCurves.expressiveAccel,
      transitionBuilder: (Widget child, Animation<double> animation) =>
          FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: animation, child: child),
          ),
      child: count <= 0
          ? const SizedBox.shrink(key: ValueKey<String>('nav-unread-none'))
          : Semantics(
              // Keyed by presence, not by value: the badge pops in once and
              // then only its number changes.
              key: const ValueKey<String>('nav-unread-badge'),
              label: context.l10n.chatListUnreadCount(count),
              child: ExcludeSemantics(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: scheme.error,
                      shape: const StadiumBorder(),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Center(
                        widthFactor: 1,
                        heightFactor: 1,
                        child: Text(
                          count > 99 ? '99+' : '$count',
                          maxLines: 1,
                          softWrap: false,
                          style:
                              (theme.textTheme.labelSmall ??
                                      const TextStyle(fontSize: 11))
                                  .copyWith(
                                    color: scheme.onError,
                                    height: 1,
                                    letterSpacing: 0,
                                  ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

/// Destination glyph that cross-fades from its outline to its filled form and
/// lifts on the way. The lift is a sine over the controller, so it drives
/// position and scale only, never opacity.
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
      _controller.animateTo(
        widget.isSelected ? 1.0 : 0.0,
        duration: widget.duration,
        curve: Curves.linear,
      );
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
        final double pulse = math.sin(math.pi * _controller.value);
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
