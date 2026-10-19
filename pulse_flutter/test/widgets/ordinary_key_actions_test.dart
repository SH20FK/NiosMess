import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_service.dart';
import 'package:pulse_flutter/widgets/chat/ordinary_encryption_settings_button.dart';
import 'package:pulse_flutter/widgets/chat/ordinary_peer_key_notice.dart';
import 'package:pulse_flutter/widgets/chat/ordinary_e2ee_notice.dart';
import 'package:pulse_flutter/models/api/message_model.dart';

class _Keys extends OrdinaryE2eeService {
  _Keys() : super(1, (action, {payload}) async => <String, dynamic>{});
  String? epoch = 'new-epoch';
  @override
  String? contactKeyChange(int chatId) => epoch;
  @override
  Future<void> dismissContactKeyChange(int chatId, String value) async {
    epoch = null;
    notifyListeners();
  }
}

void main() {
  test(
    'settings action is limited to actual undecrypted ordinary messages',
    () {
      final vector =
          jsonDecode(
                File(
                  'test/fixtures/ordinary_e2ee_vectors.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final message = ApiMessage.fromJson({
        'id': 1,
        'chat_id': 11,
        'sender_id': 2,
        'is_e2ee': true,
        'e2ee_content': vector['packet'],
      });
      expect(needsOrdinaryEncryptionSettings(message), isTrue);
      expect(
        needsOrdinaryEncryptionSettings(
          message.copyWith(id: -1, isSending: true),
        ),
        isFalse,
      );
      expect(
        needsOrdinaryEncryptionSettings(message.copyWith(isDecrypted: true)),
        isFalse,
      );
      expect(
        needsOrdinaryEncryptionSettings(message.copyWith(isDeleted: true)),
        isFalse,
      );
    },
  );
  testWidgets('working ordinary chats do not demand manual key setup', (
    tester,
  ) async {
    final keys = _Keys()..initialised = true;
    addTearDown(keys.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [ordinaryE2eeProvider.overrideWithValue(keys)],
        child: const MaterialApp(home: Scaffold(body: OrdinaryE2eeNotice())),
      ),
    );
    expect(find.text('Сохраните ключ восстановления переписки'), findsNothing);
    expect(find.text('Открыть'), findsNothing);
    keys.locked = true;
    keys.notifyListeners();
    await tester.pump();
    expect(find.text('Ожидаем ключи защищённых чатов'), findsOneWidget);
  });
  for (final brightness in Brightness.values) {
    testWidgets(
      'local settings action and passive key notice fit 320px, 200% $brightness',
      (tester) async {
        if (Platform.environment['NIOS_KEY_ACTIONS_PREVIEW'] == '1') {
          for (final font in {
            'GolosText': 'golos_text/GolosText-Variable.ttf',
            'Onest': 'onest/Onest-Variable.ttf',
          }.entries) {
            await (FontLoader(
              font.key,
            )..addFont(rootBundle.load('assets/fonts/${font.value}'))).load();
          }
        }
        final keys = _Keys();
        addTearDown(keys.dispose);
        tester.view.physicalSize = const Size(320, 650);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundary = GlobalKey();
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, _) => Scaffold(
                body: RepaintBoundary(
                  key: boundary,
                  child: ColoredBox(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 16),
                          Text(
                            'Елена',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const OrdinaryPeerKeyNotice(
                            chatId: 11,
                            child: Text('В сети'),
                          ),
                          const SizedBox(height: 30),
                          const Text(
                            'Ожидаем ключи. Сообщение откроется автоматически после синхронизации.',
                          ),
                          const OrdinaryEncryptionSettingsButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '/settings/e2ee',
              builder: (context, _) =>
                  const Scaffold(body: Text('Настройки шифрования')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [ordinaryE2eeProvider.overrideWithValue(keys)],
            child: MaterialApp.router(
              routerConfig: router,
              theme: AppTheme.themed(
                const VisualThemeSettings(
                  seedColor: Color(0xFFEAB0FF),
                  themeMode: ThemeMode.dark,
                  predictiveBackEnabled: false,
                  useSystemDynamic: false,
                ),
                brightness,
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Ключ изменился'), findsOneWidget);
        expect(find.text('Перейти к настройкам чатов'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (Platform.environment['NIOS_KEY_ACTIONS_PREVIEW'] == '1') {
          await (FontLoader('GolosText')..addFont(
                rootBundle.load(
                  'assets/fonts/golos_text/GolosText-Variable.ttf',
                ),
              ))
              .load();
          await tester.pump();
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final path = File(
              'E:/NiosIDAndNiosmess/release/automatic-chat-keys/actions-${brightness.name}.png',
            );
            await path.parent.create(recursive: true);
            await path.writeAsBytes(data!.buffer.asUint8List());
          });
        }
        await tester.pump(const Duration(seconds: 9));
        await tester.pump();
        expect(find.text('В сети'), findsOneWidget);
        await tester.tap(find.text('Перейти к настройкам чатов'));
        await tester.pumpAndSettle();
        expect(find.text('Настройки шифрования'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
