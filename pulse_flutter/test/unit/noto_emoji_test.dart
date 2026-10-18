import 'package:pulse_flutter/core/utils/noto_emoji.dart';
import 'package:test/test.dart';

void main() {
  group('single supported Noto emoji', () {
    for (final entry in <String, String>{
      '😀': '1f600',
      '❤️': '2764',
      '❤': '2764',
      '👍🏽': '1f44d_1f3fd',
      '👩🏽‍💻': '1f469_1f3fd_200d_1f4bb',
      '👨‍👩‍👧‍👦': '1f468_200d_1f469_200d_1f467_200d_1f466',
      '🇷🇺': '1f1f7_1f1fa',
      '1️⃣': '31_20e3',
      '#️⃣': '23_20e3',
      '©️': 'a9',
      '🙂‍↕️': '1f642_200d_2195',
    }.entries) {
      test('keeps ${entry.value} as one exact Unicode sequence', () {
        final emoji = NotoEmoji.fromMessage(entry.key);
        expect(emoji, isNotNull);
        expect(emoji!.unicode, entry.key);
        expect(emoji.assetId, entry.value);
      });
    }

    test('recognizes a subdivision tag flag without losing tags', () {
      final england = String.fromCharCodes([
        0x1f3f4,
        0xe0067,
        0xe0062,
        0xe0065,
        0xe006e,
        0xe0067,
        0xe007f,
      ]);
      final emoji = NotoEmoji.fromMessage(england);
      expect(emoji!.unicode, england);
      expect(emoji.assetId, '1f3f4_e0067_e0062_e0065_e006e_e0067_e007f');
    });

    test('only trims display whitespace and never mutates the message', () {
      const message = '  ❤️\n';
      final emoji = NotoEmoji.fromMessage(message)!;
      expect(emoji.unicode, '❤️');
      expect(message, '  ❤️\n');
      expect(emoji.animationAsset, 'assets/emoji/animated/2764.json.gz');
    });

    test(
      'tone and ZWJ select their own animation, never a neutral variant',
      () {
        expect(
          NotoEmoji.fromMessage('👍🏽')!.animationAsset,
          'assets/emoji/animated/1f44d_1f3fd.json.gz',
        );
        expect(
          NotoEmoji.fromMessage('🙂‍↕️')!.animationAsset,
          'assets/emoji/animated/1f642_200d_2195.json.gz',
        );
      },
    );

    for (final text in <String>[
      '',
      ' ',
      '7',
      '#',
      '*',
      '!',
      '.',
      '☍',
      'a\u0301',
      '😀😀',
      'hello 😀',
      '**😀**',
      'https://ni-os.ru/😀',
      '🏽',
      '🇷',
      '\ufe0f',
      '\u200d',
      '❤\ufe0e',
      '😀\ufe0f\ufe0f',
      '😀\u200d😀',
      '😀\n😀',
    ]) {
      test(
        'keeps non-emoji or mixed content in the normal text renderer: $text',
        () {
          expect(NotoEmoji.fromMessage(text), isNull);
        },
      );
    }

    test('rejects a long text body before grapheme/asset processing', () {
      expect(NotoEmoji.fromMessage('message ' * 1000), isNull);
    });
  });
}
