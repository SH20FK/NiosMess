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
}
