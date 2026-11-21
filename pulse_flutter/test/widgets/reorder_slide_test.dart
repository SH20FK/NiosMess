import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/widgets/chat/reorder_slide.dart';

void main() {
  Widget app(
    List<String> order, {
    Object scope = 'all',
    bool reduced = false,
  }) => MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
      child: child!,
    ),
    home: Scaffold(
      body: Column(
        children: <Widget>[
          for (final (int index, String id) in order.indexed)
            ReorderSlide(
              key: ValueKey<String>(id),
              index: index,
              scope: scope,
              child: SizedBox(width: 200, height: 50, child: Text(id)),
            ),
        ],
      ),
    ),
  );

  double y(WidgetTester tester, String id) =>
      tester.getTopLeft(find.text(id)).dy;

  testWidgets('a row that changes index slides from its old slot', (
    tester,
  ) async {
    await tester.pumpWidget(app(<String>['a', 'b', 'c']));
    final double top = y(tester, 'a');
    expect(y(tester, 'c'), closeTo(top + 100, 0.001));

    await tester.pumpWidget(app(<String>['c', 'a', 'b']));
    // First frame: every row is still drawn where it was.
    expect(y(tester, 'c'), closeTo(top + 100, 0.5));
    expect(y(tester, 'a'), closeTo(top, 0.5));
    expect(y(tester, 'b'), closeTo(top + 50, 0.5));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(y(tester, 'c'), inExclusiveRange(top, top + 100));
    expect(y(tester, 'a'), inExclusiveRange(top, top + 50));

    await tester.pumpAndSettle();
    expect(y(tester, 'c'), closeTo(top, 0.001));
    expect(y(tester, 'a'), closeTo(top + 50, 0.001));
    expect(y(tester, 'b'), closeTo(top + 100, 0.001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a second move mid-flight continues from the visible position', (
    tester,
  ) async {
    await tester.pumpWidget(app(<String>['a', 'b', 'c']));
    final double top = y(tester, 'a');

    await tester.pumpWidget(app(<String>['c', 'a', 'b']));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final double before = y(tester, 'c');

    await tester.pumpWidget(app(<String>['a', 'c', 'b']));
    expect(y(tester, 'c'), closeTo(before, 0.5));

    await tester.pumpAndSettle();
    expect(y(tester, 'c'), closeTo(top + 50, 0.001));
  });

  testWidgets('another scope repositions the rows without motion', (
    tester,
  ) async {
    await tester.pumpWidget(app(<String>['a', 'b', 'c']));
    final double top = y(tester, 'a');

    await tester.pumpWidget(app(<String>['c', 'a', 'b'], scope: 'unread'));
    expect(y(tester, 'c'), closeTo(top, 0.001));
    expect(y(tester, 'a'), closeTo(top + 50, 0.001));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('reduced motion repositions the rows immediately', (
    tester,
  ) async {
    await tester.pumpWidget(app(<String>['a', 'b', 'c'], reduced: true));
    final double top = y(tester, 'a');

    await tester.pumpWidget(app(<String>['c', 'a', 'b'], reduced: true));
    expect(y(tester, 'c'), closeTo(top, 0.001));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
