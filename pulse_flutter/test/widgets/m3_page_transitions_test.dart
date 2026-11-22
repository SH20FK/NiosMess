import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/motion/m3_page_transitions.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

void main() {
  Widget app(
    GlobalKey<NavigatorState> navigatorKey, {
    bool reduced = false,
    TextDirection direction = TextDirection.ltr,
  }) => MaterialApp(
    navigatorKey: navigatorKey,
    theme: ThemeData(
      pageTransitionsTheme: PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          for (final TargetPlatform platform in TargetPlatform.values)
            platform: const M3SharedAxisPageTransitionsBuilder(),
        },
      ),
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
      child: Directionality(textDirection: direction, child: child!),
    ),
    home: const Scaffold(body: Text('list')),
  );

  Future<void> pushChat(
    WidgetTester tester,
    GlobalKey<NavigatorState> navigatorKey,
  ) async {
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('chat')),
      ),
    );
    await tester.pump();
  }

  double dx(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text)).dx;

  test('transition lasts as long as the default spatial spring', () {
    expect(
      const M3SharedAxisPageTransitionsBuilder().transitionDuration,
      M3Durations.spatialDefault,
    );
  });

  test('going back is quicker than arriving', () {
    expect(
      const M3SharedAxisPageTransitionsBuilder().reverseTransitionDuration,
      M3Durations.spatialFast,
    );
  });

  testWidgets('a pushed route takes both durations from the builder', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(app(navigatorKey));
    final route = MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('chat')),
    );
    navigatorKey.currentState!.push(route);
    await tester.pumpAndSettle();

    expect(route.transitionDuration, M3Durations.spatialDefault);
    expect(route.reverseTransitionDuration, M3Durations.spatialFast);
  });

  testWidgets('push moves both pages along X and pop mirrors it', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(app(navigatorKey));
    final double rest = dx(tester, 'list');

    await pushChat(tester, navigatorKey);
    await tester.pump(const Duration(milliseconds: 100));
    expect(dx(tester, 'list'), lessThan(rest));
    expect(dx(tester, 'chat'), inExclusiveRange(rest, rest + 96));

    await tester.pumpAndSettle();
    expect(find.text('list'), findsNothing);
    expect(dx(tester, 'chat'), closeTo(rest, 0.001));

    navigatorKey.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(dx(tester, 'chat'), greaterThan(rest));
    expect(dx(tester, 'list'), lessThan(rest));

    await tester.pumpAndSettle();
    expect(find.text('chat'), findsNothing);
    expect(dx(tester, 'list'), closeTo(rest, 0.001));
  });

  testWidgets('RTL mirrors the travel direction', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(app(navigatorKey, direction: TextDirection.rtl));
    final double rest = dx(tester, 'list');

    await pushChat(tester, navigatorKey);
    await tester.pump(const Duration(milliseconds: 100));
    expect(dx(tester, 'list'), greaterThan(rest));
    expect(dx(tester, 'chat'), lessThan(rest));

    await tester.pumpAndSettle();
    expect(dx(tester, 'chat'), closeTo(rest, 0.001));
  });

  testWidgets('reduced motion keeps only the cross-fade', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(app(navigatorKey, reduced: true));
    final double rest = dx(tester, 'list');

    await pushChat(tester, navigatorKey);
    await tester.pump(const Duration(milliseconds: 100));
    expect(dx(tester, 'list'), closeTo(rest, 0.001));
    expect(dx(tester, 'chat'), closeTo(rest, 0.001));

    await tester.pumpAndSettle();
    expect(find.text('chat'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
