import 'package:material_ui/material_ui.dart';
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
    VoidCallback? onEndTriggered,
    VoidCallback? onArmed,
    Widget background = const Text('read'),
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
                background: background,
                onEndTriggered: onEndTriggered,
                endBackground: const Text('mute'),
                onArmed: onArmed,
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

  testWidgets('pull towards the start edge triggers the end action', (
    tester,
  ) async {
    var read = 0;
    var muted = 0;
    var armed = 0;
    await tester.pumpWidget(
      app(
        onTriggered: () => read++,
        onEndTriggered: () => muted++,
        onArmed: () => armed++,
      ),
    );
    final double rest = tester.getTopLeft(row).dx;

    final gesture = await tester.startGesture(tester.getCenter(row));
    await gesture.moveBy(const Offset(-100, 0));
    await tester.pump();
    expect(tester.getTopLeft(row).dx, closeTo(rest - 100, 0.001));
    // Only the background of the pulled side is revealed.
    expect(find.text('mute'), findsOneWidget);
    expect(find.text('read'), findsNothing);
    // 25% of the row: not far enough yet.
    expect(armed, 0);

    await gesture.moveBy(const Offset(-60, 0));
    await tester.pump();
    expect(armed, 1);
    // Moving on past the threshold does not arm again.
    await gesture.moveBy(const Offset(-10, 0));
    await tester.pump();
    expect(armed, 1);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(muted, 1);
    expect(read, 0);
    expect(tester.getTopLeft(row).dx, closeTo(rest, 0.001));
    expect(find.text('mute'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('background learns when the pull is far enough to trigger', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        onTriggered: () {},
        background: Builder(
          builder: (BuildContext context) =>
              Text(SwipeActionRow.armedOf(context) ? 'armed' : 'idle'),
        ),
      ),
    );

    final gesture = await tester.startGesture(tester.getCenter(row));
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();
    expect(find.text('idle'), findsOneWidget);

    await gesture.moveBy(const Offset(100, 0));
    await tester.pump();
    expect(find.text('armed'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('armed'), findsNothing);
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
