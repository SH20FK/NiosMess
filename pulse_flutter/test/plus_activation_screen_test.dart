import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pulse_flutter/providers/token_provider.dart';
import 'package:pulse_flutter/screens/plus_activation_screen.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('activation respects $brightness, consent and narrow layout', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        final font = await File(
          'assets/fonts/golos_text/GolosText-Variable.ttf',
        ).readAsBytes();
        await (FontLoader(
          'GolosText',
        )..addFont(Future.value(ByteData.sublistView(font)))).load();
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(sessionAccessTokenProvider.notifier)
          .setToken('test-session');
      var redeemed = 0;
      var hashReads = 0;
      final boundary = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData(
              fontFamily: 'GolosText',
              brightness: brightness,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xffa824bc),
                brightness: brightness,
              ),
            ),
            home: RepaintBoundary(
              key: boundary,
              child: PlusActivationScreen(
                code: 'test-activation-code',
                deviceHashReader: () async {
                  hashReads++;
                  return 'a' * 64;
                },
                onActivated: () async {},
                clientFactory: () => MockClient((request) async {
                  final body = jsonDecode(request.body) as Map<String, dynamic>;
                  expect(
                    request.headers['Authorization'],
                    'Bearer test-session',
                  );
                  if (request.url.path.endsWith('/redeem')) {
                    redeemed++;
                    expect(body['device_hash_consent'], isTrue);
                    expect(body['expected_account'], 'test-account');
                    expect(body['device_hash'], 'a' * 64);
                    return http.Response.bytes(
                      utf8.encode(
                        jsonEncode({'expires_at': '2026-12-01T00:00:00Z'}),
                      ),
                      200,
                    );
                  }
                  return http.Response.bytes(
                    utf8.encode(
                      jsonEncode({
                        'plan': '30d',
                        'duration': '30 дней',
                        'username': 'nios_user',
                        'account': 'test-account',
                        'already_redeemed': false,
                      }),
                    ),
                    200,
                  );
                }),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('@nios_user'), findsOneWidget);
      expect(find.text('Активировать на 30 дней?'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(hashReads, 0);
      final buttonContext = tester.element(find.byType(FilledButton));
      final scheme = Theme.of(buttonContext).colorScheme;
      expect(scheme.brightness, brightness);
      expect(
        tester
            .widget<FilledButton>(find.byType(FilledButton))
            .style!
            .backgroundColor!
            .resolve({}),
        scheme.primary,
      );
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'build/plus-activation-${brightness.name}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(redeemed, 1);
      expect(hashReads, 1);
      expect(find.text('Подписка активирована'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
