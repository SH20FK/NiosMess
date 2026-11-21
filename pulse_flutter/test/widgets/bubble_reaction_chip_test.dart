import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/widgets/chat/bubble/bubble_reaction_chip.dart';
import 'package:pulse_flutter/widgets/motion/m3_reaction_burst.dart';

void main() {
  Widget app({
    required int count,
    VoidCallback? onTap,
    bool reduced = false,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Scaffold(
        body: Center(
          child: BubbleReactionChip(
            key: const ValueKey<String>('react_like'),
            label: 'L',
            count: count,
            onTap: onTap,
          ),
        ),
      ),
    ),
  );

  testWidgets('count change animates only the counter, not the whole pill', (
    tester,
  ) async {
    await tester.pumpWidget(app(count: 1));
    await tester.pumpAndSettle();
    final State chipState = tester.state(find.byType(BubbleReactionChip));
    final double labelX = tester.getTopLeft(find.text('L')).dx;

    await tester.pumpWidget(app(count: 2));
    await tester.pump(const Duration(milliseconds: 50));

    // Same pill: it is not recreated and its emoji does not move.
    expect(tester.state(find.byType(BubbleReactionChip)), same(chipState));
    expect(tester.getTopLeft(find.text('L')).dx, closeTo(labelX, 0.001));
    // Old and new counters cross-fade.
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('1'), findsNothing);
    expect(find.text('2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tap reports the reaction and fires the burst', (tester) async {
    var taps = 0;
    await tester.pumpWidget(app(count: 3, onTap: () => taps++));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BubbleReactionChip));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(taps, 1);
    expect(
      find.descendant(
        of: find.byType(M3ReactionBurst),
        matching: find.byType(CustomPaint),
      ),
      findsWidgets,
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion keeps the pill static', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      app(count: 3, onTap: () => taps++, reduced: true),
    );
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.tap(find.byType(BubbleReactionChip));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  group('BubbleReactionRow', () {
    Widget row(Map<String, int> reactions, {bool reduced = false}) =>
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: Scaffold(
              body: Center(
                child: BubbleReactionRow(
                  reactions: reactions,
                  alignEnd: false,
                  labelBuilder: (String key) => key,
                ),
              ),
            ),
          ),
        );

    testWidgets('a removed reaction fades out instead of vanishing', (
      tester,
    ) async {
      await tester.pumpWidget(row(<String, int>{'A': 1, 'B': 2}));
      await tester.pumpAndSettle();

      await tester.pumpWidget(row(<String, int>{'B': 2}));
      await tester.pump(const Duration(milliseconds: 50));

      // The pill is still there mid-exit, already partly transparent.
      // The nearest fade above the emoji is the pill's own; the ones further
      // up belong to the page route.
      expect(find.text('A'), findsOneWidget);
      final FadeTransition fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.text('A'),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, lessThan(1.0));

      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing);
      expect(find.text('B'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a reaction that comes back mid-exit stays', (tester) async {
      await tester.pumpWidget(row(<String, int>{'A': 1, 'B': 2}));
      await tester.pumpAndSettle();

      await tester.pumpWidget(row(<String, int>{'B': 2}));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(row(<String, int>{'A': 1, 'B': 2}));
      await tester.pumpAndSettle();

      expect(find.text('A'), findsOneWidget);
      expect(find.byType(BubbleReactionChip), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the row collapses after the last reaction leaves', (
      tester,
    ) async {
      await tester.pumpWidget(row(<String, int>{'A': 1}));
      await tester.pumpAndSettle();

      await tester.pumpWidget(row(const <String, int>{}));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(BubbleReactionChip), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(BubbleReactionChip), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion removes the pill at once', (tester) async {
      await tester.pumpWidget(
        row(<String, int>{'A': 1, 'B': 2}, reduced: true),
      );
      await tester.pump();

      await tester.pumpWidget(row(<String, int>{'B': 2}, reduced: true));
      await tester.pump();

      expect(find.text('A'), findsNothing);
      expect(find.text('B'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
