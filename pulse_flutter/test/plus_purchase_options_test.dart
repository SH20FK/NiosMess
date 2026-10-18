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
import 'package:pulse_flutter/widgets/plus_purchase_options.dart';

void main() {
  testWidgets(
    'regional catalog, purchase consent and inline activation validation',
    (tester) async {
      tester.view.physicalSize = const Size(960, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        final bytes = await File(
          'assets/fonts/golos_text/GolosText-Variable.ttf',
        ).readAsBytes();
        final loader = FontLoader('GolosText')
          ..addFont(Future.value(ByteData.sublistView(bytes)));
        await loader.load();
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(sessionAccessTokenProvider.notifier)
          .setToken('synthetic-token');
      final client = MockClient((request) async {
        expect(request.url.path, '/api/plus/catalog');
        expect(request.headers['Authorization'], 'Bearer synthetic-token');
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'region_tier': 'ru',
              'plans': [
                {
                  'id': '14d',
                  'duration': '14 дней',
                  'price_kopecks': 8050,
                  'promo': true,
                  'purchase_url': 'https://funpay.com/lots/offer?id=79858618',
                },
                {
                  'id': '30d',
                  'duration': '30 дней',
                  'price_kopecks': 18975,
                  'promo': false,
                  'purchase_url': 'https://funpay.com/lots/offer?id=79858775',
                },
              ],
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData(
              fontFamily: 'GolosText',
              colorScheme: const ColorScheme.dark(
                primary: Color(0xffff5a36),
                onPrimary: Color(0xff21120e),
                secondary: Color(0xffafbcff),
                surface: Color(0xff0b1025),
                onSurface: Color(0xffedf0f7),
              ),
            ),
            home: Scaffold(
              body: Center(
                child: RepaintBoundary(
                  key: boundaryKey,
                  child: SizedBox(
                    width: 480,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: PlusPurchaseOptions(
                        onChanged: () {},
                        clientFactory: () => client,
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
      expect(find.text('80,50 ₽'), findsOneWidget);
      expect(find.text('189,75 ₽'), findsOneWidget);
      expect(
        find.textContaining('К цене добавляется комиссия'),
        findsOneWidget,
      );
      expect(find.byType(AlertDialog), findsNothing);
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'build/plus-purchase-preview.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
      await tester.tap(find.text('Купить').first);
      await tester.pumpAndSettle();
      final submit = find.widgetWithText(FilledButton, 'Перейти на FunPay');
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'https://evil.example/plus/activate#bad',
      );
      await tester.tap(find.text('Проверить подписку'));
      await tester.pumpAndSettle();
      expect(
        find.text('Вставьте полную ссылку активации из заказа'),
        findsOneWidget,
      );
    },
  );
}
