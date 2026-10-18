import 'dart:ui' as ui;

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/chat/noto_message_emoji.dart';
import 'package:pulse_flutter/widgets/message_bubble.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_io/io.dart';

class _StaticEmojiSettings extends UiSettingsNotifier {
  @override
  UiSettingsState build() => const UiSettingsState.defaults().copyWith(
    animateEmoji: false,
    soundEffects: false,
  );
}

void main() {
  final output = Platform.environment['NIOS_NOTO_CAPTURE_DIR'];
  if (output != null) {
    setUpAll(() async {
      for (final entry in {
        'Onest': 'assets/fonts/onest/Onest-Variable.ttf',
        'GolosText': 'assets/fonts/golos_text/GolosText-Variable.ttf',
        'BricolageGrotesque':
            'assets/fonts/bricolage_grotesque/BricolageGrotesque-Variable.ttf',
        'NotoColorEmoji': 'assets/fonts/noto_color_emoji/NotoColorEmoji.ttf',
        'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
      }.entries) {
        final loader = FontLoader(entry.key)
          ..addFont(rootBundle.load(entry.value));
        await loader.load();
      }
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets('Noto messages, static picker and bottom toast $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final capture = GlobalKey();
      late BuildContext toastContext;
      final theme = AppTheme.themed(
        const VisualThemeSettings(
          seedColor: Color(0xff6750a4),
          themeMode: ThemeMode.system,
          useSystemDynamic: false,
          predictiveBackEnabled: true,
        ),
        brightness,
      );
      final scheme = theme.colorScheme;
      const normalText = 'Обычное сообщение с эмодзи 😀';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            uiSettingsProvider.overrideWith(_StaticEmojiSettings.new),
          ],
          child: MaterialApp(
            theme: theme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('ru'),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.6),
                disableAnimations: true,
              ),
              child: RepaintBoundary(key: capture, child: child!),
            ),
            home: Scaffold(
              appBar: AppBar(title: const Text('Noto Emoji')),
              body: Builder(
                builder: (context) {
                  toastContext = context;
                  return Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: const [
                              MessageBubble(
                                key: ValueKey('noto-message-smile'),
                                text: '😀',
                                formattedTime: '12:00',
                                isMine: false,
                                chatId: 1,
                              ),
                              MessageBubble(
                                key: ValueKey('noto-message-tone'),
                                text: '👍🏽',
                                formattedTime: '12:01',
                                isMine: true,
                                isRead: true,
                                chatId: 1,
                              ),
                              MessageBubble(
                                key: ValueKey('noto-message-plain'),
                                text: normalText,
                                formattedTime: '12:02',
                                isMine: false,
                                chatId: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                      EmojiPicker(
                        config: Config(
                          height: 300,
                          checkPlatformCompatibility: false,
                          locale: const Locale('ru'),
                          emojiTextStyle: const TextStyle(
                            fontFamily: 'NotoColorEmoji',
                          ),
                          emojiViewConfig: EmojiViewConfig(
                            columns: 8,
                            backgroundColor: scheme.surfaceContainerLow,
                            buttonMode: ButtonMode.NONE,
                          ),
                          categoryViewConfig: CategoryViewConfig(
                            initCategory: Category.SMILEYS,
                            backgroundColor: scheme.surfaceContainerLow,
                            iconColor: scheme.onSurfaceVariant,
                            iconColorSelected: scheme.primary,
                            indicatorColor: scheme.primary,
                          ),
                          bottomActionBarConfig: const BottomActionBarConfig(
                            enabled: false,
                          ),
                        ),
                      ),
                      const SizedBox(height: 88),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NotoMessageEmoji), findsNWidgets(2));
      expect(tester.getSize(find.byType(NotoMessageEmoji).first).width, 112);
      for (final entry in {
        'noto-message-smile': '😀',
        'noto-message-tone': '👍🏽',
        'noto-message-plain': normalText,
      }.entries) {
        final bubble = find.byKey(ValueKey(entry.key));
        expect(tester.widget<MessageBubble>(bubble).text, entry.value);
        expect(
          find.descendant(
            of: bubble,
            matching: find.text(entry.value, findRichText: true),
          ),
          findsOneWidget,
        );
      }
      expect(
        tester
            .widget<EmojiPicker>(find.byType(EmojiPicker))
            .config
            .emojiTextStyle
            ?.fontFamily,
        'NotoColorEmoji',
      );
      AppToast.showInfo(toastContext, 'Сообщение сохранено');
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(SnackBar)).bottom, closeTo(1000, 1));
      expect(tester.takeException(), isNull);

      if (output != null) {
        await tester.runAsync(() async {
          final boundary =
              capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1.5);
          try {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory(output).create(recursive: true);
            await File(
              '$output/noto_${brightness.name}_large_text.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        });
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
