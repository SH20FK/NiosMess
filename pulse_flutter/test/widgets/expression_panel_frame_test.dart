import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/widgets/chat/expression_panel_frame.dart';

void main() {
  late GlobalKey<ExpressionPanelFrameState> frameKey;

  setUp(() => frameKey = GlobalKey<ExpressionPanelFrameState>());

  Widget app({
    required double height,
    double keyboardInset = 0.0,
    bool reduced = false,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: ExpressionPanelFrame(
            key: frameKey,
            height: height,
            keyboardInset: keyboardInset,
            layoutHeight: 300.0,
            maxHeight: 500.0,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ),
  );

  double panelHeight(WidgetTester tester) =>
      tester.getSize(find.byType(ExpressionPanelFrame)).height;

  testWidgets('opening and closing spring the height', (tester) async {
    await tester.pumpWidget(app(height: 0.0));
    expect(panelHeight(tester), 0.0);

    await tester.pumpWidget(app(height: 300.0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(panelHeight(tester), greaterThan(0.0));
    expect(panelHeight(tester), lessThan(300.0));

    await tester.pumpAndSettle();
    expect(panelHeight(tester), closeTo(300.0, 0.001));

    // The closing spring overshoots below zero; the height must not.
    await tester.pumpWidget(app(height: 0.0));
    await tester.pumpAndSettle();
    expect(panelHeight(tester), 0.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a change that comes with the keyboard is applied at once', (
    tester,
  ) async {
    await tester.pumpWidget(app(height: 300.0));
    await tester.pumpAndSettle();

    await tester.pumpWidget(app(height: 100.0, keyboardInset: 200.0));
    await tester.pump();

    expect(panelHeight(tester), closeTo(100.0, 0.001));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('a drag follows the finger and release springs back', (
    tester,
  ) async {
    await tester.pumpWidget(app(height: 300.0));
    await tester.pumpAndSettle();
    final ExpressionPanelFrameState frame = frameKey.currentState!;

    frame.dragBy(-40.0);
    await tester.pump();
    expect(panelHeight(tester), closeTo(340.0, 0.001));

    frame.dragBy(100.0);
    await tester.pump();
    expect(panelHeight(tester), closeTo(240.0, 0.001));

    // A new resting height does not pull the panel from under the finger.
    await tester.pumpWidget(app(height: 500.0));
    await tester.pump();
    expect(panelHeight(tester), closeTo(240.0, 0.001));

    frame.release(0.0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(panelHeight(tester), greaterThan(240.0));
    expect(panelHeight(tester), lessThan(500.0));

    await tester.pumpAndSettle();
    expect(panelHeight(tester), closeTo(500.0, 0.001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a drag stays between zero and maxHeight', (tester) async {
    await tester.pumpWidget(app(height: 300.0));
    await tester.pumpAndSettle();
    final ExpressionPanelFrameState frame = frameKey.currentState!;

    frame.dragBy(-1000.0);
    await tester.pump();
    expect(panelHeight(tester), closeTo(500.0, 0.001));

    frame.dragBy(2000.0);
    await tester.pump();
    expect(panelHeight(tester), 0.0);

    frame.release(0.0);
    await tester.pumpAndSettle();
    expect(panelHeight(tester), closeTo(300.0, 0.001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion jumps to the new height', (tester) async {
    await tester.pumpWidget(app(height: 0.0, reduced: true));

    await tester.pumpWidget(app(height: 300.0, reduced: true));
    await tester.pump();

    expect(panelHeight(tester), closeTo(300.0, 0.001));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
