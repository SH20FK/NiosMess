import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_codec.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_service.dart';
import 'package:pulse_flutter/widgets/settings/ordinary_e2ee_settings.dart';

class _Chats extends ChatsNotifier {
  @override
  Future<List<ApiChatSummary>> build() async => const [
    ApiChatSummary(
      id: 11,
      chatType: 'direct',
      name: 'Елена',
      unreadCount: 0,
      membersCount: 2,
    ),
  ];
}

void main() {
  group('Ordinary E2E settings', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
    });
    for (final brightness in Brightness.values) {
      testWidgets('theme and recovery controls fit 320px at 200% $brightness', (
        tester,
      ) async {
        if (Platform.environment['NIOS_E2EE_PREVIEW'] == '1') {
          for (final font in {
            'GolosText': 'golos_text/GolosText-Variable.ttf',
            'Onest': 'onest/Onest-Variable.ttf',
            'BricolageGrotesque':
                'bricolage_grotesque/BricolageGrotesque-Variable.ttf',
          }.entries) {
            await (FontLoader(
              font.key,
            )..addFont(rootBundle.load('assets/fonts/${font.value}'))).load();
          }
        }
        final identity = OrdinaryKeys.create(1);
        final recovery = randomE2eBytes();
        final public = await identity.public();
        final backup = await OrdinaryCodec.backup(identity, recovery);
        FlutterSecureStorage.setMockInitialValues({
          'niosmess.ordinary.1.v1.keys': jsonEncode({
            'keys': identity.secret(),
            'recovery': OrdinaryCodec.recoveryCode(recovery),
            'old': [],
          }),
        });
        final service = OrdinaryE2eeService(1, (action, {payload}) async {
          if (payload!['op'] == 'preference') {
            return {'enabled': payload['enabled']};
          }
          return {'enabled': true, 'identity': public, 'backup': backup};
        });
        await service.open();
        addTearDown(service.dispose);
        tester.view.physicalSize = const Size(320, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ordinaryE2eeProvider.overrideWithValue(service),
              chatsProvider.overrideWith(_Chats.new),
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
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(2)),
                child: child!,
              ),
              home: RepaintBoundary(
                key: boundary,
                child: const Scaffold(
                  body: SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: OrdinaryE2eeSettings(),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
        expect(find.text('Личные чаты · тестирование E2E'), findsOneWidget);
        expect(find.text(OrdinaryCodec.recoveryCode(recovery)), findsNothing);
        if (Platform.environment['NIOS_E2EE_PREVIEW'] == '1') {
          final font = FontLoader('GolosText')
            ..addFont(
              rootBundle.load('assets/fonts/golos_text/GolosText-Variable.ttf'),
            );
          await font.load();
          await tester.pump();
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            await File(
              'E:/NiosIDAndNiosmess/release/ordinary-e2ee/settings-${brightness.name}.png',
            ).writeAsBytes(data!.buffer.asUint8List());
          });
        }
        await tester.ensureVisible(find.text('Показать ключ'));
        await tester.tap(find.text('Показать ключ'));
        await tester.pumpAndSettle();
        expect(find.text(OrdinaryCodec.recoveryCode(recovery)), findsOneWidget);
        await tester.ensureVisible(find.text('Я сохранил ключ'));
        await tester.tap(find.text('Я сохранил ключ'));
        await tester.pumpAndSettle();
        expect(service.backupAcknowledged, isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
