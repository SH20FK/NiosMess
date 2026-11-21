import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:pulse_flutter/core/motion/m3_motion.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

void main() {
  group('M3Motion', () {
    test('motions wrap the M3 Expressive spring descriptions', () {
      expect(M3Motion.spatialFast.description, same(M3Spring.spatialFast));
      expect(M3Motion.spatialDefault.description, same(M3Spring.spatialDefault));
      expect(M3Motion.spatialSlow.description, same(M3Spring.spatialSlow));
      expect(M3Motion.effectsFast.description, same(M3Spring.effectsFast));
      expect(M3Motion.effectsDefault.description, same(M3Spring.effectsDefault));
      expect(M3Motion.effectsSlow.description, same(M3Spring.effectsSlow));
    });

    test('normalizeVelocity converts pixel velocity to fractional units', () {
      expect(M3Motion.normalizeVelocity(1200.0, 600.0), 2.0);
      expect(M3Motion.normalizeVelocity(-600.0, 300.0), -2.0);
      expect(M3Motion.normalizeVelocity(500.0, 0.0), 0.0);
    });

    test('simulation starts with the handed-off velocity and settles', () {
      final Simulation sim = M3Motion.spatialDefault.createSimulation(
        start: 0.2,
        end: 1.0,
        velocity: 3.5,
      );

      expect(sim.x(0.0), closeTo(0.2, 1e-4));
      expect(sim.dx(0.0), closeTo(3.5, 1e-4));
      expect(sim.x(5.0), 1.0);
      expect(sim.isDone(5.0), isTrue);
    });

    testWidgets('springTo starts with the gesture velocity', (tester) async {
      final controller = SingleMotionController(
        motion: M3Motion.spatialDefault,
        vsync: const TestVSync(),
      );
      addTearDown(controller.dispose);

      controller.springTo(1.0, velocity: 3.5);
      expect(controller.velocity, closeTo(3.5, 1e-6));

      await tester.pumpAndSettle();
      expect(controller.value, 1.0);
      expect(controller.isAnimating, isFalse);
    });

    testWidgets('springTo keeps velocity when retargeted mid-flight',
        (tester) async {
      final controller = SingleMotionController(
        motion: M3Motion.spatialDefault,
        vsync: const TestVSync(),
      );
      addTearDown(controller.dispose);

      controller.springTo(1.0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final double velocity = controller.velocity;
      expect(velocity, greaterThan(0.0));

      controller.springTo(0.0);
      expect(controller.velocity, closeTo(velocity, 1e-6));

      await tester.pumpAndSettle();
      expect(controller.value, 0.0);
    });

    testWidgets('springTo jumps to the target when motion is reduced',
        (tester) async {
      final controller = SingleMotionController(
        motion: M3Motion.spatialFast,
        vsync: const TestVSync(),
      );
      addTearDown(controller.dispose);

      controller.springTo(1.0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      controller.springTo(0.4, reduceMotion: true);
      expect(controller.value, 0.4);
      expect(controller.isAnimating, isFalse);
    });

    testWidgets('reduceMotion follows MediaQuery.disableAnimations',
        (tester) async {
      late bool reduced;
      late Duration duration;

      Widget probe({required bool disableAnimations}) {
        return MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Builder(
            builder: (BuildContext context) {
              reduced = context.reduceMotion;
              duration = context.motionDuration(M3Durations.spatialDefault);
              return const SizedBox.shrink();
            },
          ),
        );
      }

      await tester.pumpWidget(probe(disableAnimations: true));
      expect(reduced, isTrue);
      expect(duration, Duration.zero);

      await tester.pumpWidget(probe(disableAnimations: false));
      expect(reduced, isFalse);
      expect(duration, M3Durations.spatialDefault);
    });
  });
}
