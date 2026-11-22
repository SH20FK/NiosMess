import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/widgets/app_refresh_indicator.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

void main() {
  late int refreshes;
  late Completer<void> refresh;

  setUp(() => refreshes = 0);

  Widget app({bool reduced = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Scaffold(
        body: AppRefreshIndicator(
          onRefresh: () {
            refreshes++;
            // Created here, inside the test's fake-async zone: a completer
            // from setUp would complete only after the test body ends.
            refresh = Completer<void>();
            return refresh.future;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const <Widget>[SizedBox(height: 80, child: Text('Row'))],
          ),
        ),
      ),
    ),
  );

  final Finder indicator = find.byType(AppLoadingIndicator);

  double opacity(WidgetTester tester) => tester
      .widget<FadeTransition>(
        find.ancestor(of: indicator, matching: find.byType(FadeTransition)).first,
      )
      .opacity
      .value;

  Future<void> settle(WidgetTester tester) async {
    // The loading indicator loops, so pumpAndSettle would never return.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('nothing is built or ticking at rest', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();

    expect(indicator, findsNothing);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('a full pull refreshes and holds the indicator until done', (
    tester,
  ) async {
    await tester.pumpWidget(app());

    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await settle(tester);

    expect(refreshes, 1);
    expect(indicator, findsOneWidget);
    expect(opacity(tester), 1.0);

    refresh.complete();
    await settle(tester);

    expect(indicator, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the indicator follows a partial pull and a release cancels', (
    tester,
  ) async {
    await tester.pumpWidget(app());

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byType(ListView)),
    );
    await gesture.moveBy(const Offset(0, 30));
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();

    expect(indicator, findsOneWidget);
    expect(opacity(tester), inExclusiveRange(0.0, 1.0));

    await gesture.up();
    await settle(tester);

    expect(refreshes, 0);
    expect(indicator, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion still refreshes and shows the indicator', (
    tester,
  ) async {
    await tester.pumpWidget(app(reduced: true));

    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await settle(tester);

    expect(refreshes, 1);
    expect(opacity(tester), 1.0);

    refresh.complete();
    await settle(tester);

    expect(indicator, findsNothing);
    expect(tester.takeException(), isNull);
  });
}
