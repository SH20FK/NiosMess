import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_io/io.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/providers/secret_chat_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/chat/e2ee_verification_sheet.dart';
import 'package:pulse_flutter/widgets/chat/security_status_chip.dart';
import '../services/secret_chat_delivery_test.dart' show Pair;

void main() {
  Widget verificationApp(Pair pair) => ProviderScope(
    overrides: [
      appSoundProvider.overrideWithValue(SoundService()..setEnabled(false)),
      secretChatEngineProvider.overrideWithValue(pair.a),
      secretChatRevisionProvider.overrideWith(
        (ref) => pair.a.changes.map((_) => 1),
      ),
    ],
    child: MaterialApp(
      theme: ThemeData(useMaterial3: true),
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: E2eeVerificationSheet(chatId: 42)),
    ),
  );

  testWidgets(
    'pressing Codes match preserves session and subsequent bidirectional delivery',
    (tester) async {
      final pair = (await tester.runAsync(() async {
        final pair = Pair();
        await pair.start();
        await pair.settle();
        pair.hub.online = false;
        await pair.a.enqueue(42, {
          'text': 'queued before button',
          'type': 'text',
        });
        return pair;
      }))!;
      addTearDown(pair.close);
      final before = pair.a.chat(42)..remove('verified');
      await tester.pumpWidget(verificationApp(pair));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.qr_code_rounded));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Коды совпадают'));
      await tester.runAsync(() async {
        final saved = pair.a.changes.firstWhere(
          (_) => pair.a.chat(42)['verified'] == true,
        );
        await tester.tap(find.text('Коды совпадают'));
        await saved;
      });
      await tester.pumpAndSettle();
      expect(pair.a.chat(42)..remove('verified'), before);
      expect(find.text('Код проверен'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        pair.hub.online = true;
        await pair.a.enqueue(42, {'text': 'sent after button', 'type': 'text'});
        await pair.b.enqueue(42, {
          'text': 'received after button',
          'type': 'text',
        });
        await pair.settle();
      });
      await tester.pumpAndSettle();
      expect(
        pair.b.messages(42).any((m) => m['content'] == 'queued before button'),
        true,
      );
      expect(
        pair.b.messages(42).any((m) => m['content'] == 'sent after button'),
        true,
      );
      expect(
        pair.a.messages(42).any((m) => m['content'] == 'received after button'),
        true,
      );
      expect(pair.a.chat(42)['status'], 'secured');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed verification write reports error without deleting queued text',
    (tester) async {
      final pair = (await tester.runAsync(() async {
        final pair = Pair();
        await pair.start();
        await pair.settle();
        pair.hub.online = false;
        await pair.a.enqueue(42, {
          'text': 'preserve this queue',
          'type': 'text',
        });
        return pair;
      }))!;
      addTearDown(pair.close);
      await tester.pumpWidget(verificationApp(pair));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.qr_code_rounded));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Коды совпадают'));
      pair.aDisk.fail = true;
      await tester.runAsync(() async {
        await tester.tap(find.text('Коды совпадают'));
        await Future<void>.delayed(const Duration(milliseconds: 40));
      });
      await tester.pumpAndSettle();
      expect(pair.a.chat(42)['verified'], isNot(true));
      expect(pair.a.messages(42).single['content'], 'preserve this queue');
      expect(
        find.text('Не удалось сохранить проверку ключа. Сообщения не удалены.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  setUpAll(() async {
    for (final font in {
      'BricolageGrotesque':
          'assets/fonts/bricolage_grotesque/BricolageGrotesque-Variable.ttf',
      'Onest': 'assets/fonts/onest/Onest-Variable.ttf',
      'GolosText': 'assets/fonts/golos_text/GolosText-Variable.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final loader = FontLoader(font.key)..addFont(rootBundle.load(font.value));
      await loader.load();
    }
  });
  for (final brightness in Brightness.values) {
    for (final locale in ['ru', 'en']) {
      testWidgets(
        'protection panel $locale $brightness fits 320px at 200% text',
        (tester) async {
          final pair = (await tester.runAsync(() async {
            final pair = Pair();
            await pair.start();
            await pair.settle();
            pair.hub.online = false;
            return pair;
          }))!;
          addTearDown(pair.close);
          tester.view.physicalSize = const Size(320, 720);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final boundary = GlobalKey();
          final theme = AppTheme.themed(
            const VisualThemeSettings(
              seedColor: Color(0xff6750a4),
              themeMode: ThemeMode.system,
              useSystemDynamic: false,
              predictiveBackEnabled: true,
            ),
            brightness,
          );
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                secretChatEngineProvider.overrideWithValue(pair.a),
                secretChatRevisionProvider.overrideWith(
                  (ref) => pair.a.changes.map((_) => 1),
                ),
              ],
              child: RepaintBoundary(
                key: boundary,
                child: MaterialApp(
                  theme: theme,
                  locale: Locale(locale),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(2)),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: Column(
                      children: [
                        SecurityStatusChip(chatId: 42, onTap: () {}),
                        const Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: E2eeVerificationSheet(chatId: 42),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(SelectableText), findsNothing);
          expect(
            find.text(locale == 'ru' ? 'Секретный чат' : 'Secret chat'),
            findsWidgets,
          );
          expect(tester.takeException(), isNull);
          final output = Platform.environment['SECRET_UI_OUTPUT'];
          if (output != null) {
            await tester.runAsync(() async {
              final image =
                  await (boundary.currentContext!.findRenderObject()
                          as RenderRepaintBoundary)
                      .toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                '$output/secret-$locale-${brightness.name}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.ensureVisible(find.byIcon(Icons.qr_code_rounded));
          await tester.tap(find.byIcon(Icons.qr_code_rounded));
          await tester.pumpAndSettle();
          expect(find.byType(SelectableText), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
