import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

void main() {
  group('M3SpringCurves Normalized Mathematical Physics', () {
    test('all 5 curves strictly satisfy f(0.0) == 0.0 and f(1.0) == 1.0 boundary conditions', () {
      final curves = [
        M3SpringCurves.spatial,
        M3SpringCurves.emphasized,
        M3SpringCurves.snappy,
        M3SpringCurves.bouncy,
        M3SpringCurves.gentle,
      ];

      for (final curve in curves) {
        expect(curve.transform(0.0), 0.0);
        expect(curve.transform(1.0), 1.0);
        expect(curve.transform(-0.5), 0.0);
        expect(curve.transform(1.5), 1.0);
      }
    });

    test('spatial curve moves smoothly throughout full duration interval', () {
      final spatial = M3SpringCurves.spatial;

      final double v25 = spatial.transform(0.25);
      final double v50 = spatial.transform(0.50);
      final double v75 = spatial.transform(0.75);
      final double v100 = spatial.transform(1.0);

      // Verify progression is spread across the entire duration (not collapsed into first 25%)
      expect(v25, closeTo(0.47, 0.06));
      expect(v50, closeTo(0.89, 0.06));
      expect(v75, closeTo(1.00, 0.05));
      expect(v100, 1.0);

      // Must not settle prematurely at t=0.25
      expect(v25 < 0.60, isTrue);
      expect(v50 > v25, isTrue);
    });

    test('bouncy curve provides perceptible overshoot near midpoint', () {
      final bouncy = M3SpringCurves.bouncy;

      final double v50 = bouncy.transform(0.50);

      // With stiffness 58 and dampingRatio 0.55, overshoot is ~1.145 (14.5%)
      expect(v50, greaterThan(1.05));
      expect(v50, closeTo(1.145, 0.05));
    });

    test('gentle curve is strictly monotonic and never overshoots 1.0', () {
      final gentle = M3SpringCurves.gentle;

      double previous = 0.0;
      for (int i = 0; i <= 100; i++) {
        final double t = i / 100.0;
        final double val = gentle.transform(t);
        expect(val, greaterThanOrEqualTo(previous));
        expect(val, lessThanOrEqualTo(1.0));
        previous = val;
      }
    });
  });
}
