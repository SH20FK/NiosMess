import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/widgets/common/touch_container.dart';

void main() {
  testWidgets('reduced motion preserves taps without scaling on press', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: Center(
              child: TouchContainer(
                onTap: () => taps++,
                enableHaptics: false,
                child: const SizedBox(width: 100, height: 80),
              ),
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(TouchContainer)),
    );
    await tester.pump(const Duration(milliseconds: 200));
    final scale = tester.widget<AnimatedScale>(
      find.descendant(
        of: find.byType(TouchContainer),
        matching: find.byType(AnimatedScale),
      ),
    );
    expect(scale.scale, 1);
    expect(scale.duration, Duration.zero);
    await gesture.up();
    expect(taps, 1);
  });
}
