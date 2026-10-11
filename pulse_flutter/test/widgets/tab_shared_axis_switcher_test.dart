import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/widgets/nav/tab_shared_axis_switcher.dart';
import 'package:pulse_flutter/widgets/app_bottom_nav.dart';

class _NavTestSettings extends UiSettingsNotifier {
  @override
  UiSettingsState build() => const UiSettingsState.defaults().copyWith(soundEffects: false);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TabSharedAxisSwitcher Tests', () {
    testWidgets('Steady state returns live IndexedStack without RawImage', (WidgetTester tester) async {
      final TabTransitionController controller = TabTransitionController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TabSharedAxisSwitcher(
              index: 0,
              controller: controller,
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
      expect(find.byType(RawImage), findsNothing);
    });

    testWidgets('Forward transition animates outgoing snapshot and incoming tab', (WidgetTester tester) async {
      final TabTransitionController controller = TabTransitionController();
      int activeIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return TabSharedAxisSwitcher(
                  index: activeIndex,
                  controller: controller,
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

      // Capture outgoing and switch index
      controller.captureOutgoing();
      activeIndex = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return TabSharedAxisSwitcher(
                  index: activeIndex,
                  controller: controller,
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

      // Mid-flight: pump partial duration
      await tester.pump(const Duration(milliseconds: 130));
      await tester.pump();
      expect(find.text('Tab 1 Content'), findsOneWidget);

      // Settle completely
      await tester.pumpAndSettle();

      // After settling, snapshot is disposed and removed from tree
      expect(find.byType(RawImage), findsNothing);
      expect(find.text('Tab 1 Content'), findsOneWidget);
    });

    testWidgets('animate: false performs instant swap without RawImage', (WidgetTester tester) async {
      final TabTransitionController controller = TabTransitionController();
      int activeIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return TabSharedAxisSwitcher(
                  index: activeIndex,
                  controller: controller,
                  animate: false,
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
      await tester.pump();

      activeIndex = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return TabSharedAxisSwitcher(
                  index: activeIndex,
                  controller: controller,
                  animate: false,
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
      await tester.pump();

      expect(find.text('Tab 1 Content'), findsOneWidget);
      expect(find.byType(RawImage), findsNothing);
    });

    testWidgets('Child subtree state survives across tab transitions', (WidgetTester tester) async {
      final TabTransitionController controller = TabTransitionController();
      final TextEditingController textController = TextEditingController(text: 'Persistent state');

      Widget buildHarness(int index) {
        return MaterialApp(
          home: Scaffold(
            body: TabSharedAxisSwitcher(
              index: index,
              controller: controller,
              children: <Widget>[
                TextField(controller: textController),
                const Text('Tab 1 Content'),
              ],
            ),
          ),
        );
      }

      await tester.pumpWidget(buildHarness(0));
      await tester.pumpAndSettle();
      expect(find.text('Persistent state'), findsOneWidget);

      // Switch 0 -> 1
      controller.captureOutgoing();
      await tester.pumpWidget(buildHarness(1));
      await tester.pumpAndSettle();
      expect(find.text('Tab 1 Content'), findsOneWidget);

      // Switch 1 -> 0
      controller.captureOutgoing();
      await tester.pumpWidget(buildHarness(0));
      await tester.pumpAndSettle();

      // State is preserved!
      expect(find.text('Persistent state'), findsOneWidget);
      expect(textController.text, 'Persistent state');
    });

    testWidgets('bottom navigation accepts successive taps inside feedback cooldown', (tester) async {
      var index = 0;
      final selections = <int>[];
      await tester.pumpWidget(ProviderScope(overrides: [
        uiSettingsProvider.overrideWith(_NavTestSettings.new),
        totalUnreadCountProvider.overrideWithValue(0),
      ], child: MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StatefulBuilder(builder: (context, update) => Scaffold(
          bottomNavigationBar: AppBottomNav(currentIndex: index, hapticsEnabled: false,
            onTap: (next) { selections.add(next); update(() => index = next); }),
        )),
      )));
      await tester.pump();
      await tester.tap(find.text('Лента'));
      await tester.pump();
      await tester.tap(find.text('Настройки'));
      await tester.pumpAndSettle();
      expect(selections, [1, 2]);
      expect(index, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('indicator retarget preserves its position and deformation', (tester) async {
      Widget app(int index, {bool animate = true}) => MaterialApp(home: Scaffold(
        body: SizedBox(width: 400, height: 80, child: TravelingNavIndicator(
          index: index, count: 4, color: Colors.blue, animate: animate,
        )),
      ));
      await tester.pumpWidget(app(0));
      await tester.pumpWidget(app(3));
      await tester.pump(const Duration(milliseconds: 70));
      final before = tester.getRect(find.byType(DecoratedBox));
      await tester.pumpWidget(app(1));
      final after = tester.getRect(find.byType(DecoratedBox));
      expect(after.center.dx, closeTo(before.center.dx, 0.001));
      expect(after.width, closeTo(before.width, 0.001));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(app(1, animate: false));
      expect(tester.getCenter(find.byType(DecoratedBox)).dx, closeTo(150, 0.001));
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tab icon lifts and settles when motion is disabled mid-flight', (tester) async {
      Widget app(bool selected, {bool animate = true}) => MaterialApp(home: Scaffold(
        body: TabMorphIcon(outlineIcon: Icons.chat_bubble_outline_rounded,
          filledIcon: Icons.chat_bubble_rounded, isSelected: selected,
          color: Colors.blue, animate: animate, duration: const Duration(milliseconds: 320)),
      ));
      await tester.pumpWidget(app(false));
      await tester.pumpWidget(app(true));
      await tester.pump(const Duration(milliseconds: 100));
      final transforms = tester.widgetList<Transform>(find.byType(Transform)).toList();
      expect(transforms.any((t) => t.transform.storage[13] < 0), isTrue);
      expect(transforms.any((t) => t.transform.storage[0] > 1), isTrue);
      await tester.pumpWidget(app(true, animate: false));
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TravelingNavIndicator animates horizontal position', (WidgetTester tester) async {
      Widget buildIndicator(int index, {bool animate = true}) {
        return MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 80,
                child: TravelingNavIndicator(
                  index: index,
                  count: 4,
                  color: Colors.blue,
                  animate: animate,
                ),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildIndicator(0));
      await tester.pump();

      // Find initial center position
      final Finder pillFinder = find.byType(DecoratedBox);
      expect(pillFinder, findsOneWidget);
      final Finder navFinder = find.byType(TravelingNavIndicator);
      double pillLocalCenterX() =>
          tester.getCenter(pillFinder).dx - tester.getTopLeft(navFinder).dx;

      // Container width 400, slot 0 of 4 -> center at (0 + 0.5) * 100 = 50.0
      expect(pillLocalCenterX(), closeTo(50.0, 0.5));

      // Move to index 1
      await tester.pumpWidget(buildIndicator(1));
      await tester.pump(const Duration(milliseconds: 100));

      // Moving right towards slot 1 center (150.0)
      expect(pillLocalCenterX(), greaterThan(50.0));

      await tester.pumpAndSettle();
      // Settled at slot 1 of 4 -> center at (1 + 0.5) * 100 = 150.0
      expect(pillLocalCenterX(), closeTo(150.0, 0.5));
    });
  });
}
