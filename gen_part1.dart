// Comprehensive Material 3 Expressive Auth & Onboarding E2E Test Suite (Tiers 1-4)
// Opaque-box requirement-driven testing across all authentication and onboarding features.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/core/services/biometric_service.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/session_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/repositories/auth_repository.dart';
import 'package:pulse_flutter/screens/onboarding_screen.dart';
import 'package:pulse_flutter/screens/setup_onboarding_screen.dart';
import 'package:pulse_flutter/screens/login_screen.dart';
import 'package:pulse_flutter/screens/register_screen.dart';
import 'package:pulse_flutter/screens/two_fa_screen.dart';
import 'package:pulse_flutter/screens/verify_email_screen.dart';
import 'package:pulse_flutter/screens/reset_password_request_screen.dart';
import 'package:pulse_flutter/screens/reset_password_confirm_screen.dart';
import 'package:pulse_flutter/widgets/m3_auth_text_field.dart';
import 'package:pulse_flutter/widgets/code_preview.dart';
import 'package:pulse_flutter/widgets/app_logo_mark.dart';
import 'package:pulse_flutter/widgets/pulse_button.dart';

// --- Test Fakes & Mock Infrastructure ---

class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository(super.ref);

  AuthLoginResult loginResult = const AuthLoginResult(
    accessToken: 'mock_access_token_123',
    userId: 100,
    username: 'alex_r',
    displayName: 'Alex Rivera',
  );

  AuthLoginResult twoFaResult = const AuthLoginResult(
    accessToken: 'mock_access_token_2fa_456',
    userId: 100,
    username: 'alex_r',
    displayName: 'Alex Rivera',
  );

  Map<String, dynamic> registerResult = <String, dynamic>{
    'message': 'Registration successful. Verification code sent.',
  };

  Map<String, dynamic> verifyEmailResult = <String, dynamic>{
    'message': 'Email verified successfully.',
  };

  Map<String, dynamic> resetRequestResult = <String, dynamic>{
    'message': 'Password reset email sent.',
  };

  Map<String, dynamic> resetConfirmResult = <String, dynamic>{
    'message': 'Password has been reset successfully.',
  };

  bool shouldRequireTwoFa = false;
  bool shouldFailLogin = false;
  bool shouldFailRegister = false;
  bool shouldFailVerifyEmail = false;
  bool shouldFailTwoFa = false;
  bool shouldFailResetRequest = false;
  bool shouldFailResetConfirm = false;

  String? lastLoginIdentifier;
  String? lastLoginPassword;
  String? lastRegisterEmail;
  String? lastRegisterUsername;
  String? lastRegisterDisplayName;
  String? lastVerifyEmailCode;
  String? lastTwoFaCode;
  String? lastResetRequestEmail;
  String? lastResetConfirmNewPassword;

  @override
  Future<AuthLoginResult> login({
    required String identifier,
    required String password,
  }) async {
    lastLoginIdentifier = identifier;
    lastLoginPassword = password;

    if (shouldRequireTwoFa) {
      return const AuthLoginResult(
        twoFaRequired: true,
        message: 'Two-factor authentication required',
      );
    }
    if (shouldFailLogin) {
      return const AuthLoginResult(
        message: 'Invalid identifier or password',
      );
    }
    return loginResult;
  }

  @override
  Future<AuthLoginResult> verifyTwoFa({
    required String identifier,
    required String code,
  }) async {
    lastTwoFaCode = code;
    if (shouldFailTwoFa || code == '000000') {
      return const AuthLoginResult(
        message: 'Invalid 2FA authentication code',
      );
    }
    return twoFaResult;
  }

  @override
  Future<Map<String, dynamic>> register({
    required String email,
    required String username,
    required String displayName,
    required String password,
  }) async {
    lastRegisterEmail = email;
    lastRegisterUsername = username;
    lastRegisterDisplayName = displayName;
    if (shouldFailRegister) {
      throw Exception('Username or email already in use');
    }
    return registerResult;
  }

  @override
  Future<Map<String, dynamic>> verifyEmail({
    required String email,
    required String code,
  }) async {
    lastVerifyEmailCode = code;
    if (shouldFailVerifyEmail || code == '000000') {
      throw Exception('Verification code expired or invalid');
    }
    return verifyEmailResult;
  }

  @override
  Future<Map<String, dynamic>> requestPasswordReset({
    required String email,
  }) async {
    lastResetRequestEmail = email;
    if (shouldFailResetRequest) {
      throw Exception('Account with this email does not exist');
    }
    return resetRequestResult;
  }

  @override
  Future<Map<String, dynamic>> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    lastResetConfirmNewPassword = newPassword;
    if (shouldFailResetConfirm || code == '000000') {
      throw Exception('Invalid reset code provided');
    }
    return resetConfirmResult;
  }

  @override
  Future<ApiProfile> getMe() async {
    return const ApiProfile(
      id: 100,
      username: 'alex_r',
      displayName: 'Alex Rivera',
      bio: 'NiosMess Test Bio',
    );
  }

  @override
  Future<ApiProfile> updateProfile({
    String? displayName,
    String? username,
    String? bio,
  }) async {
    return ApiProfile(
      id: 100,
      username: username ?? 'alex_r',
      displayName: displayName ?? 'Alex Rivera',
      bio: bio ?? 'Updated Bio',
    );
  }

  @override
  Future<void> logout() async {}

  @override
  Future<void> unregisterFcmToken(String fcmToken) async {}
}

class FakeBiometricService extends BiometricService {
  bool isSupported = true;
  bool canCheck = true;
  bool isEnabled = false;
  bool authSuccess = true;

  @override
  Future<bool> get isDeviceSupported async => isSupported;

