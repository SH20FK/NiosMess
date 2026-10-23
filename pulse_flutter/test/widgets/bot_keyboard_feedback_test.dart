import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/chat/inline_keyboard_view.dart';
import 'package:pulse_flutter/widgets/chat/chat_detail_app_bar.dart';
import 'package:pulse_flutter/widgets/chat/chat_input_bar.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_service.dart';

class _Settings extends UiSettingsNotifier {
  @override
  UiSettingsState build() => const UiSettingsState.defaults().copyWith(
    soundEffects: false,
    haptics: false,
  );
}

Widget app(Widget child, {double scale = 1}) => ProviderScope(
  overrides: [
    uiSettingsProvider.overrideWith(_Settings.new),
    ordinaryE2eeProvider.overrideWithValue(null),
  ],
  child: MaterialApp(
    theme: ThemeData(useMaterial3: true),
    locale: const Locale('ru'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(body: Center(child: child)),
  ),
);
void main() {
  testWidgets(
    'many bot actions remain tappable at 320px and 200 percent text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final markup = InlineKeyboardMarkup(
        inlineKeyboard: [
          List.generate(
            6,
            (i) =>
                InlineKeyboardButton(text: 'Действие $i', callbackData: '$i'),
          ),
        ],
      );
      await tester.pumpWidget(
        app(
          InlineKeyboardView(replyMarkup: markup, onCallbackQuery: (_) {}),
          scale: 2,
        ),
      );
      for (var i = 0; i < 6; i++) {
        final action = find.ancestor(
          of: find.text('Действие $i'),
          matching: find.byType(InkWell),
        );
        expect(tester.getSize(action).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'a rejected callback keeps the action usable and offers a retry',
    (tester) async {
      var requests = 0;
      await tester.pumpWidget(
        app(
          InlineKeyboardView(
            replyMarkup: const InlineKeyboardMarkup(
              inlineKeyboard: [
                [InlineKeyboardButton(text: 'Запрос', callbackData: 'go')],
              ],
            ),
            onCallbackQuery: (_) async {
              requests++;
              throw StateError('offline');
            },
          ),
        ),
      );
      await tester.tap(find.text('Запрос'));
      await tester.pumpAndSettle();
      expect(find.byType(AppLoadingIndicator), findsNothing);
      expect(requests, 1);
      await tester.tap(find.text('Запрос'));
      await tester.pumpAndSettle();
      expect(requests, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    },
  );
  testWidgets(
    'bot callback gives feedback immediately and cannot fire twice until its acknowledgement',
    (tester) async {
      final ack = Completer<void>();
      var requests = 0;
      await tester.pumpWidget(
        app(
          InlineKeyboardView(
            replyMarkup: const InlineKeyboardMarkup(
              inlineKeyboard: [
                [InlineKeyboardButton(text: 'Открыть', callbackData: 'open')],
              ],
            ),
            onCallbackQuery: (_) {
              requests++;
              return ack.future;
            },
          ),
        ),
      );
      await tester.tap(find.text('Открыть'));
      await tester.pump();
      expect(requests, 1);
      expect(find.byType(AppLoadingIndicator), findsOneWidget);
      await tester.tap(find.text('Открыть'));
      await tester.pump();
      expect(requests, 1);
      ack.complete();
      await tester.pumpAndSettle();
      expect(find.byType(AppLoadingIndicator), findsNothing);
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      expect(requests, 2);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'attachment plus opens attachments directly, without poll creation',
    (tester) async {
      final input = TextEditingController();
      final focus = FocusNode();
      addTearDown(input.dispose);
      addTearDown(focus.dispose);
      var attachments = 0;
      await tester.pumpWidget(
        app(
          ChatInputBar(
            inputController: input,
            inputFocusNode: focus,
            isAiProcessing: false,
            uploadingMedia: false,
            editingMessageId: null,
            editingOriginalText: null,
            replyToMessageId: null,
            replyPreviewText: null,
            onSend: () {},
            onCommitEdit: () {},
            onCancelEdit: () {},
            onClearReply: () {},
            onAttachMedia: () => attachments++,
            onAiPressed: () {},
            onVoiceSend: (_) {},
            hapticsEnabled: false,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      expect(attachments, 1);
      expect(find.text('Опрос'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('interactive creation is discoverable in the chat header menu', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      app(
        SizedBox(
          height: 100,
          child: ChatDetailAppBar(
            chatId: 1,
            isDesktopSplit: false,
            title: 'Группа',
            headerIcon: Icons.groups_rounded,
            typingSubtitle: const Text('Участники'),
            onBack: () {},
            onCreateInteractive: (kind) => selected = kind,
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SubmenuButton, 'Создать'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Опрос'));
    await tester.pumpAndSettle();
    expect(selected, 'poll');
    expect(tester.takeException(), isNull);
  });
}
