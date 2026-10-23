import 'package:test/test.dart';
import 'package:pulse_flutter/core/utils/message_preview_text.dart';

void main() {
  test('chat formatting becomes readable plain preview', () {
    expect(
      messagePreviewText('**слово** и *курсив* ~~нет~~'),
      'слово и курсив нет',
    );
    expect(
      messagePreviewText('[Сайт](https://example.com) и `код`'),
      'Сайт и код',
    );
    expect(
      messagePreviewText('# Заголовок\n\n- Первый\n- Второй'),
      'Заголовок Первый Второй',
    );
    expect(messagePreviewText('![Фото](photo.png)'), 'Фото');
    expect(messagePreviewText('2 * 3 = 6'), '2 * 3 = 6');
    expect(messagePreviewText('Привет 👋'), 'Привет 👋');
  });
  test('link definitions cannot leak between messages', () {
    messagePreviewText('[test]: https://example.com');
    expect(messagePreviewText('[test]'), '[test]');
  });
}
