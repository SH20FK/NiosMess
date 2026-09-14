import 'package:flutter/animation.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

class AppCurves {
  AppCurves._();

  /// Legacy spring preset; redirected to [M3SpringCurves.spatial].
  static const Curve springUp = M3SpringCurves.spatial;

  /// Legacy spring preset; redirected to [M3SpringCurves.snappy].
  static const Curve springScale = M3SpringCurves.snappy;

  /// Legacy spring preset; redirected to [M3SpringCurves.gentle].
  static const Curve springGentle = M3SpringCurves.gentle;

  /// Legacy spring preset; redirected to [M3SpringCurves.bouncy].
  static const Curve springBouncy = M3SpringCurves.bouncy;

  static const Curve easeOutSnap = Cubic(0.22, 1.0, 0.36, 1.0);

  static const Curve easeOutSmooth = Cubic(0.16, 1.0, 0.3, 1.0);

  static const Curve easeInSmooth = Cubic(0.7, 0.0, 0.84, 0.0);

  static const Curve entrance = Cubic(0.0, 0.0, 0.2, 1.0);
}
