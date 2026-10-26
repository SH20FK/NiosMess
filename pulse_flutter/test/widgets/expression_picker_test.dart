import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/models/api/custom_emoji_model.dart';
import 'package:pulse_flutter/models/api/sticker_model.dart';
import 'package:pulse_flutter/providers/custom_emoji_provider.dart';
import 'package:pulse_flutter/providers/sticker_provider.dart';
import 'package:pulse_flutter/providers/recent_stickers_provider.dart';
import 'package:pulse_flutter/widgets/chat/chat_input_bar.dart';
import 'package:pulse_flutter/widgets/chat/expression_picker_panel.dart';
import 'package:pulse_flutter/widgets/chat/expression_picker_components.dart';
import 'package:pulse_flutter/widgets/chat/custom_emoji.dart';

class _Emojis extends CustomEmojiSets {
  @override
  Future<List<ApiCustomEmojiSet>> build() async => const [
    ApiCustomEmojiSet(
      id: 1,
      name: 'faces',
      title: 'Faces',
      emojis: [
        ApiCustomEmoji(
          id: 1,
          setId: 1,
          shortcode: 'happy',
          url: 'https://invalid.test/happy.png',
        ),
      ],
    ),
    ApiCustomEmojiSet(
      id: 2,
      name: 'pets',
      title: 'Pets',
      emojis: [
        ApiCustomEmoji(
          id: 2,
          setId: 2,
          shortcode: 'kitten',
          url: 'https://invalid.test/cat.png',
        ),
      ],
    ),
  ];
}

class _Stickers extends StickerSetsNotifier {
  @override
  Future<List<ApiStickerSet>> build() async => [
    ApiStickerSet(
      id: 1,
      name: 'cats',
      title: 'Cats',
      stickers: [
        ApiSticker(id: 12, url: 'https://invalid.test/cat.webp', emoji: '🐈'),
      ],
    ),
    ApiStickerSet(
      id: 2,
      name: 'empty',
      title: 'Empty pack',
      stickers: const [],
    ),
  ];
}

class _Recent extends RecentStickersNotifier {
  @override
  Future<List<int>> build() async => const [12];
  @override
  Future<void> record(int id) async {}
}

