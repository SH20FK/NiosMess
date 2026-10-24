import 'package:pulse_flutter/models/api/post_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/models/api/custom_emoji_model.dart';
import 'package:pulse_flutter/providers/custom_emoji_provider.dart';
import 'package:pulse_flutter/widgets/chat/custom_emoji.dart';
import 'package:pulse_flutter/widgets/chat/bubble/bubble_text_renderer.dart';
import 'package:pulse_flutter/widgets/feed_poll_card.dart';
import 'package:pulse_flutter/widgets/chat/custom_emoji_text.dart';

class _Catalog extends CustomEmojiCatalog {
  final requested = <String>[];
  @override
  Map<String, ApiCustomEmoji> build() => {};
  @override
  void ensure(Iterable<String> codes) {
    requested.addAll(codes);
  }
}

void main() {
  test(
    'custom emoji count and length limit treat each token as one character',
    () {
      expect(customEmojiLength('a:nios_check:👨‍👩‍👧‍👦:nios_star:'), 4);
      final formatter = CustomEmojiLengthFormatter(2);
      const old = TextEditingValue(text: 'a');
      const next = TextEditingValue(text: 'a:nios_check:');
      expect(formatter.formatEditUpdate(old, next), next);
      expect(
        formatter.formatEditUpdate(
          next,
          const TextEditingValue(text: 'a:nios_check:b'),
        ),
        next,
      );
    },
  );
  test(
    'custom emoji controller deletes whole token and snaps cursor boundaries',
    () {
      final c = CustomEmojiTextController(text: 'a:nios_check:b');
      c.selection = const TextSelection.collapsed(offset: 5);
      expect(c.selection.extentOffset, 13);
      c.value = const TextEditingValue(
        text: 'a:nios_checkb',
        selection: TextSelection.collapsed(offset: 12),
      );
      expect(c.text, 'ab');
      expect(c.selection.extentOffset, 1);
      c.text = 'a:nios_check:b';
      c.value = const TextEditingValue(
        text: 'anios_check:b',
        selection: TextSelection.collapsed(offset: 1),
      );
      expect(c.text, 'ab');
      c.dispose();
    },
  );
  testWidgets(
    'editable emoji paints inline, copies wire text and keeps typed text',
    (tester) async {
      final c = CustomEmojiTextController(text: 'a:nios_check:b');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [customEmojiCatalogProvider.overrideWith(_Catalog.new)],
          child: MaterialApp(
            home: Scaffold(body: TextField(controller: c)),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(find.byType(CustomEmojiInline), findsOneWidget);
      expect(c.text, 'a:nios_check:b');
      await tester.enterText(find.byType(TextField), 'a:nios_check:bc');
      await tester.pump();
      expect(c.text, 'a:nios_check:bc');
      expect(find.byType(CustomEmojiInline), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets('poll question, choices and quiz explanation all render emoji', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [customEmojiCatalogProvider.overrideWith(_Catalog.new)],
        child: MaterialApp(
          home: Scaffold(
            body: FeedPollCard(
              postId: 1,
              poll: {
                'kind': 'quiz',
                'title': 'Q :nios_check:',
                'items': ['A :nios_star:', 'B'],
                'my_choices': [0],
                'correct': 0,
                'counts': [1, 0],
                'total_voters': 1,
                'explanation': 'E :nios_check:',
              },
            ),
          ),
        ),
      ),
    );
    expect(find.byType(CustomEmojiInline), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
  test(
    'shared feed cache excludes account-specific ballot answers and selections',
    () {
      final post = NgPost.fromJson({
        'id': 1,
        'poll': {
          'kind': 'quiz',
          'title': 'Q',
          'items': ['A', 'B'],
          'multiple': false,
          'correct': 1,
          'explanation': 'Answer',
          'my_choices': [0],
          'counts': [1, 0],
          'total_voters': 1,
        },
      });
      final cached = post.toPublicCacheJson()['poll'] as Map;
      expect(cached['my_choices'], isEmpty);
      expect(cached.containsKey('correct'), isFalse);
      expect(cached.containsKey('explanation'), isFalse);
      expect(post.poll!['my_choices'], [0]);
    },
  );

  test('custom emoji inserts at selection and preserves surrounding text', () {
    final controller = TextEditingController(text: 'Hello WORLD!')
      ..selection = const TextSelection(baseOffset: 6, extentOffset: 11);
    insertCustomEmoji(
      controller,
      const ApiCustomEmoji(
        id: 1,
        shortcode: 'nios_check',
        url: 'https://example.invalid/a.png',
        isAdaptive: true,
      ),
    );
    expect(controller.text, 'Hello :nios_check:!');
    expect(controller.selection.baseOffset, 18);
    controller.dispose();
  });
  testWidgets(
    'inline custom emoji keeps bold text and readable missing shortcodes',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [customEmojiCatalogProvider.overrideWith(_Catalog.new)],
          child: MaterialApp(
            home: Scaffold(
              body: InteractiveMessageText(
                text: '**Важно** :nios_check: дальше',
                baseStyle: const TextStyle(fontSize: 16),
                isMine: false,
                scheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(CustomEmojiInline), findsOneWidget);
      expect(find.text(':nios_check:'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('post markdown uses the same inline custom emoji renderer', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [customEmojiCatalogProvider.overrideWith(_Catalog.new)],
        child: MaterialApp(
          home: Scaffold(
            body: MarkdownBody(
              data: 'A :nios_star: B',
              inlineSyntaxes: [CustomEmojiSyntax()],
              builders: {'nios-emoji': CustomEmojiMarkdownBuilder()},
            ),
          ),
        ),
      ),
    );
    expect(find.byType(CustomEmojiInline), findsOneWidget);
    expect(find.text(':nios_star:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final brightness in Brightness.values) {
    testWidgets(
      'anonymous quiz fits narrow screen $brightness and reveals result after vote',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final requests = <Map<String, dynamic>>[];
        const quiz = {
          'kind': 'quiz',
          'title': 'Какой вариант правильный?',
          'items': ['Первый ответ', 'Второй ответ'],
          'multiple': false,
          'counts': [0, 0],
          'my_choices': <int>[],
          'total_voters': 0,
        };
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              customEmojiRequestProvider.overrideWithValue((
                action,
                payload,
              ) async {
                expect(action, 'vote_feed_poll');
                requests.add(payload);
                return {
                  'poll': {
                    ...quiz,
                    'my_choices': [0],
                    'correct': 1,
                    'counts': [1, 0],
                    'total_voters': 1,
                    'explanation': 'Верным был второй вариант',
                  },
                };
              }),
            ],
            child: MaterialApp(
              theme: ThemeData(brightness: brightness),
              home: Scaffold(body: FeedPollCard(postId: 12, poll: quiz)),
            ),
          ),
        );
        expect(find.text('Анонимная викторина'), findsOneWidget);
        expect(find.text('Верным был второй вариант'), findsNothing);
        await tester.tap(find.text('Первый ответ'));
        await tester.pumpAndSettle();
        expect(requests.single['choices'], [0]);
        expect(find.text('Верным был второй вариант'), findsOneWidget);
        await tester.tap(find.text('Второй ответ'));
        await tester.pumpAndSettle();
        expect(requests.length, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
