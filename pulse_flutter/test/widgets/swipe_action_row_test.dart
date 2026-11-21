import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/widgets/chat/swipe_action_row.dart';

class _Row extends StatefulWidget {
  const _Row();

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  @override
  Widget build(BuildContext context) =>
      const SizedBox(key: ValueKey<String>('row'), width: 400, height: 76);
}

void main() {
  Widget app({
    required VoidCallback onTriggered,
    bool enabled = true,
    bool reduced = false,
    TextDirection direction = TextDirection.ltr,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Directionality(
        textDirection: direction,
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: SwipeActionRow(
                enabled: enabled,
                onTriggered: onTriggered,
                background: const Text('read'),
                child: const _Row(),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  final Finder row = find.byKey(const ValueKey<String>('row'));

  testWidgets('pull past the threshold triggers once and springs back', (
    tester,
  ) async {
    var triggered = 0;
    await tester.pumpWidget(app(onTriggered: () => triggered++));
    final double rest = tester.getTopLeft(row).dx;
    final State rowState = tester.state(find.byType(_Row));
    expect(find.text('read'), findsNothing);

    final gesture = await tester.startGesture(tester.getCenter(row));
    await gesture.moveBy(const Offset(160, 0));
    await tester.pump();
    expect(tester.getTopLeft(row).dx, closeTo(rest + 160, 0.001));
    expect(find.text('read'), findsOneWidget);
    // Revealing the background must not recreate the row.
    expect(tester.state(find.byType(_Row)), same(rowState));

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.getTopLeft(row).dx, inExclusiveRange(rest, rest + 160));

    await tester.pumpAndSettle();
    expect(triggered, 1);
    expect(tester.getTopLeft(row).dx, closeTo(rest, 0.001));
    expect(find.text('read'), findsNothing);
    expect(tester.state(find.byType(_Row)), same(rowState));
    expect(tester.takeException(), isNull);
  });

  testWidgets('short pull returns without triggering', (tester) async {
    var triggered = 0;
    await tester.pumpWidget(app(onTriggered: () => triggered++));
    final double rest = tester.getTopLeft(row).dx;

    final gesture = await tester.startGesture(tester.getCenter(row));
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();
    expect(tester.getTopLeft(row).dx, greaterThan(rest));
    // The row never travels towards the start edge.
    await gesture.moveBy(const Offset(-200, 0));
    await tester.pump();
    expect(tester.getTopLeft(row).dx, closeTo(rest, 0.001));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(triggered, 0);
    expect(tester.getTopLeft(row).dx, closeTo(rest, 0.001));
  });

  testWidgets('RTL mirrors the swipe direction', (tester) async {
    var triggered = 0;
    await tester.pumpWidget(
      app(onTriggered: () => triggered++, direction: TextDirection.rtl),
    );
    final double rest = tester.getTopLeft(row).dx;

    final gesture = await tester.startGesture(tester.getCenter(row));
    await gesture.moveBy(const Offset(-160, 0));
    await tester.pump();
    expect(tester.getTopLeft(row).dx, closeTo(rest - 160, 0.001));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(triggered, 1);
    expect(tester.getTopLeft(row).dx, closeTo(rest, 0.001));
  });

  testWidgets('disabled row ignores the drag', (tester) async {
    var triggered = 0;
    await tester.pumpWidget(
      app(onTriggered: () => triggered++, enabled: false),
    );
    final double rest = tester.getTopLeft(row).dx;

    final gesture = await tester.startGesture(tester.getCenter(row));
    await gesture.moveBy(const Offset(200, 0));
    await tester.pump();
    expect(tester.getTopLeft(row).dx, closeTo(rest, 0.001));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(triggered, 0);
  });

  testWidgets('reduced motion returns immediately', (tester) async {
    var triggered = 0;
    await tester.pumpWidget(
      app(onTriggered: () => triggered++, reduced: true),
    );
    final double rest = tester.getTopLeft(row).dx;

    final gesture = await tester.startGesture(tester.getCenter(row));
    await gesture.moveBy(const Offset(160, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(triggered, 1);
    expect(tester.getTopLeft(row).dx, closeTo(rest, 0.001));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
