import 'package:material_ui/material_ui.dart';
import 'package:pulse_flutter/core/motion/m3_motion.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

/// Scrim shared by every modal surface: dialogs, bottom sheets, side sheets.
Color modalScrimColor(BuildContext context) =>
    ColorScheme.of(context).scrim.withValues(alpha: 0.32);

/// Modal route with separate enter and exit timing.
///
/// The scrim fades on an effects curve while the transition builder moves the
/// surface. With reduced motion both directions are instant.
class M3ModalRoute<T> extends RawDialogRoute<T> {
  M3ModalRoute({
    required BuildContext context,
    required super.pageBuilder,
    super.transitionBuilder,
    super.barrierDismissible,
    super.settings,
    String? barrierLabel,
    Duration enterDuration = M3Durations.spatialFast,
    Duration exitDuration = M3Durations.effectsDefault,
  }) : _exitDuration = context.reduceMotion ? Duration.zero : exitDuration,
       super(
         barrierLabel:
             barrierLabel ??
             MaterialLocalizations.of(context).modalBarrierDismissLabel,
         barrierColor: modalScrimColor(context),
         transitionDuration: context.reduceMotion
             ? Duration.zero
             : enterDuration,
       );

  final Duration _exitDuration;

  static const Curve _fadeIn = Interval(
    0.0,
    0.4,
    curve: M3SpringCurves.effectsDefault,
  );

  @override
  Duration get reverseTransitionDuration => _exitDuration;

  @override
  Curve get barrierCurve => M3SpringCurves.effectsSlow;

  /// Centered surface: scales in on the default spatial spring and fades on
  /// effects curves; the exit has no overshoot.
  static Widget scaleTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return DualTransitionBuilder(
      animation: animation,
      forwardBuilder:
          (BuildContext context, Animation<double> animation, Widget? child) =>
              FadeTransition(
                opacity: animation.drive(CurveTween(curve: _fadeIn)),
                child: ScaleTransition(
                  scale: animation.drive(
                    Tween<double>(begin: 0.9, end: 1.0).chain(
                      CurveTween(curve: M3SpringCurves.spatialDefault),
                    ),
                  ),
                  child: child,
                ),
              ),
      reverseBuilder:
          (BuildContext context, Animation<double> animation, Widget? child) =>
              FadeTransition(
                opacity: animation.drive(
                  Tween<double>(begin: 1.0, end: 0.0).chain(
                    CurveTween(curve: M3SpringCurves.effectsDefault),
                  ),
                ),
                child: ScaleTransition(
                  scale: animation.drive(
                    Tween<double>(begin: 1.0, end: 0.96).chain(
                      CurveTween(curve: M3SpringCurves.expressiveAccel),
                    ),
                  ),
                  child: child,
                ),
              ),
      child: child,
    );
  }

  /// Surface attached to the right edge. It never overshoots: a spring
  /// overshoot would open a gap between the surface and the screen edge.
  static Widget sideTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return DualTransitionBuilder(
      animation: animation,
      forwardBuilder:
          (BuildContext context, Animation<double> animation, Widget? child) =>
              SlideTransition(
                position: animation.drive(
                  Tween<Offset>(
                    begin: const Offset(1.0, 0.0),
                    end: Offset.zero,
                  ).chain(CurveTween(curve: M3SpringCurves.expressiveDecel)),
                ),
                child: child,
              ),
      reverseBuilder:
          (BuildContext context, Animation<double> animation, Widget? child) =>
              SlideTransition(
                position: animation.drive(
                  Tween<Offset>(
                    begin: Offset.zero,
                    end: const Offset(1.0, 0.0),
                  ).chain(CurveTween(curve: M3SpringCurves.expressiveAccel)),
                ),
                child: child,
              ),
      child: child,
    );
  }
}
