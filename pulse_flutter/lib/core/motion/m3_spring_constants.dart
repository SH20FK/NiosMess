import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// Material 3 Expressive spring tokens as physical [SpringDescription]s.
///
/// The six `spatial*` / `effects*` tokens carry the M3 Expressive numbers
/// (stiffness / damping ratio, mass 1):
/// - **spatial** moves position, size and shape and may overshoot:
///   fast 800 / 0.6, default 380 / 0.8, slow 200 / 0.8.
/// - **effects** drives opacity and colour and never overshoots:
///   fast 3800 / 1.0, default 1600 / 1.0, slow 800 / 1.0.
abstract final class M3Spring {
  /// Fast spatial spring: stiffness 800, damping ratio 0.6.
  static const SpringDescription spatialFast = SpringDescription(
    mass: 1.0,
    stiffness: 800.0,
    damping: 33.941125496954285,
  );

  /// Default spatial spring: stiffness 380, damping ratio 0.8.
  static const SpringDescription spatialDefault = SpringDescription(
    mass: 1.0,
    stiffness: 380.0,
    damping: 31.18974190338868,
  );

  /// Slow spatial spring: stiffness 200, damping ratio 0.8.
  static const SpringDescription spatialSlow = SpringDescription(
    mass: 1.0,
    stiffness: 200.0,
    damping: 22.627416997969522,
  );

  /// Fast effects spring: stiffness 3800, damping ratio 1.0.
  static const SpringDescription effectsFast = SpringDescription(
    mass: 1.0,
    stiffness: 3800.0,
    damping: 123.28828005937953,
  );

  /// Default effects spring: stiffness 1600, damping ratio 1.0.
  static const SpringDescription effectsDefault = SpringDescription(
    mass: 1.0,
    stiffness: 1600.0,
    damping: 80.0,
  );

  /// Slow effects spring: stiffness 800, damping ratio 1.0.
  static const SpringDescription effectsSlow = SpringDescription(
    mass: 1.0,
    stiffness: 800.0,
    damping: 56.568542494923804,
  );
}

/// Damped harmonic oscillator response mapped onto a [Curve].
///
/// The response is sampled over [settleTime] of real spring time and
/// normalised so that `f(0) == 0` and `f(1) == 1`. Give the animation a
/// duration equal to [settleTime] to play the spring at its physical speed.
class SpringCurve extends Curve {
  const SpringCurve({
    this.dampingRatio = 0.7,
    this.stiffness = 200.0,
    this.mass = 1.0,
    this.settleTime = const Duration(seconds: 1),
  });

  /// Damping ratio ($\zeta$).
  /// - $\zeta < 1.0$: Underdamped (oscillates / overshoots).
  /// - $\zeta = 1.0$: Critically damped.
  /// - $\zeta > 1.0$: Overdamped.
  final double dampingRatio;

  /// Spring stiffness ($k$).
  final double stiffness;

  /// Spring mass ($m$).
  final double mass;

  /// Real spring time covered by the curve's [0.0, 1.0] interval.
  final Duration settleTime;

  double _rawResponse(double t) {
    final double omegaN = math.sqrt(stiffness / mass);
    final double zeta = dampingRatio;

    if (zeta < 1.0) {
      final double omegaD = omegaN * math.sqrt(1.0 - zeta * zeta);
      final double decay = math.exp(-zeta * omegaN * t);
      return 1.0 -
          decay *
              (math.cos(omegaD * t) +
                  (zeta * omegaN / omegaD) * math.sin(omegaD * t));
    } else if (zeta == 1.0) {
      final double decay = math.exp(-omegaN * t);
      return 1.0 - decay * (1.0 + omegaN * t);
    } else {
      final double root = omegaN * math.sqrt(zeta * zeta - 1.0);
      final double r1 = -zeta * omegaN + root;
      final double r2 = -zeta * omegaN - root;
      return 1.0 - (r2 * math.exp(r1 * t) - r1 * math.exp(r2 * t)) / (r2 - r1);
    }
  }

  @override
  double transform(double t) {
    if (t < 0.0) return 0.0;
    if (t > 1.0) return 1.0;
    return transformInternal(t);
  }

