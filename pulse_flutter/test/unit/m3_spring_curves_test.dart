import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

double _seconds(Duration duration) =>
    duration.inMicroseconds / Duration.microsecondsPerSecond;

double _peak(Curve curve) {
  double peak = 0.0;
  for (int i = 0; i <= 1000; i++) {
    final double value = curve.transform(i / 1000.0);
    if (value > peak) peak = value;
  }
  return peak;
}

void main() {
  group('M3 Expressive curve tokens', () {
    const spatial = <(Curve, SpringDescription, Duration)>[
      (M3SpringCurves.spatialFast, M3Spring.spatialFast, M3Durations.spatialFast),
      (
        M3SpringCurves.spatialDefault,
        M3Spring.spatialDefault,
        M3Durations.spatialDefault,
      ),
      (M3SpringCurves.spatialSlow, M3Spring.spatialSlow, M3Durations.spatialSlow),
    ];
    const effects = <(Curve, SpringDescription, Duration)>[
      (M3SpringCurves.effectsFast, M3Spring.effectsFast, M3Durations.effectsFast),
      (
        M3SpringCurves.effectsDefault,
        M3Spring.effectsDefault,
        M3Durations.effectsDefault,
      ),
      (M3SpringCurves.effectsSlow, M3Spring.effectsSlow, M3Durations.effectsSlow),
    ];

    test('every token satisfies f(0.0) == 0.0 and f(1.0) == 1.0', () {
      for (final (curve, _, _) in [...spatial, ...effects]) {
        expect(curve.transform(0.0), 0.0);
        expect(curve.transform(1.0), 1.0);
        expect(curve.transform(-0.5), 0.0);
        expect(curve.transform(1.5), 1.0);
      }
    });

    test('curves follow the physical spring over their settle time', () {
      for (final (curve, spring, settle) in [...spatial, ...effects]) {
        final double span = _seconds(settle);
        final sim = SpringSimulation(spring, 0.0, 1.0, 0.0);
        for (int i = 0; i <= 20; i++) {
          final double t = i / 20.0;
          expect(
            curve.transform(t),
            closeTo(sim.x(t * span), 0.005),
            reason: '$spring diverged from its simulation at t=$t',
          );
        }
      }
    });

    test('springs have settled by the end of their duration token', () {
      for (final (_, spring, settle) in [...spatial, ...effects]) {
        final sim = SpringSimulation(spring, 0.0, 1.0, 0.0);
        expect(sim.x(_seconds(settle)), closeTo(1.0, 0.005));
      }
    });

    test('spatial tokens overshoot by the amount their damping ratio gives', () {
      expect(_peak(M3SpringCurves.spatialFast), closeTo(1.095, 0.01));
      expect(_peak(M3SpringCurves.spatialDefault), closeTo(1.015, 0.005));
      expect(_peak(M3SpringCurves.spatialSlow), closeTo(1.015, 0.005));
    });

    test('effects tokens are monotonic and never leave [0.0, 1.0]', () {
      for (final (curve, _, _) in effects) {
        double previous = 0.0;
        for (int i = 0; i <= 200; i++) {
          final double value = curve.transform(i / 200.0);
          expect(value, greaterThanOrEqualTo(previous));
          expect(value, lessThanOrEqualTo(1.0));
          previous = value;
        }
      }
    });
  });
}
