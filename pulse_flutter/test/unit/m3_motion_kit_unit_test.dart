import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

void main() {
  group('M3 Motion Kit & Curves Mathematical Safety Unit Tests', () {
    test('expressive curves for opacity are strictly bounded within [0.0, 1.0]', () {
      final curves = [
        M3SpringCurves.expressiveDecel,
        M3SpringCurves.expressiveStandard,
        M3SpringCurves.expressiveAccel,
      ];

      for (final curve in curves) {
        expect(curve.transform(0.0), closeTo(0.0, 0.001));
        expect(curve.transform(1.0), closeTo(1.0, 0.001));

        for (int i = 0; i <= 100; i++) {
          final double t = i / 100.0;
          final double val = curve.transform(t);
          expect(val, greaterThanOrEqualTo(0.0),
              reason: 'Curve $curve yielded negative value at t=$t');
          expect(val, lessThanOrEqualTo(1.0),
              reason: 'Curve $curve overshot 1.0 at t=$t (unsafe for Opacity)');
        }
      }
    });

    test('M3Durations progression is strictly ascending and complies with M3 spec', () {
      expect(M3Durations.short1 < M3Durations.short2, isTrue);
      expect(M3Durations.short2 < M3Durations.short3, isTrue);
      expect(M3Durations.short3 < M3Durations.short4, isTrue);
      expect(M3Durations.short4 < M3Durations.medium1, isTrue);
      expect(M3Durations.medium1 < M3Durations.medium2, isTrue);
      expect(M3Durations.medium2 < M3Durations.medium3, isTrue);
      expect(M3Durations.medium3 < M3Durations.medium4, isTrue);
      expect(M3Durations.medium4 < M3Durations.long1, isTrue);
      expect(M3Durations.long1 < M3Durations.long2, isTrue);
      expect(M3Durations.long2 < M3Durations.extraLong1, isTrue);
      expect(M3Durations.extraLong1 < M3Durations.extraLong2, isTrue);
    });

    test('SpringCurve underdamped oscillator calculates positive omega', () {
      const curve = SpringCurve(dampingRatio: 0.7, stiffness: 200, mass: 1.0);
      expect(curve.dampingRatio, 0.7);
      expect(curve.stiffness, 200.0);
      expect(curve.mass, 1.0);

      expect(curve.transform(0.0), 0.0);
      expect(curve.transform(1.0), 1.0);
      expect(curve.transform(0.5), greaterThan(0.0));
    });
  });
}