  @override
  double transformInternal(double t) {
    final double span =
        settleTime.inMicroseconds / Duration.microsecondsPerSecond;
    final double raw = _rawResponse(t * span);
    final double rawEnd = _rawResponse(span);
    if (rawEnd == 0.0) return raw;
    return raw / rawEnd;
  }
}

/// Predefined Material 3 Expressive spring curves for use in [AnimatedContainer],
/// [AnimatedScale], [AnimatedTheme], [AnimationController], etc.
abstract final class M3SpringCurves {
  /// Fast spatial spring (800 / 0.6), overshoots by about 9 %.
  /// Pair with [M3Durations.spatialFast].
  static const Curve spatialFast = SpringCurve(
    dampingRatio: 0.6,
    stiffness: 800.0,
    settleTime: M3Durations.spatialFast,
  );

  /// Default spatial spring (380 / 0.8), overshoots by about 1.5 %.
  /// Pair with [M3Durations.spatialDefault].
  static const Curve spatialDefault = SpringCurve(
    dampingRatio: 0.8,
    stiffness: 380.0,
    settleTime: M3Durations.spatialDefault,
  );

  /// Slow spatial spring (200 / 0.8), overshoots by about 1.5 %.
  /// Pair with [M3Durations.spatialSlow].
  static const Curve spatialSlow = SpringCurve(
    dampingRatio: 0.8,
    stiffness: 200.0,
    settleTime: M3Durations.spatialSlow,
  );

  /// Fast effects spring (3800 / 1.0), stays within [0.0, 1.0].
  /// Pair with [M3Durations.effectsFast].
  static const Curve effectsFast = SpringCurve(
    dampingRatio: 1.0,
    stiffness: 3800.0,
    settleTime: M3Durations.effectsFast,
  );

  /// Default effects spring (1600 / 1.0), stays within [0.0, 1.0].
  /// Pair with [M3Durations.effectsDefault].
  static const Curve effectsDefault = SpringCurve(
    dampingRatio: 1.0,
    stiffness: 1600.0,
    settleTime: M3Durations.effectsDefault,
  );

  /// Slow effects spring (800 / 1.0), stays within [0.0, 1.0].
  /// Pair with [M3Durations.effectsSlow].
  static const Curve effectsSlow = SpringCurve(
    dampingRatio: 1.0,
    stiffness: 800.0,
    settleTime: M3Durations.effectsSlow,
  );

  /// Material 3 Expressive decelerate curve (guaranteed strictly in [0.0, 1.0]).
  /// Safe for [FadeTransition], [AnimatedOpacity], [Opacity], and alpha animations.
  static const Curve expressiveDecel = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Material 3 Expressive standard easing curve (strictly in [0.0, 1.0]).
  static const Curve expressiveStandard = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Material 3 Expressive accelerate curve for exits (strictly in [0.0, 1.0]).
  static const Curve expressiveAccel = Cubic(0.3, 0.0, 0.8, 0.15);
}

/// Material 3 Expressive duration tokens.
abstract final class M3Durations {
  static const Duration short1 = Duration(milliseconds: 50);
  static const Duration short2 = Duration(milliseconds: 100);
  static const Duration short3 = Duration(milliseconds: 150);
  static const Duration short4 = Duration(milliseconds: 200);

  static const Duration medium1 = Duration(milliseconds: 250);
  static const Duration medium2 = Duration(milliseconds: 300);
  static const Duration medium3 = Duration(milliseconds: 350);
  static const Duration medium4 = Duration(milliseconds: 400);

  static const Duration long1 = Duration(milliseconds: 450);
  static const Duration long2 = Duration(milliseconds: 500);

  static const Duration extraLong1 = Duration(milliseconds: 700);
  static const Duration extraLong2 = Duration(milliseconds: 1000);

  // Settle times of the M3 Expressive springs, for the matching
  // [M3SpringCurves] tokens.
  static const Duration spatialFast = Duration(milliseconds: 350);
  static const Duration spatialDefault = Duration(milliseconds: 500);
  static const Duration spatialSlow = Duration(milliseconds: 650);
  static const Duration effectsFast = Duration(milliseconds: 150);
  static const Duration effectsDefault = Duration(milliseconds: 200);
  static const Duration effectsSlow = Duration(milliseconds: 300);
}
