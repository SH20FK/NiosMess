import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/widgets/motion/m3_entrance.dart';

void main() {
  Widget app({Duration delay = Duration.zero, bool reduced = false}) =>
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Scaffold(
            body: Center(
              child: const Text(
                'hello',
              ).entrance(delay: delay, scaleFrom: 0.8, offsetY: 12),
            ),
          ),
        ),
      );

  double opacity(WidgetTester tester) => tester
      .widget<FadeTransition>(
        find.descendant(
          of: find.byType(M3Entrance),
          matching: find.byType(FadeTransition),
        ),
      )
      .opacity
      .value;

  testWidgets('plays once and settles at rest', (tester) async {
    await tester.pumpWidget(app());
    expect(opacity(tester), 0.0);

    await tester.pump(const Duration(milliseconds: 100));
    expect(opacity(tester), inExclusiveRange(0.0, 1.0));

    await tester.pumpAndSettle();
    expect(opacity(tester), 1.0);
    final double rest = tester.getCenter(find.text('hello')).dy;

    // A rebuild does not replay the entrance.
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 50));
    expect(opacity(tester), 1.0);
    expect(tester.getCenter(find.text('hello')).dy, closeTo(rest, 0.001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('delay keeps the child hidden until its turn', (tester) async {
    await tester.pumpWidget(app(delay: const Duration(milliseconds: 200)));
    await tester.pump(const Duration(milliseconds: 150));
    expect(opacity(tester), 0.0);

    await tester.pump(const Duration(milliseconds: 150));
    expect(opacity(tester), greaterThan(0.0));
    expect(opacity(tester), lessThanOrEqualTo(1.0));

    await tester.pumpAndSettle();
    expect(opacity(tester), 1.0);
  });

  testWidgets('reduced motion shows the child at rest', (tester) async {
    await tester.pumpWidget(
      app(delay: const Duration(milliseconds: 200), reduced: true),
    );
    expect(opacity(tester), 1.0);
    expect(tester.binding.transientCallbackCount, 0);
  });
}
