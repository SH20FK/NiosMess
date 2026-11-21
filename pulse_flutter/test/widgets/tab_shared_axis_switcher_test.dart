import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/widgets/nav/m3_route_tab_switcher.dart';
import 'package:pulse_flutter/widgets/app_bottom_nav.dart';

class _NavTestSettings extends UiSettingsNotifier {
  @override
  UiSettingsState build() => const UiSettingsState.defaults().copyWith(soundEffects: false);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('M3RouteTabSwitcher and bottom navigation tests', () {
    testWidgets('Steady state returns live IndexedStack without RawImage', (WidgetTester tester) async {
      final TabTransitionController controller = TabTransitionController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: M3RouteTabSwitcher(
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
                return M3RouteTabSwitcher(
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

      activeIndex = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return M3RouteTabSwitcher(
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
                return M3RouteTabSwitcher(
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
                return M3RouteTabSwitcher(
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
            body: M3RouteTabSwitcher(
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
      await tester.pumpWidget(buildHarness(1));
      await tester.pumpAndSettle();
      expect(find.text('Tab 1 Content'), findsOneWidget);

      // Switch 1 -> 0
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
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
      expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).animationDuration, Duration.zero);
      expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 2);
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
  });
}
