import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// Material 3 Expressive spring physics presets and curves.
///
/// Based on Google Material 3 Expressive motion specifications:
/// - **Spatial**: For spatial movements, expands, morphs, and container transformations.
/// - **Emphasized**: For prominent visual entries/exits, hero transitions, dialog reveals.
/// - **Snappy**: High stiffness, fast settling for user-initiated gestures, buttons, tabs.
/// - **Bouncy**: Playful tactile overshoot for switches, badges, like reactions, orbs.
/// - **Gentle**: Relaxed, low-frequency motion for subtle background shifts, color transitions.
abstract final class M3Spring {
  /// Spatial spring: mass 1.0, stiffness 220, damping 26 (~damping ratio 0.75)
  static const SpringDescription spatial = SpringDescription(
    mass: 1.0,
    stiffness: 220.0,
    damping: 26.0,
  );

  /// Emphasized spring: mass 1.0, stiffness 200, damping 22 (~damping ratio 0.70)
  static const SpringDescription emphasized = SpringDescription(
    mass: 1.0,
    stiffness: 200.0,
    damping: 22.0,
  );

  /// Snappy spring: mass 1.0, stiffness 340, damping 32 (~damping ratio 0.85)
  static const SpringDescription snappy = SpringDescription(
    mass: 1.0,
    stiffness: 340.0,
    damping: 32.0,
  );

  /// Bouncy spring: mass 1.0, stiffness 260, damping 18 (~damping ratio 0.55)
  static const SpringDescription bouncy = SpringDescription(
    mass: 1.0,
    stiffness: 260.0,
    damping: 18.0,
  );

  /// Gentle spring: mass 1.0, stiffness 150, damping 22 (~damping ratio 0.90)
  static const SpringDescription gentle = SpringDescription(
    mass: 1.0,
    stiffness: 150.0,
    damping: 22.0,
  );
}

/// Damped harmonic oscillator curve simulating spring physics over [0.0, 1.0].
class SpringCurve extends Curve {
  const SpringCurve({
    this.dampingRatio = 0.7,
    this.stiffness = 200.0,
    this.mass = 1.0,
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

  @override
  double transform(double t) {
    if (t <= 0.0) return 0.0;
    if (t >= 1.0) return 1.0;
    return transformInternal(t);
  }

  @override
  double transformInternal(double t) {
    if (t <= 0.0) return 0.0;
    if (t >= 1.0) return 1.0;

    final double omegaN = math.sqrt(stiffness / mass);
    final double zeta = dampingRatio;

    if (zeta < 1.0) {
      final double omegaD = omegaN * math.sqrt(1.0 - zeta * zeta);
      final double decay = math.exp(-zeta * omegaN * t);
      final double response = 1.0 -
          decay *
              (math.cos(omegaD * t) +
                  (zeta * omegaN / omegaD) * math.sin(omegaD * t));
      return response;
    } else {
      final double decay = math.exp(-omegaN * t);
      return 1.0 - decay * (1.0 + omegaN * t);
    }
  }
}

/// Predefined Material 3 Expressive spring curves for use in [AnimatedContainer],
/// [AnimatedScale], [AnimatedTheme], [AnimationController], etc.
abstract final class M3SpringCurves {
  /// Spatial curve: smooth, natural container morph with slight overshoot.
  static const Curve spatial = SpringCurve(
    dampingRatio: 0.75,
    stiffness: 220.0,
  );

  /// Emphasized curve: expressive overshoot for important UI elements.
  static const Curve emphasized = SpringCurve(
    dampingRatio: 0.70,
    stiffness: 200.0,
  );

  /// Snappy curve: immediate responsiveness with tight damping.
  static const Curve snappy = SpringCurve(
    dampingRatio: 0.85,
    stiffness: 340.0,
  );

  /// Bouncy curve: visible, playful bounce for icons, orbs, badges, toggles.
  static const Curve bouncy = SpringCurve(
    dampingRatio: 0.55,
    stiffness: 260.0,
  );

  /// Gentle curve: soft, fluid settling without aggressive bounce.
  static const Curve gentle = SpringCurve(
    dampingRatio: 0.90,
    stiffness: 150.0,
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
}