void main() {
  group('expression keyboard and library', () {
    late TextEditingController input;
    late FocusNode focus;
    late List<ApiSticker> sent;
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      input = TextEditingController();
      focus = FocusNode();
      sent = [];
    });
    tearDown(() {
      input.dispose();
      focus.dispose();
    });
    Widget app({
      String locale = 'ru',
      double scale = 1,
      Brightness brightness = Brightness.light,
    }) => ProviderScope(
      overrides: [
        customEmojiSetsProvider.overrideWith(_Emojis.new),
        stickerSetsProvider.overrideWith(_Stickers.new),
        recentStickersProvider.overrideWith(_Recent.new),
      ],
      child: MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xff648877),
            brightness: brightness,
          ),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ChatInputBar(
              inputController: input,
              inputFocusNode: focus,
              isAiProcessing: false,
              uploadingMedia: false,
              editingMessageId: null,
              editingOriginalText: null,
              replyToMessageId: null,
              replyPreviewText: null,
              hapticsEnabled: false,
              onSend: () {},
              onCommitEdit: () {},
              onCancelEdit: () {},
              onClearReply: () {},
              onAttachMedia: () {},
              onAiPressed: () {},
              onVoiceSend: (_) {},
              onSendSticker: sent.add,
            ),
          ),
        ),
      ),
    );
    Future<void> open(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.emoji_emotions_outlined));
      await tester.pumpAndSettle();
    }

    Future<void> tab(WidgetTester tester, String label) async {
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('expression-mode-tabs')),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> library(WidgetTester tester) async {
      if (find.byType(ExpressionPackCard).evaluate().isNotEmpty) return;
      final gridButton = find.byIcon(Icons.grid_view_rounded);
      await tester.tap(
        gridButton.evaluate().isNotEmpty
            ? gridButton
            : find.byKey(const ValueKey('expression-library-toggle')),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'three labeled tabs fit 320dp at 200% in RU/EN and light/dark',
      (tester) async {
        tester.view.physicalSize = const Size(320, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final locale in ['ru', 'en']) {
          for (final brightness in Brightness.values) {
            await tester.pumpWidget(
              app(locale: locale, scale: 2, brightness: brightness),
            );
            await tester.pumpAndSettle();
            if (find
                .byIcon(Icons.emoji_emotions_outlined)
                .evaluate()
                .isNotEmpty) {
              await open(tester);
            }
            for (final label
                in locale == 'ru'
                    ? ['Эмодзи', 'Свои', 'Стикеры']
                    : ['Emoji', 'Custom', 'Stickers']) {
              expect(
                find.descendant(
                  of: find.byKey(const ValueKey('expression-mode-tabs')),
                  matching: find.text(label),
                ),
                findsOneWidget,
              );
              await tab(tester, label);
              expect(tester.takeException(), isNull);
            }
            await library(tester);
            expect(find.byType(ExpressionPackCard), findsWidgets);
            tester.view.viewInsets = const FakeViewPadding(bottom: 300);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            tester.view.resetViewInsets();
            await tester.pumpAndSettle();
            await tester.tap(
              find.byTooltip(
                MaterialLocalizations.of(
                  tester.element(find.byType(ExpressionPickerPanel)),
                ).closeButtonTooltip,
              ),
            );
            await tester.pumpAndSettle();
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets(
      'library pack selection, insert at cursor, search and close preserve state',
      (tester) async {
        await tester.pumpWidget(app());
        await open(tester);
        await library(tester);
        await tab(tester, 'Свои');
        await tester.tap(
          find.descendant(
            of: find.byType(ExpressionPackCard),
            matching: find.text('Pets'),
          ),
        );
        await tester.pumpAndSettle();
        input.value = const TextEditingValue(
          text: 'ab',
          selection: TextSelection.collapsed(offset: 1),
        );
        final kitten = find.byWidgetPredicate(
          (w) => w is CustomEmojiImage && w.emoji.shortcode == 'kitten',
        );
        await tester.tap(
          find.ancestor(of: kitten.last, matching: find.byType(InkWell)).first,
        );
        await tester.pumpAndSettle();
        expect(input.text, 'a:kitten:b');
        final search = find.byType(TextField).last;
        await tester.enterText(search, 'kitten');
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Закрыть'));
        await tester.pumpAndSettle();
        await open(tester);
        expect(
          tester
              .widget<TextField>(find.byType(TextField).last)
              .controller!
              .text,
          'kitten',
        );
        await tab(tester, 'Стикеры');
        final stickerGrid = find.byKey(const PageStorageKey('stickers:null:'));
        expect(stickerGrid, findsOneWidget);
        await tester.tap(
          find
              .descendant(of: stickerGrid, matching: find.byType(InkWell))
              .first,
        );
        await tester.pumpAndSettle();
        expect(sent.map((s) => s.id), [12]);
        await tab(tester, 'Свои');
        expect(
          tester
              .widget<TextField>(find.byType(TextField).last)
              .controller!
              .text,
          'kitten',
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets(
      'swipe opens library, keyboard keeps it usable, Back only closes picker',
      (tester) async {
        tester.view.physicalSize = const Size(360, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpWidget(app());
        await open(tester);
        await tester.drag(
          find.byKey(const ValueKey('expression-library-toggle')),
          const Offset(0, -75),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ExpressionPackCard), findsWidgets);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        expect(find.byType(ExpressionPackCard), findsWidgets);
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('expression-mode-tabs')).hitTestable(),
          findsNothing,
        );
        expect(find.byType(ChatInputBar), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });
}
