import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

/// Available animation transition modes for [M3SpringSwitcher].
enum M3SwitcherType {
  /// Spring scale combined with normalized expressive fade.
  fadeScale,

  /// Vertical slide combined with normalized expressive fade.
  fadeSlideY,

  /// Horizontal slide combined with normalized expressive fade.
  fadeSlideX,

  /// Pure normalized expressive fade.
  fade,

  /// Pure spring scale.
  scale,
}

/// Material 3 Expressive AnimatedSwitcher.
///
/// Ensures strict mathematical normalization:
/// - Opacity transitions NEVER use bouncy/overshoot curves; strictly [M3SpringCurves.expressiveDecel].
/// - Spatial/scale transitions utilize normalized [M3SpringCurves.spatial].
/// - Zero per-frame clipping or save-layers.
class M3SpringSwitcher extends StatelessWidget {
  const M3SpringSwitcher({
    required this.child,
    super.key,
    this.type = M3SwitcherType.fadeScale,
    this.duration = const Duration(milliseconds: 300),
    this.reverseDuration,
    this.switchInCurve = M3SpringCurves.spatial,
    this.switchOutCurve = M3SpringCurves.expressiveDecel,
    this.layoutBuilder = AnimatedSwitcher.defaultLayoutBuilder,
  });

  /// The child widget. Must have a distinct [Key] when switching content.
  final Widget? child;

  /// Transition mode preset.
  final M3SwitcherType type;

  /// Duration of the in-transition.
  final Duration duration;

  /// Duration of the out-transition (defaults to [duration]).
  final Duration? reverseDuration;

  /// Curve applied to the incoming child (for scale/slide).
  final Curve switchInCurve;

  /// Curve applied to the outgoing child.
  final Curve switchOutCurve;

  /// Layout builder for child stacking.
  final AnimatedSwitcherLayoutBuilder layoutBuilder;

  Widget _buildTransition(Widget child, Animation<double> animation) {
    // Opacity animation strictly clamped with expressiveDecel
    final Animation<double> fadeAnim = CurvedAnimation(
      parent: animation,
      curve: M3SpringCurves.expressiveDecel,
      reverseCurve: M3SpringCurves.expressiveAccel,
    );

    switch (type) {
      case M3SwitcherType.fadeScale:
        final Animation<double> scaleAnim = CurvedAnimation(
          parent: animation,
          curve: switchInCurve,
          reverseCurve: switchOutCurve,
        );
        return FadeTransition(
          opacity: fadeAnim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1.0).animate(scaleAnim),
            child: child,
          ),
        );

      case M3SwitcherType.fadeSlideY:
        final Animation<Offset> slideAnim = Tween<Offset>(
          begin: const Offset(0.0, 0.12),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: switchInCurve,
          reverseCurve: switchOutCurve,
        ));
        return FadeTransition(
          opacity: fadeAnim,
          child: SlideTransition(
            position: slideAnim,
            child: child,
          ),
        );

      case M3SwitcherType.fadeSlideX:
        final Animation<Offset> slideAnim = Tween<Offset>(
          begin: const Offset(0.12, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: switchInCurve,
          reverseCurve: switchOutCurve,
        ));
        return FadeTransition(
          opacity: fadeAnim,
          child: SlideTransition(
            position: slideAnim,
            child: child,
          ),
        );

      case M3SwitcherType.scale:
        final Animation<double> scaleAnim = CurvedAnimation(
          parent: animation,
          curve: switchInCurve,
          reverseCurve: switchOutCurve,
        );
        return ScaleTransition(
          scale: scaleAnim,
          child: child,
        );

      case M3SwitcherType.fade:
        return FadeTransition(
          opacity: fadeAnim,
          child: child,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (disableAnimations) {
      return child ?? const SizedBox.shrink();
    }

    return AnimatedSwitcher(
      duration: duration,
      reverseDuration: reverseDuration,
      switchInCurve: Curves.linear,
      switchOutCurve: Curves.linear,
      transitionBuilder: _buildTransition,
      layoutBuilder: layoutBuilder,
      child: child,
    );
  }
}
