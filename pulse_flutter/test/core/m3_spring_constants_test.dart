import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

void main() {
  group('M3Spring physics descriptions', () {
    test('all presets have positive mass, stiffness, and damping', () {
      final presets = [
        M3Spring.spatial,
        M3Spring.emphasized,
        M3Spring.snappy,
        M3Spring.bouncy,
        M3Spring.gentle,
      ];

      for (final spring in presets) {
        expect(spring.mass, greaterThan(0));
        expect(spring.stiffness, greaterThan(0));
        expect(spring.damping, greaterThan(0));
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

    test('bouncy curve exhibits characteristic spring overshoot', () {
      bool sawOvershoot = false;
      for (double t = 0.0; t <= 1.0; t += 0.02) {
        final val = M3SpringCurves.bouncy.transform(t);
        if (val > 1.0) {
          sawOvershoot = true;
          break;
        }
      }
      expect(sawOvershoot, isTrue, reason: 'Bouncy curve should overshoot 1.0');
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
