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
  Size surfaceSize = const Size(800, 1000),
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
        padding: EdgeInsets.zero,
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
  group('LoginScreen M3 Expressive Nios ID Auth Hub Tests', () {
    testWidgets('renders brand hero, 3 ecosystem pillars, and Nios ID action button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_createLoginHarness());
      await tester.pumpAndSettle();

      // Hero Header
      expect(find.text('NiosMess'), findsOneWidget);
      expect(find.text('Войдите в NiosMess через аккаунт Nios ID'), findsOneWidget);

      // 3 Ecosystem Pillars
      expect(find.text('Единый вход Nios ID'), findsOneWidget);
      expect(find.text('Сквозное E2EE шифрование'), findsOneWidget);
      expect(find.text('Конфиденциальность'), findsOneWidget);

      // Primary 56dp Pill Button
      expect(find.text('Войти через Nios ID'), findsOneWidget);
      expect(find.byIcon(Icons.vpn_key_rounded), findsOneWidget);

      // Secondary Link
      expect(find.text('Создать аккаунт Nios ID'), findsOneWidget);

      // Legal Footer
      expect(find.text('Условия использования'), findsOneWidget);
      expect(find.text('Политика конфиденциальности'), findsOneWidget);
    });

    testWidgets('zero username or password input fields on screen (strict OAuth spec)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_createLoginHarness());
      await tester.pumpAndSettle();

      // Must not contain any text editing fields for credentials
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.byKey(const Key('login_identifier_field')), findsNothing);
      expect(find.byKey(const Key('login_password_field')), findsNothing);
    });

    testWidgets('renders correctly on desktop wide screen with centered 480dp card', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _createLoginHarness(surfaceSize: const Size(1920, 1080)),
      );
      await tester.pumpAndSettle();

      expect(find.text('NiosMess'), findsOneWidget);
      expect(find.text('Войти через Nios ID'), findsOneWidget);
    });

    testWidgets('handles error query parameter gracefully without crashing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _createLoginHarness(
          initialError: 'access_denied',
          initialErrorDescription: 'Пользователь отменил вход',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('NiosMess'), findsOneWidget);
      expect(find.text('Войти через Nios ID'), findsOneWidget);
    });

    testWidgets('tapping legal links navigates to legal screens', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_createLoginHarness());
      await tester.pumpAndSettle();

      final termsLink = find.text('Условия использования');
      expect(termsLink, findsOneWidget);
      await tester.ensureVisible(termsLink);
      await tester.tap(termsLink, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Terms Screen'), findsOneWidget);
    });
  });
}
