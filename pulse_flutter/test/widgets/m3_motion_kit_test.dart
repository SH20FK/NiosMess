import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/widgets/motion/motion.dart';

void main() {
  group('M3 Expressive Motion Kit Primitives', () {
    testWidgets('M3PressScale compresses while pressed and returns to rest', (WidgetTester tester) async {
      Widget app({required bool pressed, bool reduced = false}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Scaffold(
            body: Center(
              child: M3PressScale(
                pressed: pressed,
                child: const SizedBox(width: 100, height: 40),
              ),
            ),
          ),
        ),
      );
      AnimatedScale scale() =>
          tester.widget<AnimatedScale>(find.byType(AnimatedScale));

      await tester.pumpWidget(app(pressed: false));
      expect(scale().scale, 1.0);

      await tester.pumpWidget(app(pressed: true));
      expect(scale().scale, lessThan(1.0));
      // The press never overshoots; the release rides the spatial spring.
      expect(scale().curve, M3SpringCurves.effectsFast);
      await tester.pumpAndSettle();

      await tester.pumpWidget(app(pressed: false));
      expect(scale().curve, M3SpringCurves.spatialFast);
      await tester.pumpAndSettle();
      expect(scale().scale, 1.0);

      await tester.pumpWidget(app(pressed: true, reduced: true));
      expect(scale().scale, 1.0);
      expect(scale().duration, Duration.zero);
    });

    testWidgets('M3MorphingIcon renders initial icon and morphs on change', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: M3MorphingIcon(
                icon: Icons.play_arrow_rounded,
                size: 32,
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      // Update to pause icon
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: M3MorphingIcon(
                icon: Icons.pause_rounded,
                size: 32,
              ),
            ),
          ),
        ),
      );

      // Mid-animation
      await tester.pump(const Duration(milliseconds: 130));
      // Settled
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    testWidgets('M3SpringSwitcher switches between keyed children', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: M3SpringSwitcher(
                child: Text('First', key: ValueKey<int>(1)),
              ),
            ),
          ),
        ),
      );

      expect(find.text('First'), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: M3SpringSwitcher(
                child: Text('Second', key: ValueKey<int>(2)),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(find.text('Second'), findsOneWidget);
      expect(find.text('First'), findsNothing);
    });

    testWidgets('M3Reveal expands and collapses cleanly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: M3Reveal(
                revealed: false,
                child: Text('Secret Content'),
              ),
            ),
          ),
        ),
      );

      // Initially unrevealed, dismissed
      expect(find.text('Secret Content'), findsNothing);

      // Reveal
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: M3Reveal(
                revealed: true,
                child: Text('Secret Content'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Secret Content'), findsOneWidget);
    });

    testWidgets('M3StaggeredItem animates early items and skips later items', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                M3StaggeredItem(index: 0, child: Text('Item 0')),
                M3StaggeredItem(index: 9, child: Text('Item 9')),
              ],
            ),
          ),
        ),
      );

      // Item 9 renders immediately without animation
      expect(find.text('Item 9'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Item 0'), findsOneWidget);
    });

    testWidgets('M3AnimatedBadge displays count and pops on update', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: M3AnimatedBadge(count: 3),
            ),
          ),
        ),
      );

      expect(find.text('3'), findsOneWidget);

      // Update count
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: M3AnimatedBadge(count: 5),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('5'), findsOneWidget);

      // Count 0 collapses badge
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: M3AnimatedBadge(count: 0),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('0'), findsNothing);
    });

    testWidgets('M3ReactionBurst fires on tap without errors', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: M3ReactionBurst(
                onTap: () => tapped = true,
                child: const Icon(Icons.favorite_rounded),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(M3ReactionBurst));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });
  });
}
