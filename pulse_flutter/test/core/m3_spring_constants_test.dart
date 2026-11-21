import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

double _dampingRatio(SpringDescription spring) =>
    spring.damping / (2.0 * math.sqrt(spring.stiffness * spring.mass));

void main() {
  group('M3 Expressive spring tokens', () {
    test('spatial tokens match the spec stiffness and damping ratio', () {
      expect(M3Spring.spatialFast.stiffness, 800.0);
      expect(_dampingRatio(M3Spring.spatialFast), closeTo(0.6, 1e-9));

      expect(M3Spring.spatialDefault.stiffness, 380.0);
      expect(_dampingRatio(M3Spring.spatialDefault), closeTo(0.8, 1e-9));

      expect(M3Spring.spatialSlow.stiffness, 200.0);
      expect(_dampingRatio(M3Spring.spatialSlow), closeTo(0.8, 1e-9));
    });

    test('effects tokens are critically damped', () {
      expect(M3Spring.effectsFast.stiffness, 3800.0);
      expect(_dampingRatio(M3Spring.effectsFast), closeTo(1.0, 1e-9));

      expect(M3Spring.effectsDefault.stiffness, 1600.0);
      expect(_dampingRatio(M3Spring.effectsDefault), closeTo(1.0, 1e-9));

      expect(M3Spring.effectsSlow.stiffness, 800.0);
      expect(_dampingRatio(M3Spring.effectsSlow), closeTo(1.0, 1e-9));
    });

    test('all tokens use unit mass', () {
      final tokens = [
        M3Spring.spatialFast,
        M3Spring.spatialDefault,
        M3Spring.spatialSlow,
        M3Spring.effectsFast,
        M3Spring.effectsDefault,
        M3Spring.effectsSlow,
      ];
      for (final spring in tokens) {
        expect(spring.mass, 1.0);
      }
    });
  });

  group('SpringCurve transform tests', () {
    test('transform returns 0.0 at t=0 and 1.0 at t=1', () {
      const curve = SpringCurve(dampingRatio: 0.7, stiffness: 200);
      expect(curve.transform(0.0), 0.0);
      expect(curve.transform(1.0), 1.0);
    });

    test('transform clamps out of range values', () {
      const curve = SpringCurve(dampingRatio: 0.7, stiffness: 200);
      expect(curve.transform(-0.5), 0.0);
      expect(curve.transform(1.5), 1.0);
    });

    test('spatialFast curve exhibits characteristic spring overshoot', () {
      bool sawOvershoot = false;
      for (double t = 0.0; t <= 1.0; t += 0.02) {
        final val = M3SpringCurves.spatialFast.transform(t);
        if (val > 1.0) {
          sawOvershoot = true;
          break;
        }
      }
      expect(sawOvershoot, isTrue, reason: 'spatialFast should overshoot 1.0');
    });

    test('critically damped or overdamped spring settles cleanly', () {
      const overdamped = SpringCurve(dampingRatio: 1.2, stiffness: 200);
      expect(overdamped.transform(0.0), 0.0);
      expect(overdamped.transform(1.0), 1.0);
      for (double t = 0.0; t <= 1.0; t += 0.05) {
        final val = overdamped.transform(t);
        expect(val, inInclusiveRange(0.0, 1.0));
      }
    });

    test('normalization guarantees continuity near t=1.0 without step jumps', () {
      final curves = [
        M3SpringCurves.spatialFast,
        M3SpringCurves.spatialDefault,
        M3SpringCurves.spatialSlow,
        M3SpringCurves.effectsFast,
        M3SpringCurves.effectsDefault,
        M3SpringCurves.effectsSlow,
      ];
      for (final curve in curves) {
        final valNearEnd = curve.transform(0.999);
        final valEnd = curve.transform(1.0);
        expect((valEnd - valNearEnd).abs(), lessThan(0.01),
            reason: 'Curve $curve should not have an abrupt step discontinuity at 1.0');
      }
    });
  });

  group('Bounded M3 easing curves for opacity/alpha safety', () {
    test('expressiveDecel, expressiveStandard, expressiveAccel are strictly within [0.0, 1.0]', () {
      final safeCurves = [
        M3SpringCurves.expressiveDecel,
        M3SpringCurves.expressiveStandard,
        M3SpringCurves.expressiveAccel,
      ];

      for (final curve in safeCurves) {
        for (double t = 0.0; t <= 1.0; t += 0.01) {
          final val = curve.transform(t);
          expect(
            val,
            inInclusiveRange(0.0, 1.0),
            reason: '$curve exceeded [0.0, 1.0] at t=$t with val=$val',
          );
        }
      }
    });
  });

  group('M3Durations tokens', () {
    test('durations are monotonically ordered within families', () {
      expect(M3Durations.short1 < M3Durations.short2, isTrue);
      expect(M3Durations.short2 < M3Durations.short3, isTrue);
      expect(M3Durations.short3 < M3Durations.short4, isTrue);

      expect(M3Durations.medium1 < M3Durations.medium2, isTrue);
      expect(M3Durations.medium2 < M3Durations.medium3, isTrue);
      expect(M3Durations.medium3 < M3Durations.medium4, isTrue);

      expect(M3Durations.long1 < M3Durations.long2, isTrue);
      expect(M3Durations.extraLong1 < M3Durations.extraLong2, isTrue);
    });
  });
}
