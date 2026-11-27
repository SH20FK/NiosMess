import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/modal/m3_modal_route.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

void main() {
  Future<M3ModalRoute<void>> open(
    WidgetTester tester, {
    bool reduced = false,
  }) async {
    late M3ModalRoute<void> route;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                route = M3ModalRoute<void>(
                  context: context,
                  transitionBuilder: M3ModalRoute.scaleTransition,
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      const Center(child: Material(child: Text('dialog'))),
                );
                Navigator.of(context).push<void>(route);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    return route;
  }

  testWidgets('uses the shared scrim and separate enter and exit timing', (
    tester,
  ) async {
    final M3ModalRoute<void> route = await open(tester);
    final ColorScheme scheme = Theme.of(
      tester.element(find.text('open')),
    ).colorScheme;

    expect(route.barrierColor, scheme.scrim.withValues(alpha: 0.32));
    expect(route.barrierCurve, M3SpringCurves.effectsSlow);
    expect(route.transitionDuration, M3Durations.spatialFast);
    expect(route.reverseTransitionDuration, M3Durations.effectsDefault);

    await tester.pumpAndSettle();
    expect(find.text('dialog'), findsOneWidget);
  });

  testWidgets('barrier tap plays the exit before the surface leaves', (
    tester,
  ) async {
    await open(tester);
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(4, 4));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('dialog'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('dialog'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion makes both directions instant', (tester) async {
    final M3ModalRoute<void> route = await open(tester, reduced: true);

    expect(route.transitionDuration, Duration.zero);
    expect(route.reverseTransitionDuration, Duration.zero);

    // No time elapses: the surface is there right after the push frame.
    expect(find.text('dialog'), findsOneWidget);

    Navigator.of(tester.element(find.text('dialog'))).pop();
    await tester.pump();
    await tester.pump();
    expect(find.text('dialog'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
