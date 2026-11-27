import 'package:material_ui/material_ui.dart';
import 'package:pulse_flutter/core/motion/m3_motion.dart';
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

  /// Spring scale combined with a normalized fade so the outgoing child
  /// never pops.
  scale,
}

/// Material 3 Expressive AnimatedSwitcher.
///
/// Ensures strict mathematical normalization:
/// - Opacity enters on [M3SpringCurves.expressiveDecel] and leaves on
///   [M3SpringCurves.expressiveAccel]; never bouncy/overshoot curves.
/// - Spatial/scale transitions enter on [switchInCurve] and leave on
///   [switchOutCurve], both normalized springs.
/// - Zero per-frame clipping or save-layers.
class M3SpringSwitcher extends StatelessWidget {
  const M3SpringSwitcher({
    required this.child,
    super.key,
    this.type = M3SwitcherType.fadeScale,
    this.duration = const Duration(milliseconds: 300),
    this.reverseDuration,
    this.switchInCurve = M3SpringCurves.spatialDefault,
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
    // The switcher hands every entry a linear animation (Curves.linear in
    // [build]); [DualTransitionBuilder] picks the enter or exit transition
    // from the animation status instead of recreating a [CurvedAnimation]
    // on every rebuild.
    return DualTransitionBuilder(
      animation: animation,
      forwardBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Widget? child,
          ) => _enterTransition(animation, child),
      reverseBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Widget? child,
          ) => _exitTransition(animation, child),
      child: child,
    );
  }

  /// Enter half: the incoming child fades in on the effects spring and
  /// scales or slides in on [switchInCurve].
  Widget _enterTransition(Animation<double> animation, Widget? child) {
    final Animation<double> fadeAnim = animation.drive(
      CurveTween(curve: M3SpringCurves.expressiveDecel),
    );

    switch (type) {
      case M3SwitcherType.fadeScale:
        return FadeTransition(
          opacity: fadeAnim,
          child: ScaleTransition(
            scale: animation.drive(
              Tween<double>(begin: 0.88, end: 1.0).chain(
                CurveTween(curve: switchInCurve),
              ),
            ),
            child: child,
          ),
        );

      case M3SwitcherType.fadeSlideY:
        return FadeTransition(
          opacity: fadeAnim,
          child: SlideTransition(
            position: animation.drive(
              Tween<Offset>(
                begin: const Offset(0.0, 0.12),
                end: Offset.zero,
              ).chain(CurveTween(curve: switchInCurve)),
            ),
            child: child,
          ),
        );

      case M3SwitcherType.fadeSlideX:
        return FadeTransition(
          opacity: fadeAnim,
          child: SlideTransition(
            position: animation.drive(
              Tween<Offset>(
                begin: const Offset(0.12, 0.0),
                end: Offset.zero,
              ).chain(CurveTween(curve: switchInCurve)),
            ),
            child: child,
          ),
        );

      case M3SwitcherType.scale:
        // Scales from 0.6, never from a point, and fades so the swap never
        // pops.
        return FadeTransition(
          opacity: fadeAnim,
          child: ScaleTransition(
            scale: animation.drive(
              Tween<double>(begin: 0.6, end: 1.0).chain(
                CurveTween(curve: switchInCurve),
              ),
            ),
            child: child,
          ),
        );

      case M3SwitcherType.fade:
        return FadeTransition(
          opacity: fadeAnim,
          child: child,
        );
    }
  }

  /// Exit half: the outgoing child fades out on the effects accel spring
  /// and scales or slides away on [switchOutCurve].
  Widget _exitTransition(Animation<double> animation, Widget? child) {
    final Animation<double> fadeAnim = animation.drive(
      Tween<double>(begin: 1.0, end: 0.0).chain(
        CurveTween(curve: M3SpringCurves.expressiveAccel),
      ),
    );

    switch (type) {
      case M3SwitcherType.fadeScale:
        return FadeTransition(
          opacity: fadeAnim,
          child: ScaleTransition(
            scale: animation.drive(
              Tween<double>(begin: 1.0, end: 0.88).chain(
                CurveTween(curve: switchOutCurve),
              ),
            ),
            child: child,
          ),
        );

      case M3SwitcherType.fadeSlideY:
        return FadeTransition(
          opacity: fadeAnim,
          child: SlideTransition(
            position: animation.drive(
              Tween<Offset>(
                begin: Offset.zero,
                end: const Offset(0.0, 0.12),
              ).chain(CurveTween(curve: switchOutCurve)),
            ),
            child: child,
          ),
        );

      case M3SwitcherType.fadeSlideX:
        return FadeTransition(
          opacity: fadeAnim,
          child: SlideTransition(
            position: animation.drive(
              Tween<Offset>(
                begin: Offset.zero,
                end: const Offset(0.12, 0.0),
              ).chain(CurveTween(curve: switchOutCurve)),
            ),
            child: child,
          ),
        );

      case M3SwitcherType.scale:
        return FadeTransition(
          opacity: fadeAnim,
          child: ScaleTransition(
            scale: animation.drive(
              Tween<double>(begin: 1.0, end: 0.6).chain(
                CurveTween(curve: switchOutCurve),
              ),
            ),
            child: child,
          ),
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
    final bool disableAnimations = context.reduceMotion;

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
