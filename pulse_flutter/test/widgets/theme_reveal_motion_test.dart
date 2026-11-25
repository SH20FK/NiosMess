import 'package:material_ui/material_ui.dart';
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
    expect(CircularThemeSwitcher.revealing.value, isFalse);
  });

  testWidgets('a reveal flags itself so the theme switches at once under it', (
    tester,
  ) async {
    final key = GlobalKey<CircularThemeSwitcherState>();
    var changes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: CircularThemeSwitcher(
          key: key,
          child: const ColoredBox(color: Colors.blue),
        ),
      ),
    );
    expect(CircularThemeSwitcher.revealing.value, isFalse);

    await key.currentState!.toggleTheme(() => changes++);
    await tester.pump();
    expect(changes, 1);
    expect(CircularThemeSwitcher.revealing.value, isTrue);

    await tester.pumpAndSettle();
    expect(CircularThemeSwitcher.revealing.value, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a reveal disposed mid-flight clears the flag', (tester) async {
    final key = GlobalKey<CircularThemeSwitcherState>();
    await tester.pumpWidget(
      MaterialApp(
        home: CircularThemeSwitcher(
          key: key,
          child: const ColoredBox(color: Colors.blue),
        ),
      ),
    );
    await key.currentState!.toggleTheme(() {});
    await tester.pump();
    expect(CircularThemeSwitcher.revealing.value, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(CircularThemeSwitcher.revealing.value, isFalse);
    expect(tester.takeException(), isNull);
  });
}
