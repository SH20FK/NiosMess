import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/theme/app_typography.dart';
import 'package:pulse_flutter/widgets/chat/chat_input_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Noto picker works offline and inserts the original Unicode', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final input = TextEditingController();
    final focus = FocusNode();
    addTearDown(input.dispose);
    addTearDown(focus.dispose);
    Widget app(Locale locale) => ProviderScope(
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          useMaterial3: true,
          textTheme: AppTypography.textTheme,
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
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(app(const Locale('en')));
    await tester.tap(find.byTooltip('Emoji'));
    await tester.pumpAndSettle();
    var config = tester.widget<EmojiPicker>(find.byType(EmojiPicker)).config;
    expect(config.checkPlatformCompatibility, isFalse);
    expect(config.emojiTextStyle?.fontFamily, AppFonts.emoji);
    expect(config.locale.languageCode, 'en');
    await tester.tap(find.byIcon(config.categoryViewConfig.categoryIcons.smileyIcon));
    await tester.pumpAndSettle();
    // No network/image provider: static cells are rendered with the local font.
    final face = find.text('😀');
    expect(face, findsWidgets);
    await tester.tap(face.first);
    await tester.pump();
    expect(input.text, '😀');

    await tester.pumpWidget(app(const Locale('ru')));
    await tester.pumpAndSettle();
    config = tester.widget<EmojiPicker>(find.byType(EmojiPicker)).config;
    expect(config.locale.languageCode, 'ru');
    expect(config.emojiTextStyle?.fontFamily, AppFonts.emoji);
    expect(input.text, '😀');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
