import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/screens/settings_plus_screen.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState.initial();
}

class _Socket extends WebSocketClient {
  _Socket() : super(baseUrl: 'wss://test.invalid', readToken: () => null);
  @override
  Future<dynamic> request(
    String action, {
    Map<String, dynamic>? payload,
    Duration timeout = const Duration(seconds: 15),
    int maxRetries = 2,
  }) async => {'is_nios_plus': true};
}

void main() {
  for (final direct in [true, false]) {
    testWidgets(
      'Plus back exits ${direct ? "direct route" : "pushed route"}, even after scrolling',
      (tester) async {
        tester.view.physicalSize = const Size(1084, 711);
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
        final key = GlobalKey();
        final router = GoRouter(
          initialLocation: direct ? '/settings/plus' : '/origin',
          routes: [
            GoRoute(
              path: '/main/chats',
              builder: (_, _) => const Scaffold(body: Text('Chats')),
            ),
            GoRoute(
              path: '/origin',
              builder: (context, _) => Scaffold(
                body: TextButton(
                  onPressed: () => context.push('/settings/plus'),
                  child: const Text('Open Plus'),
                ),
              ),
            ),
            GoRoute(
              path: '/settings/plus',
              builder: (_, _) =>
                  RepaintBoundary(key: key, child: const SettingsPlusScreen()),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(_Auth.new),
              webSocketClientProvider.overrideWithValue(_Socket()),
            ],
            child: MaterialApp.router(
              theme: ThemeData.dark().copyWith(
                textTheme: ThemeData.dark().textTheme.apply(
                  fontFamily: 'GolosText',
                ),
              ),
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (!direct) {
          await tester.tap(find.text('Open Plus'));
          await tester.pumpAndSettle();
        }
        expect(find.text('Назад'), findsOneWidget);
        if (direct) {
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              'build/plus-back-navigation.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Назад'));
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          direct ? '/main/chats' : '/origin',
        );
        expect(find.text(direct ? 'Chats' : 'Open Plus'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
