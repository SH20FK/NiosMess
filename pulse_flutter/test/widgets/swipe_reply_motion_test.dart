import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/widgets/chat/bubble/bubble_gestures.dart';

void main() {
  testWidgets('reduced motion returns a dragged message immediately', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: Center(
              child: SwipeToReply(
                onReply: () {},
                scheme: ColorScheme.fromSeed(seedColor: Colors.blue),
                child: const SizedBox(
                  key: ValueKey('message'),
                  width: 200,
                  height: 80,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final message = find.byKey(const ValueKey('message'));
    final initial = tester.getTopLeft(message);
    final gesture = await tester.startGesture(tester.getCenter(message));
    await gesture.moveBy(const Offset(-40, 0));
    await tester.pump();
    expect(tester.getTopLeft(message).dx, lessThan(initial.dx));
    await gesture.up();
    await tester.pump();
    expect(tester.getTopLeft(message), initial);
  });

  Widget app({required VoidCallback onReply}) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: SwipeToReply(
          onReply: onReply,
          scheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          child: const SizedBox(
            key: ValueKey('message'),
            width: 200,
            height: 80,
          ),
        ),
      ),
    ),
  );

  testWidgets('release carries the finger velocity into the return spring', (
    tester,
  ) async {
    await tester.pumpWidget(app(onReply: () {}));
    final message = find.byKey(const ValueKey('message'));
    final initial = tester.getTopLeft(message);

    final gesture = await tester.startGesture(tester.getCenter(message));
    for (var i = 1; i <= 3; i++) {
      await gesture.moveBy(
        const Offset(-10, 0),
        timeStamp: Duration(milliseconds: 10 * i),
      );
    }
    await tester.pump();
    final atRelease = tester.getTopLeft(message).dx;
    expect(atRelease, lessThan(initial.dx));

    await gesture.up(timeStamp: const Duration(milliseconds: 35));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 8));
    // Still travelling left: the spring did not start from a dead stop.
    expect(tester.getTopLeft(message).dx, lessThan(atRelease));

    await tester.pumpAndSettle();
    expect(tester.getTopLeft(message).dx, closeTo(initial.dx, 0.001));
  });

  testWidgets('pull past the threshold stretches and triggers a reply', (
    tester,
  ) async {
    var replies = 0;
    await tester.pumpWidget(app(onReply: () => replies++));
    final message = find.byKey(const ValueKey('message'));
    final initial = tester.getTopLeft(message);

    final gesture = await tester.startGesture(tester.getCenter(message));
    await gesture.moveBy(const Offset(-64, 0));
    await tester.pump();
    expect(tester.getTopLeft(message).dx, closeTo(initial.dx - 64, 0.001));

    await gesture.moveBy(const Offset(-400, 0));
    await tester.pump();
    final stretched = initial.dx - tester.getTopLeft(message).dx;
    expect(stretched, greaterThan(64));
    expect(stretched, lessThan(64 + 32));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(replies, 1);
    expect(tester.getTopLeft(message).dx, closeTo(initial.dx, 0.001));
  });
}
