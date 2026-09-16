import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/motion/nios_motion.dart';

void main() {
  group('NiosMotion Physics Engine (NF-1...NF-5)', () {
    test('Canonical 5 springs have correct physical properties', () {
      expect(NiosMotion.spatial.mass, 1.0);
      expect(NiosMotion.spatial.stiffness, 220.0);
      expect(NiosMotion.spatial.damping, 26.0);

      expect(NiosMotion.emphasized.mass, 1.0);
      expect(NiosMotion.emphasized.stiffness, 200.0);
      expect(NiosMotion.emphasized.damping, 22.0);

      expect(NiosMotion.snappy.mass, 1.0);
      expect(NiosMotion.snappy.stiffness, 340.0);
      expect(NiosMotion.snappy.damping, 32.0);

      expect(NiosMotion.bouncy.mass, 1.0);
      expect(NiosMotion.bouncy.stiffness, 260.0);
      expect(NiosMotion.bouncy.damping, 18.0);

      expect(NiosMotion.gentle.mass, 1.0);
      expect(NiosMotion.gentle.stiffness, 150.0);
      expect(NiosMotion.gentle.damping, 22.0);
    });

    test('normalizeVelocity accurately converts pixel velocity to fractional units', () {
      expect(NiosMotion.normalizeVelocity(1200.0, 600.0), 2.0);
      expect(NiosMotion.normalizeVelocity(-600.0, 300.0), -2.0);
      expect(NiosMotion.normalizeVelocity(500.0, 0.0), 0.0);
    });

    test('simulate preserves initial velocity without discontinuity at t=0', () {
      const double initialVelocity = 3.5;
      final sim = NiosMotion.simulate(
        spring: NiosMotion.spatial,
        from: 0.2,
        to: 1.0,
        velocity: initialVelocity,
      );

      // Value at t=0 must match start
      expect(sim.x(0.0), closeTo(0.2, 0.0001));

      // Velocity at t=0 must strictly equal initial velocity (uninterrupted handoff)
      expect(sim.dx(0.0), closeTo(initialVelocity, 0.0001));

      // As time advances, simulation must settle near target
      expect(sim.x(5.0), closeTo(1.0, 0.01));
      expect(sim.isDone(5.0), isTrue);
    });

    test('Spring simulation handles reverse bounce settling', () {
      final sim = NiosMotion.simulate(
        spring: NiosMotion.snappy,
        from: 0.8,
        to: 0.0,
        velocity: -1.5,
      );

      expect(sim.x(0.0), closeTo(0.8, 0.0001));
      expect(sim.dx(0.0), closeTo(-1.5, 0.0001));
      expect(sim.x(4.0), closeTo(0.0, 0.01));
    });
  });
}
