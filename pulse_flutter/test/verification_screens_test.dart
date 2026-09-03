import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/screens/two_fa_screen.dart';
import 'package:pulse_flutter/screens/verify_email_screen.dart';
import 'package:pulse_flutter/screens/reset_password_request_screen.dart';
import 'package:pulse_flutter/screens/reset_password_confirm_screen.dart';

class TestAuthNotifier extends AuthNotifier {
  TestAuthNotifier({
    this.initialState = const AuthState(
      hydrated: true,
      busy: false,
      session: null,
      pendingIdentifier: 'user@example.com',
      error: null,
      profile: null,
    ),
    this.onVerifyTwoFa,
    this.onVerifyEmail,
    this.onRequestPasswordReset,
    this.onConfirmPasswordReset,
  });

  final AuthState initialState;
  final Future<AuthActionResult> Function(String code)? onVerifyTwoFa;
  final Future<AuthActionResult> Function(String email, String code)? onVerifyEmail;
  final Future<AuthActionResult> Function(String email)? onRequestPasswordReset;
  final Future<AuthActionResult> Function(
    String email,
    String code,
    String newPassword,
  )? onConfirmPasswordReset;

  @override
  AuthState build() => initialState;

  @override
  Future<AuthActionResult> verifyTwoFa({required String code}) async {
    if (onVerifyTwoFa != null) {
      return onVerifyTwoFa!(code);
    }
    return const AuthActionResult(success: true);
  }

  @override
  Future<AuthActionResult> verifyEmail({
    required String email,
    required String code,
  }) async {
    if (onVerifyEmail != null) {
      return onVerifyEmail!(email, code);
    }
    return const AuthActionResult(success: true);
  }

  @override
  Future<AuthActionResult> requestPasswordReset({required String email}) async {
    if (onRequestPasswordReset != null) {
      return onRequestPasswordReset!(email);
    }
    return const AuthActionResult(success: true);
  }

  @override
  Future<AuthActionResult> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    if (onConfirmPasswordReset != null) {
      return onConfirmPasswordReset!(email, code, newPassword);
    }
    return const AuthActionResult(success: true);
  }
}

Widget _buildTestApp({
  required List<dynamic> overrides,
  required Widget child,
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

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => child,
      ),
      GoRoute(
        path: '/main/chats',
        builder: (context, state) => const Scaffold(body: Text('Chats')),
      ),
    ],
  );

  return ProviderScope(
    overrides: overrides.cast(),
    child: MaterialApp.router(
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      theme: effectiveTheme,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  group('TwoFaScreen Tests', () {
    testWidgets('renders dialpad and accepts 6 digits', (tester) async {
      String submittedCode = '';
      final mockNotifier = TestAuthNotifier(
        onVerifyTwoFa: (code) async {
          submittedCode = code;
          return const AuthActionResult(success: true);
        },
      );

      await tester.pumpWidget(
        _buildTestApp(
          overrides: [
            authProvider.overrideWith(() => mockNotifier),
          ],
          child: const TwoFaScreen(initialIdentifier: 'user@example.com'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TwoFaScreen), findsOneWidget);

      // Tap digits 1, 2, 3, 4, 5, 6
      for (final digit in ['1', '2', '3', '4', '5', '6']) {
        final btn = find.widgetWithText(InkWell, digit);
        if (btn.evaluate().isNotEmpty) {
          await tester.tap(btn.first);
        }
      }
      await tester.pumpAndSettle();
      expect(submittedCode, '123456');
    });
  });

  group('VerifyEmailScreen Tests', () {
    testWidgets('renders verify email screen and elements', (tester) async {
      final mockNotifier = TestAuthNotifier();

      await tester.pumpWidget(
        _buildTestApp(
          overrides: [
            authProvider.overrideWith(() => mockNotifier),
          ],
          child: const VerifyEmailScreen(initialEmail: 'test@niosmess.com'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VerifyEmailScreen), findsOneWidget);
    });
  });

  group('ResetPasswordRequestScreen Tests', () {
    testWidgets('renders reset password request screen', (tester) async {
      final mockNotifier = TestAuthNotifier();

      await tester.pumpWidget(
        _buildTestApp(
          overrides: [
            authProvider.overrideWith(() => mockNotifier),
          ],
          child: const ResetPasswordRequestScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ResetPasswordRequestScreen), findsOneWidget);
    });
  });

  group('ResetPasswordConfirmScreen Tests', () {
    testWidgets('renders reset password confirm screen', (tester) async {
      final mockNotifier = TestAuthNotifier();

      await tester.pumpWidget(
        _buildTestApp(
          overrides: [
            authProvider.overrideWith(() => mockNotifier),
          ],
          child: const ResetPasswordConfirmScreen(initialEmail: 'bob@example.com'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ResetPasswordConfirmScreen), findsOneWidget);
    });
  });
}
