import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/models/interactive_message.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/interactive_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/chat/interactive_composer.dart';
import 'package:pulse_flutter/widgets/chat/interactive_message_card.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState.initial().copyWith(
    session: const AuthSession(
      accessToken: 'fixture',
      userId: 2,
      username: 'fixture',
      displayName: 'Саша',
    ),
  );
}

void main() {
  final previews = Platform.environment['NIOS_INTERACTIVE_PREVIEW'] == '1';
  for (final brightness in Brightness.values) {
    for (final kind in ['poll', 'quiz', 'list']) {
      testWidgets('$kind creation fits 320px and large text $brightness', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showInteractiveComposer(context, kind),
                  child: const Text('Создать'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Создать'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // Empty input remains in the composer, with actionable validation.
        await tester.tap(find.text('Отправить'));
        await tester.pumpAndSettle();
        expect(find.text('Заполните поле'), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Закрыть'));
        await tester.pumpAndSettle();
        expect(find.text('Отправить'), findsNothing);
      });
    }
    testWidgets(
      'all interactive messages use the current theme at 320px $brightness',
      (tester) async {
        if (previews) {
          for (final font in {
            'GolosText': 'golos_text/GolosText-Variable.ttf',
            'Onest': 'onest/Onest-Variable.ttf',
          }.entries) {
            await (FontLoader(
              font.key,
            )..addFont(rootBundle.load('assets/fonts/${font.value}'))).load();
          }
        }
        tester.view.physicalSize = const Size(390, 1320);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final definitions = [
          InteractiveMessage.parse(
            InteractiveMessage.encode({
              'kind': 'poll',
              'document': 'document-poll',
              'title': 'Куда идём в субботу?',
              'items': ['В парк', 'В кино', 'Останемся дома'],
              'multiple': true,
            }, 'Опрос'),
          )!,
          InteractiveMessage.parse(
            InteractiveMessage.encode({
              'kind': 'quiz',
              'document': 'document-quiz',
              'title': 'Какая планета ближе к Солнцу?',
              'items': ['Венера', 'Меркурий'],
              'correct': 1,
              'explanation': 'Меркурий — первая планета от Солнца.',
            }, 'Викторина'),
          )!,
          InteractiveMessage.parse(
            InteractiveMessage.encode({
              'kind': 'list',
              'document': 'document-list',
              'title': 'Купить к ужину',
              'items': ['Помидоры', 'Хлеб', 'Молоко'],
            }, 'Список'),
          )!,
        ];
        final roots = [
          for (var i = 0; i < 3; i++)
            ApiMessage.fromJson({
              'id': 10 + i,
              'chat_id': 1,
              'sender_id': 1,
              'content': InteractiveMessage.encode(
                definitions[i].data,
                'Пример',
              ),
            }),
        ];
        ApiMessage event(int i, Map<String, dynamic> body) =>
            ApiMessage.fromJson({
              'id': 100 + i,
              'chat_id': 1,
              'sender_id': 2,
              'sender_display_name': 'Саша',
              'reply_to_id': roots[i].id,
              'content': InteractiveMessage.encode({
                'kind': 'update',
                'document': definitions[i].document,
                'definition': definitions[i].fingerprint,
                'root': roots[i].id,
                ...body,
              }, 'Изменение'),
            });
        final events = [
          event(0, {
            'action': 'vote',
            'choices': [0, 1],
          }),
          event(1, {
            'action': 'vote',
            'choices': [1],
          }),
          event(2, {'action': 'check', 'item': 0, 'checked': true}),
        ];
        final boundary = GlobalKey();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(_Auth.new),
              for (var i = 0; i < 3; i++)
                interactiveEventsProvider((
                  2,
                  1,
                  roots[i].id,
                )).overrideWith((ref) async => [events[i]]),
            ],
            child: MaterialApp(
              theme: AppTheme.themed(
                const VisualThemeSettings(
                  seedColor: Color(0xFFEAB0FF),
                  themeMode: ThemeMode.dark,
                  useSystemDynamic: false,
                  predictiveBackEnabled: false,
                ),
                brightness,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: RepaintBoundary(
                    key: boundary,
                    child: ColoredBox(
                      color: Theme.of(context).colorScheme.surface,
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              for (var i = 0; i < 3; i++)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Material(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: InteractiveMessageCard(
                                        message: roots[i],
                                        definition: definitions[i],
                                        foreground: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Верно'), findsOneWidget);
        expect(find.text('Выполнено 1 из 3'), findsOneWidget);
        expect(find.text('Изменить голос'), findsOneWidget);
        expect(find.byType(PulseAvatar), findsOneWidget);
        await tester.tap(find.text('Проголосовали: 1').first);
        await tester.pumpAndSettle();
        expect(find.byType(PulseAvatar), findsNWidgets(2));
        await tester.tap(find.text('Закрыть'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (previews) {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final path = File(
              'E:/NiosIDAndNiosmess/release/ballot-redesign/messages-${brightness.name}.png',
            );
            await path.parent.create(recursive: true);
            await path.writeAsBytes(data!.buffer.asUint8List());
          });
        }
        // Keep actual counts and action buttons readable at 200% / 320px.
        tester.view.physicalSize = const Size(320, 950);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
