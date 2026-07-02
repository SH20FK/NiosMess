import 'dart:math' as math;

import 'package:flutter/animation.dart';

class AppCurves {
  AppCurves._();

  static const Curve springUp = _SpringCurve(
    mass: 1,
    stiffness: 180,
    damping: 14,
  );

  static const Curve springScale = _SpringCurve(
    mass: 1,
    stiffness: 240,
    damping: 18,
  );

  static const Curve springGentle = _SpringCurve(
    mass: 1,
    stiffness: 120,
    damping: 16,
  );

  static const Curve springBouncy = _SpringCurve(
    mass: 1,
    stiffness: 200,
    damping: 10,
  );

  static const Curve easeOutSnap = Cubic(0.22, 1.0, 0.36, 1.0);

  static const Curve easeOutSmooth = Cubic(0.16, 1.0, 0.3, 1.0);

  static const Curve easeInSmooth = Cubic(0.7, 0.0, 0.84, 0.0);

  static const Curve entrance = Cubic(0.0, 0.0, 0.2, 1.0);
}

class _SpringCurve extends Curve {
  const _SpringCurve({
    required this.mass,
    required this.stiffness,
    required this.damping,
  });

  final double mass;
  final double stiffness;
  final double damping;

  @override
  double transformInternal(double t) {
    final double omega0 = math.sqrt(stiffness / mass);
    final double zeta = damping / (2 * math.sqrt(stiffness * mass));

    if (zeta < 1.0) {
      final double omegaD = omega0 * math.sqrt(1 - zeta * zeta);
      final double decay = zeta * omega0;
      return 1 -
          (math.exp(-decay * t * 6) *
              (math.cos(omegaD * t * 6) +
                  (decay / omegaD) * math.sin(omegaD * t * 6)));
    }

    return 1 - math.exp(-omega0 * t * 6) * (1 + omega0 * t * 6);
  }
}
