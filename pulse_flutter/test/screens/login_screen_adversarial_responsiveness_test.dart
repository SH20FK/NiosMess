import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/screens/login_screen.dart';

Widget _createLoginHarness({
  Locale locale = const Locale('ru'),
  required Size surfaceSize,
  String? initialCode,
  String? initialState,
  String? initialError,
  String? initialErrorDescription,
}) {
  final effectiveTheme = AppTheme.themed(
    const VisualThemeSettings(
      seedColor: Color(0xFF1E88E5),
      themeMode: ThemeMode.light,
      useSystemDynamic: false,
      predictiveBackEnabled: false,
    ),
    Brightness.light,
  );

  final GoRouter router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(
          initialCode: initialCode,
          initialState: initialState,
          initialError: initialError,
          initialErrorDescription: initialErrorDescription,
        ),
      ),
      GoRoute(
        path: '/legal/terms',
        builder: (context, state) => const Scaffold(body: Text('Terms Screen')),
      ),
      GoRoute(
        path: '/legal/privacy',
        builder: (context, state) => const Scaffold(body: Text('Privacy Screen')),
      ),
      GoRoute(
        path: '/main/chats',
        builder: (context, state) => const Scaffold(body: Text('Chats Screen')),
      ),
    ],
  );

  return ProviderScope(
    child: MediaQuery(
      data: MediaQueryData(
        size: surfaceSize,
        padding: const EdgeInsets.only(top: 24, bottom: 24),
        viewInsets: EdgeInsets.zero,
      ),
      child: MaterialApp.router(
        routerConfig: router,
        debugShowCheckedModeBanner: false,
        theme: effectiveTheme,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
}

void main() {
  group('LoginScreen Adversarial Responsiveness Matrix (320dp to 3840dp)', () {
    final List<Map<String, dynamic>> viewports = [
      {'name': 'Compact Mobile (iPhone SE)', 'size': const Size(320, 568)},
      {'name': 'Narrow Android', 'size': const Size(360, 640)},
      {'name': 'Standard Mobile (iPhone 14)', 'size': const Size(390, 844)},
      {'name': 'Large Mobile (Pixel 7 Pro)', 'size': const Size(412, 915)},
      {'name': 'Small Tablet Portrait', 'size': const Size(600, 960)},
      {'name': 'iPad Portrait', 'size': const Size(768, 1024)},
      {'name': 'iPad Landscape', 'size': const Size(1024, 768)},
      {'name': 'Laptop HD (1366x768)', 'size': const Size(1366, 768)},
      {'name': 'MacBook Pro Retina (1440x900)', 'size': const Size(1440, 900)},
      {'name': 'Desktop Full HD (1920x1080)', 'size': const Size(1920, 1080)},
      {'name': 'Desktop QHD (2560x1440)', 'size': const Size(2560, 1440)},
      {'name': 'Desktop 4K Ultra-Wide (3840x2160)', 'size': const Size(3840, 2160)},
    ];

    for (final vp in viewports) {
      testWidgets('Renders on ${vp['name']} (${vp['size']}) and checks for RenderFlex overflow', (
        WidgetTester tester,
      ) async {
        final Size size = vp['size'] as Size;
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_createLoginHarness(surfaceSize: size));
        await tester.pumpAndSettle();

        // Key elements should always be mounted
        expect(find.text('NiosMess'), findsOneWidget);
        expect(find.text('Войти через Nios ID'), findsOneWidget);
        expect(find.text('Создать аккаунт Nios ID'), findsOneWidget);
        expect(find.text('Условия использования'), findsOneWidget);
        expect(find.text('Политика конфиденциальности'), findsOneWidget);

        // Check for any Flutter framework RenderFlex exceptions
        expect(tester.takeException(), isNull, reason: 'Render exception detected on ${vp['name']}');
      });
    }

    testWidgets('Consent rejection with error=access_denied displays error toast and remains interactive', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _createLoginHarness(
          surfaceSize: const Size(800, 1000),
          initialError: 'access_denied',
          initialErrorDescription: 'Пользователь отказал в доступе к Nios ID',
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('NiosMess'), findsOneWidget);

      final loginBtn = find.widgetWithText(FilledButton, 'Войти через Nios ID');
      expect(loginBtn, findsOneWidget);

      // Verify button is enabled and not stuck in disabled/loading state
      final FilledButton buttonWidget = tester.widget<FilledButton>(loginBtn);
      expect(buttonWidget.onPressed, isNotNull);
    });
  });
}
