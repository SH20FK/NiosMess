import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/widgets/circular_theme_reveal.dart';

void main() {
  testWidgets('reduced motion switches theme without starting a reveal', (
    tester,
  ) async {
    final key = GlobalKey<CircularThemeSwitcherState>();
    var changes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: CircularThemeSwitcher(
            key: key,
            child: const ColoredBox(color: Colors.blue),
          ),
        ),
      ),
    );
    await key.currentState!.toggleTheme(() => changes++);
    await tester.pump();
    expect(changes, 1);
    expect(
      find.descendant(
        of: find.byType(CircularThemeSwitcher),
        matching: find.byType(AnimatedBuilder),
      ),
      findsNothing,
    );
    expect(tester.binding.transientCallbackCount, 0);
  });
}
