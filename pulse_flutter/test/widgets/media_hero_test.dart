import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/widgets/media/media_hero.dart';

void main() {
  testWidgets('repeated attachment URLs can open and return independently', (
    tester,
  ) async {
    final first = chatMediaHeroTag(7, 10);
    final second = chatMediaHeroTag(7, 11);
    expect(first, isNot(second));
    expect(first, isNot(chatMediaHeroTag(8, 10)));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Column(
                children: [
                  MediaHero(
                    tag: first,
                    child: const SizedBox(width: 80, height: 60),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => Scaffold(
                          body: MediaHero(
                            tag: second,
                            child: const Center(
                              child: Text('Loading attachment'),
                            ),
                          ),
                        ),
                      ),
                    ),
                    child: MediaHero(
                      tag: second,
                      child: const SizedBox(
                        key: ValueKey('thumbnail'),
                        width: 80,
                        height: 60,
                        child: ColoredBox(color: Color(0xff6750a4)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('thumbnail')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.text('Loading attachment'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('thumbnail')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion keeps the image without a Hero flight', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MediaHero(tag: 'attachment', child: Text('Image')),
        ),
      ),
    );
    expect(find.text('Image'), findsOneWidget);
    expect(find.byType(Hero), findsNothing);
  });
}
