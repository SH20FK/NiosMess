import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/widgets/nav/m3_route_tab_switcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('M3RouteTabSwitcher Tests', () {
    testWidgets('Steady state renders single IndexedStack with zero RawImage snapshots', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: M3RouteTabSwitcher(
              index: 0,
              children: const <Widget>[
                Text('Tab 0'),
                Text('Tab 1'),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Tab 0'), findsOneWidget);
      expect(find.byType(IndexedStack), findsOneWidget);
      expect(find.byType(RawImage), findsNothing);
    });

    testWidgets('Incoming tab uses strict dp-to-fraction slide and direction awareness', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Widget buildHarness(int idx) {
        return MaterialApp(
          home: Scaffold(
            body: M3RouteTabSwitcher(
              index: idx,
              slideDistance: 20.0,
              duration: const Duration(milliseconds: 200),
              children: const <Widget>[
                Text('Tab 0 Content'),
                Text('Tab 1 Content'),
              ],
            ),
          ),
        );
      }

      await tester.pumpWidget(buildHarness(0));
      await tester.pumpAndSettle();

      // Switch 0 -> 1 (forward: direction +1)
      await tester.pumpWidget(buildHarness(1));

      // Mid-flight check
      await tester.pump(const Duration(milliseconds: 20));

      // Outgoing tab 0 and incoming tab 1 both present
      expect(find.text('Tab 0 Content'), findsOneWidget);
      expect(find.text('Tab 1 Content'), findsOneWidget);

      // Incoming SlideTransition should have dx > 0 (traveling from right)
      // 20dp on 400dp width = 0.05 fraction
      final Finder slideFinder = find.descendant(
        of: find.byType(M3RouteTabSwitcher),
        matching: find.byType(SlideTransition),
      );
      expect(slideFinder, findsOneWidget);
      final SlideTransition slide = tester.widget<SlideTransition>(slideFinder);
      expect(slide.position.value.dx, greaterThan(0.0));
      expect(slide.position.value.dx, lessThanOrEqualTo(0.05));

      // Settle
      await tester.pumpAndSettle();
      expect(find.text('Tab 1 Content'), findsOneWidget);
      expect(find.text('Tab 0 Content'), findsNothing);

      // Now switch 1 -> 0 (backward: direction -1)
      await tester.pumpWidget(buildHarness(0));

      await tester.pump(const Duration(milliseconds: 50));

      final Finder backwardFinder = find.descendant(
        of: find.byType(M3RouteTabSwitcher),
        matching: find.byType(SlideTransition),
      );
      expect(backwardFinder, findsOneWidget);
      final SlideTransition backwardSlide =
          tester.widget<SlideTransition>(backwardFinder);
      expect(backwardSlide.position.value.dx, lessThan(0.0));
      expect(backwardSlide.position.value.dx, greaterThanOrEqualTo(-0.05));

      await tester.pumpAndSettle();
    });

    testWidgets('Outgoing tab strictly fades in place with 0 slide translation', (WidgetTester tester) async {
      int activeIndex = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return M3RouteTabSwitcher(
                  index: activeIndex,
                  slideDistance: 24.0,
                  duration: const Duration(milliseconds: 200),
                  children: const <Widget>[
                    Text('Tab 0 Content'),
                    Text('Tab 1 Content'),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      activeIndex = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return M3RouteTabSwitcher(
                  index: activeIndex,
                  slideDistance: 24.0,
                  duration: const Duration(milliseconds: 200),
                  children: const <Widget>[
                    Text('Tab 0 Content'),
                    Text('Tab 1 Content'),
                  ],
                );
              },
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));

      // There must be exactly ONE SlideTransition in the switcher (for the incoming page).
      // The outgoing page must NOT have a SlideTransition.
      final Finder allSlides = find.descendant(
        of: find.byType(M3RouteTabSwitcher),
        matching: find.byType(SlideTransition),
      );
      expect(allSlides, findsOneWidget);

      // Verify that Tab 1 Content is inside SlideTransition, and Tab 0 is NOT
      expect(
        find.descendant(of: allSlides, matching: find.text('Tab 1 Content')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: allSlides, matching: find.text('Tab 0 Content')),
        findsNothing,
      );

      await tester.pumpAndSettle();
    });

    testWidgets('Rapid taps (0 -> 2 -> 1) retarget cleanly without throwing or glitching', (WidgetTester tester) async {
      int activeIndex = 0;

      Widget buildWidget(int idx) {
        return MaterialApp(
          home: Scaffold(
            body: M3RouteTabSwitcher(
              index: idx,
              duration: const Duration(milliseconds: 200),
              children: const <Widget>[
                Text('Tab 0'),
                Text('Tab 1'),
                Text('Tab 2'),
              ],
            ),
          ),
        );
      }

      await tester.pumpWidget(buildWidget(0));
      await tester.pumpAndSettle();

      // Tap to Tab 2
      activeIndex = 2;
      await tester.pumpWidget(buildWidget(activeIndex));
      await tester.pump(const Duration(milliseconds: 50));

      // Mid-flight tap to Tab 1
      activeIndex = 1;
      await tester.pumpWidget(buildWidget(activeIndex));
      await tester.pump(const Duration(milliseconds: 20));

      // Clean retargeting: Tab 1 is now incoming
      expect(find.text('Tab 1'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Tab 1'), findsOneWidget);
      expect(find.text('Tab 0'), findsNothing);
      expect(find.text('Tab 2'), findsNothing);
    });

    testWidgets('onTransitionStateChanged notifies true on start and false on finish', (WidgetTester tester) async {
      final List<bool> transitions = <bool>[];

      Widget buildWidget(int idx) {
        return MaterialApp(
          home: Scaffold(
            body: M3RouteTabSwitcher(
              index: idx,
              duration: const Duration(milliseconds: 150),
              onTransitionStateChanged: (bool running) => transitions.add(running),
              children: const <Widget>[
                Text('Tab 0'),
                Text('Tab 1'),
              ],
            ),
          ),
        );
      }

      await tester.pumpWidget(buildWidget(0));
      await tester.pumpAndSettle();
      expect(transitions, isEmpty);

      // Trigger transition
      await tester.pumpWidget(buildWidget(1));
      expect(transitions.last, isTrue);

      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(transitions.last, isFalse);
    });

    testWidgets('animate: false performs instant swap', (WidgetTester tester) async {
      Widget buildWidget(int idx) {
        return MaterialApp(
          home: Scaffold(
            body: M3RouteTabSwitcher(
              index: idx,
              animate: false,
              children: const <Widget>[
                Text('Tab 0'),
                Text('Tab 1'),
              ],
            ),
          ),
        );
      }

      await tester.pumpWidget(buildWidget(0));
      await tester.pump();
      expect(find.text('Tab 0'), findsOneWidget);

      await tester.pumpWidget(buildWidget(1));
      await tester.pump();

      expect(find.text('Tab 1'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(M3RouteTabSwitcher),
          matching: find.byType(SlideTransition),
        ),
        findsNothing,
      );
    });

    testWidgets('Subtree state survives across tab transitions', (WidgetTester tester) async {
      final TextEditingController textController = TextEditingController(text: 'Persistent state');

      Widget buildWidget(int idx) {
        return MaterialApp(
          home: Scaffold(
            body: M3RouteTabSwitcher(
              index: idx,
              children: <Widget>[
                TextField(controller: textController),
                const Text('Tab 1 Content'),
              ],
            ),
          ),
        );
      }

      await tester.pumpWidget(buildWidget(0));
      await tester.pumpAndSettle();
      expect(find.text('Persistent state'), findsOneWidget);

      // Switch 0 -> 1
      await tester.pumpWidget(buildWidget(1));
      await tester.pumpAndSettle();
      expect(find.text('Tab 1 Content'), findsOneWidget);

      // Switch 1 -> 0
      await tester.pumpWidget(buildWidget(0));
      await tester.pumpAndSettle();
      expect(find.text('Persistent state'), findsOneWidget);
      expect(textController.text, 'Persistent state');
    });
  });
}
