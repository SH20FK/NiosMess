import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/widgets/chat/bubble/bubble_text_renderer.dart';

void main() {
  Future<TextSpan> render(
    WidgetTester tester,
    String text, {
    bool mine = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InteractiveMessageText(
            text: text,
            baseStyle: const TextStyle(fontSize: 15),
            isMine: mine,
            scheme: ColorScheme.fromSeed(seedColor: Colors.purple),
          ),
        ),
      ),
    );
    return tester.widget<Text>(find.byType(Text).last).textSpan! as TextSpan;
  }

  testWidgets('Support greeting and subscription name are bold', (
    tester,
  ) async {
    final span = await render(
      tester,
      '**Привет, Елена**\nМы знаем что у тебя есть подписка Nios**Plus**\nСпасибо за поддержку нашего проекта ❤️',
    );
    expect(
      span.toPlainText(),
      'Привет, Елена\nМы знаем что у тебя есть подписка NiosPlus\nСпасибо за поддержку нашего проекта ❤️',
    );
    final bold = span.children!
        .whereType<TextSpan>()
        .where((s) => s.style?.fontWeight == FontWeight.w700)
        .map((s) => s.text)
        .toList();
    expect(bold, ['Привет, Елена', 'Plus']);
  });

  testWidgets('bold links retain interaction and punctuation', (tester) async {
    final span = await render(
      tester,
      '**https://ni-os.ru/ai, @hello_sanlsan**',
    );
    final links = span.children!.whereType<TextSpan>().where(
      (s) => s.recognizer != null,
    );
    expect(links.map((s) => s.text), ['https://ni-os.ru/ai', '@hello_sanlsan']);
    expect(links.every((s) => s.style?.fontWeight == FontWeight.w700), isTrue);
    expect(span.toPlainText(), 'https://ni-os.ru/ai, @hello_sanlsan');
  });

  testWidgets('escaped names and unmatched delimiters remain literal', (
    tester,
  ) async {
    var span = await render(tester, r'**Привет, name\*** Nios**Plus**');
    expect(span.toPlainText(), 'Привет, name* NiosPlus');
    span = await render(tester, r'\*\*обычный\*\* и **без конца');
    expect(span.toPlainText(), '**обычный** и **без конца');
  });

  testWidgets('editing message clears old spans and recognizers', (
    tester,
  ) async {
    await render(tester, '**@hello_sanlsan**');
    final span = await render(tester, 'Новый текст', mine: true);
    expect(span.toPlainText(), 'Новый текст');
    expect(
      span.children!.whereType<TextSpan>().any((s) => s.recognizer != null),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });
}
