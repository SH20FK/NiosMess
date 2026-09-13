import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/widgets/message_bubble.dart';

void main() {
  Widget buildTestBubble({required String text}) {
    return ProviderScope(
      child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          splashFactory: InkRipple.splashFactory,
        ),
        home: Scaffold(
          body: MessageBubble(
            text: text,
            formattedTime: '12:00',
            isMine: false,
            chatId: 101,
          ),
        ),
      ),
    );
  }

  group('MessageBubble Rich Link and Mention Parsing Tests', () {
    testWidgets('Renders plain text without extra gesture recognizers', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestBubble(text: 'Hello world, this is a plain message'));
      await tester.pumpAndSettle();

      final RichText richText = tester.widget<RichText>(find.byType(RichText).first);
      final TextSpan rootSpan = richText.text as TextSpan;
      final TextSpan bodySpan = rootSpan.children!.first as TextSpan;

      final List<InlineSpan> spans = bodySpan.children!;
      final List<TextSpan> interactiveSpans = spans
          .whereType<TextSpan>()
          .where((TextSpan s) => s.recognizer != null)
          .toList();
      expect(interactiveSpans, isEmpty);
      expect(bodySpan.toPlainText(), contains('Hello world, this is a plain message'));
    });

    testWidgets('Parses and highlights @mention and URL in a message', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestBubble(
        text: 'Hi @alice! Join https://ni-os.ru/u/tester now, or see t.me/channel',
      ));
      await tester.pumpAndSettle();

      final RichText richText = tester.widget<RichText>(find.byType(RichText).first);
      final TextSpan rootSpan = richText.text as TextSpan;
      final TextSpan bodySpan = rootSpan.children!.first as TextSpan;

      final List<InlineSpan> spans = bodySpan.children!;
      expect(spans, isNotEmpty);

      // Find spans that have recognizers
      final List<TextSpan> interactiveSpans = spans
          .whereType<TextSpan>()
          .where((TextSpan s) => s.recognizer is TapGestureRecognizer)
          .toList();

      expect(interactiveSpans.length, equals(3));
      expect(interactiveSpans[0].text, equals('@alice'));
      expect(interactiveSpans[1].text, equals('https://ni-os.ru/u/tester'));
      expect(interactiveSpans[2].text, equals('t.me/channel'));
    });

    testWidgets('Correctly strips trailing punctuation from URLs', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestBubble(
        text: 'Visit https://ni-os.ru/u/alpha! And t.me/beta.',
      ));
      await tester.pumpAndSettle();

      final RichText richText = tester.widget<RichText>(find.byType(RichText).first);
      final TextSpan rootSpan = richText.text as TextSpan;
      final TextSpan bodySpan = rootSpan.children!.first as TextSpan;

      final List<TextSpan> interactiveSpans = bodySpan.children!
          .whereType<TextSpan>()
          .where((TextSpan s) => s.recognizer is TapGestureRecognizer)
          .toList();

      expect(interactiveSpans.length, equals(2));
      expect(interactiveSpans[0].text, equals('https://ni-os.ru/u/alpha'));
      expect(interactiveSpans[1].text, equals('t.me/beta'));
    });
  });
}
