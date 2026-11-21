import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

/// M3 Expressive springs as `motor` motions.
///
/// Use these with [MotionController] or [MotionBuilder] wherever motion
/// follows a gesture or can be retargeted mid-flight: the controller keeps its
/// velocity when the target changes. Widgets that only accept a duration and a
/// curve take [M3SpringCurves] with the matching [M3Durations] instead.
abstract final class M3Motion {
  static const SpringMotion spatialFast = SpringMotion(
    M3Spring.spatialFast,
    snapToEnd: true,
  );

  static const SpringMotion spatialDefault = SpringMotion(
    M3Spring.spatialDefault,
    snapToEnd: true,
  );

  static const SpringMotion spatialSlow = SpringMotion(
    M3Spring.spatialSlow,
    snapToEnd: true,
  );

  static const SpringMotion effectsFast = SpringMotion(
    M3Spring.effectsFast,
    snapToEnd: true,
  );

  static const SpringMotion effectsDefault = SpringMotion(
    M3Spring.effectsDefault,
    snapToEnd: true,
  );

  static const SpringMotion effectsSlow = SpringMotion(
    M3Spring.effectsSlow,
    snapToEnd: true,
  );

  /// Converts a gesture velocity in logical pixels per second into units per
  /// second for a controller whose value is a fraction of [dimension].
  static double normalizeVelocity(double pixelVelocity, double dimension) {
    if (dimension <= 0.0) return 0.0;
    return pixelVelocity / dimension;
  }
}

/// Single way to read the platform's reduce-motion setting.
extension M3ReduceMotion on BuildContext {
  bool get reduceMotion => MediaQuery.maybeDisableAnimationsOf(this) ?? false;

  /// [duration], or [Duration.zero] when motion is reduced.
  Duration motionDuration(Duration duration) =>
      reduceMotion ? Duration.zero : duration;
}

extension M3MotionControllerSpring<T extends Object> on MotionController<T> {
  /// Springs to [target]. The current velocity carries over unless [velocity]
  /// is given, e.g. from the end of a drag. With [reduceMotion] the value
  /// jumps to [target].
  TickerFuture springTo(
    T target, {
    T? velocity,
    bool reduceMotion = false,
  }) {
    if (reduceMotion) {
      // BoundedMotionController's value setter leaves the ticker running.
      stop(canceled: true);
      value = target;
      return TickerFuture.complete();
    }
    return animateTo(target, withVelocity: velocity);
  }
}