  @override
  Future<bool> get canCheckBiometrics async => canCheck;

  @override
  Future<bool> get isBiometricEnabled async => isEnabled;

  @override
  Future<void> setBiometricEnabled(bool value) async {
    isEnabled = value;
  }

  @override
  Future<bool> authenticate({String reason = 'Подтвердите личность'}) async {
    return authSuccess;
  }

  @override
  Future<bool> authenticateIfEnabled() async {
    if (!isEnabled) return true;
    return authenticate();
  }
}

GoRouter createAuthTestRouter({
  String initialLocation = '/login',
  List<RouteBase>? extraRoutes,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/onboarding',
        builder: (BuildContext context, GoRouterState state) =>
            const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (BuildContext context, GoRouterState state) =>
            const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (BuildContext context, GoRouterState state) =>
            const RegisterScreen(),
      ),
      GoRoute(
        path: '/setup',
        builder: (BuildContext context, GoRouterState state) =>
            const SetupOnboardingScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (BuildContext context, GoRouterState state) =>
            VerifyEmailScreen(
              initialEmail: state.uri.queryParameters['email'],
            ),
      ),
      GoRoute(
        path: '/2fa',
        builder: (BuildContext context, GoRouterState state) =>
            TwoFaScreen(
              initialIdentifier: state.uri.queryParameters['identifier'],
            ),
      ),
      GoRoute(
        path: '/reset-password/request',
        builder: (BuildContext context, GoRouterState state) =>
            const ResetPasswordRequestScreen(),
      ),
      GoRoute(
        path: '/reset-password/confirm',
        builder: (BuildContext context, GoRouterState state) =>
            ResetPasswordConfirmScreen(
              initialEmail: state.uri.queryParameters['email'],
            ),
      ),
      GoRoute(
        path: '/main/chats',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Center(child: Text('Main Chats Screen'))),
      ),
      GoRoute(
        path: '/legal/terms',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Center(child: Text('Terms of Service Screen'))),
      ),
      GoRoute(
        path: '/legal/privacy',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Center(child: Text('Privacy Policy Screen'))),
      ),
      ...?extraRoutes,
    ],
  );
}

Widget buildAuthTestHarness({
  Widget? child,
  GoRouter? router,
  String initialLocation = '/login',
  List<dynamic> overrides = const <dynamic>[],
  Locale locale = const Locale('en'),
  ThemeData? theme,
  Size? surfaceSize,
}) {
  final ThemeData effectiveTheme = theme ??
      AppTheme.themed(
        const VisualThemeSettings(
          seedColor: Color(0xFF1E88E5),
          themeMode: ThemeMode.light,
          useSystemDynamic: false,
          predictiveBackEnabled: false,
        ),
        Brightness.light,
      );

  final GoRouter effectiveRouter = router ??
      (child != null
          ? GoRouter(
              initialLocation: '/',
              routes: <RouteBase>[
                GoRoute(
                  path: '/',
                  builder: (BuildContext context, GoRouterState state) =>
                      Scaffold(body: child),
                ),
                GoRoute(
                  path: '/onboarding',
                  builder: (BuildContext context, GoRouterState state) =>
                      const OnboardingScreen(),
                ),
                GoRoute(
                  path: '/login',
                  builder: (BuildContext context, GoRouterState state) =>
                      const LoginScreen(),
                ),
                GoRoute(
                  path: '/register',
                  builder: (BuildContext context, GoRouterState state) =>
                      const RegisterScreen(),
                ),
                GoRoute(
                  path: '/setup',
                  builder: (BuildContext context, GoRouterState state) =>
                      const SetupOnboardingScreen(),
                ),
                GoRoute(
                  path: '/verify-email',
                  builder: (BuildContext context, GoRouterState state) =>
                      VerifyEmailScreen(
                        initialEmail: state.uri.queryParameters['email'],
                      ),
                ),
                GoRoute(
                  path: '/2fa',
                  builder: (BuildContext context, GoRouterState state) =>
                      TwoFaScreen(
                        initialIdentifier: state.uri.queryParameters['identifier'],
                      ),
                ),
                GoRoute(
                  path: '/reset-password/request',
                  builder: (BuildContext context, GoRouterState state) =>
                      const ResetPasswordRequestScreen(),
                ),
                GoRoute(
                  path: '/reset-password/confirm',
                  builder: (BuildContext context, GoRouterState state) =>
                      ResetPasswordConfirmScreen(
                        initialEmail: state.uri.queryParameters['email'],
                      ),
                ),
                GoRoute(
                  path: '/main/chats',
                  builder: (BuildContext context, GoRouterState state) =>
                      const Scaffold(body: Center(child: Text('Main Chats Screen'))),
                ),
                GoRoute(
                  path: '/legal/terms',
                  builder: (BuildContext context, GoRouterState state) =>
                      const Scaffold(body: Center(child: Text('Terms of Service Screen'))),
                ),
                GoRoute(
                  path: '/legal/privacy',
                  builder: (BuildContext context, GoRouterState state) =>
                      const Scaffold(body: Center(child: Text('Privacy Policy Screen'))),
                ),
              ],
            )
          : createAuthTestRouter(initialLocation: initialLocation));

  Widget app = MaterialApp.router(
    debugShowCheckedModeBanner: false,
    theme: effectiveTheme,
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: effectiveRouter,
  );

  if (surfaceSize != null) {
    app = MediaQuery(
      data: MediaQueryData(
        size: surfaceSize,
        padding: EdgeInsets.zero,
        viewInsets: EdgeInsets.zero,
      ),
      child: app,
    );
  }

  return ProviderScope(
    overrides: overrides.cast(),
    child: app,
  );
}
