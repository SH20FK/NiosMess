import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/screens/settings_password_screen.dart';
import 'package:pulse_flutter/services/password_reset_service.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the fake Nios ID did and what it was asked to do.
class _Server {
  int requests = 0;
  int resets = 0;
  String? requestEmail;
  String? resetEmail;
  String? resetCode;
  String? resetPassword;
  PasswordResetException? requestFailure;
  PasswordResetException? resetFailure;
}

class _Service extends PasswordResetService {
  const _Service(this.server);
  final _Server server;

  @override
  Future<void> requestCode(String email, {http.Client? client}) async {
    server.requests++;
    server.requestEmail = email;
    final PasswordResetException? failure = server.requestFailure;
    if (failure != null) throw failure;
  }

  @override
  Future<void> reset({
    required String email,
    required String code,
    required String newPassword,
    http.Client? client,
  }) async {
    server.resets++;
    server.resetEmail = email;
    server.resetCode = code;
    server.resetPassword = newPassword;
    final PasswordResetException? failure = server.resetFailure;
    if (failure != null) throw failure;
  }
}

class _Auth extends AuthNotifier {
  _Auth({this.email});

  final String? email;

  @override
  AuthState build() => AuthState(
    hydrated: true,
    busy: false,
    session: const AuthSession(
      accessToken: 'fixture',
      userId: 1,
      username: 'account1',
      displayName: 'Account 1',
    ),
    pendingIdentifier: null,
    error: null,
    profile: ApiProfile(
      id: 1,
      username: 'account1',
      displayName: 'Account 1',
      bio: '',
      email: email,
    ),
  );
}

const ValueKey<String> _sendCode = ValueKey<String>(
  'settings-password-send-code',
);
const ValueKey<String> _codeField = ValueKey<String>('settings-password-code');
const ValueKey<String> _newPasswordField = ValueKey<String>(
  'settings-password-new',
);
const ValueKey<String> _repeatField = ValueKey<String>(
  'settings-password-repeat',
);
const ValueKey<String> _submit = ValueKey<String>('settings-password-submit');
const ValueKey<String> _done = ValueKey<String>('settings-password-done');
const ValueKey<String> _openPortal = ValueKey<String>(
  'settings-password-open-nios-id',
);
const ValueKey<String> _resend = ValueKey<String>('settings-password-resend');

/// The profile has not arrived yet: saying "no email" now would be wrong.
class _NoProfileAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    hydrated: true,
    busy: false,
    session: AuthSession(
      accessToken: 'fixture',
      userId: 1,
      username: 'account1',
      displayName: 'Account 1',
    ),
    pendingIdentifier: null,
    error: null,
    profile: null,
  );
}

Future<void> _open(
  WidgetTester tester,
  _Server server,
  AuthNotifier auth, {
  // A waiting profile spins a loading indicator forever: settling would hang.
  bool settle = true,
}) async {
  // Tall enough to keep every control on screen without scrolling.
  tester.view.physicalSize = const Size(600, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('Hub route')),
      ),
      GoRoute(
        path: '/password',
        builder: (_, _) => const SettingsPasswordScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(() => auth),
        passwordResetServiceProvider.overrideWith(
          (Ref ref) => _Service(server),
        ),
      ],
      child: MaterialApp.router(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  Future<void> advance() async {
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  await advance();
  router.push('/password');
  await advance();
}

FilledButton _submitButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(_submit));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Settings password screen', () {
    testWidgets('code, password, then a done card that leaves the page', (
      tester,
    ) async {
      final _Server server = _Server();
      final _Auth auth = _Auth(email: 'user@example.com');
      await _open(tester, server, auth);

      // Step one names the address the code goes to.
      expect(find.textContaining('user@example.com'), findsOneWidget);
      expect(find.byKey(_codeField), findsNothing);

      await tester.tap(find.byKey(_sendCode));
      await tester.pumpAndSettle();
      expect(server.requests, 1);
      expect(server.requestEmail, 'user@example.com');
      expect(find.byKey(_codeField), findsOneWidget);
      expect(_submitButton(tester).onPressed, isNull);

      // Six digits alone do not unlock the button.
      await tester.enterText(find.byKey(_codeField), '123456');
      await tester.pump();
      expect(_submitButton(tester).onPressed, isNull);

      // A password the Nios ID would refuse keeps it locked too.
      await tester.enterText(find.byKey(_newPasswordField), 'shortpass');
      await tester.pump();
      expect(_submitButton(tester).onPressed, isNull);

      // And so does a repeat that disagrees.
      await tester.enterText(find.byKey(_newPasswordField), 'Longpass123');
      await tester.enterText(find.byKey(_repeatField), 'Longpass456');
      await tester.pump();
      expect(_submitButton(tester).onPressed, isNull);

      await tester.enterText(find.byKey(_repeatField), 'Longpass123');
      await tester.pump();
      expect(_submitButton(tester).onPressed, isNotNull);

      await tester.tap(find.byKey(_submit));
      await tester.pumpAndSettle();
      expect(server.resets, 1);
      expect(server.resetEmail, 'user@example.com');
      expect(server.resetCode, '123456');
      expect(server.resetPassword, 'Longpass123');
      expect(find.byKey(_done), findsOneWidget);

      await tester.tap(find.byKey(_done));
      await tester.pumpAndSettle();
      expect(find.text('Hub route'), findsOneWidget);
    });

    testWidgets('the code field only accepts digits', (tester) async {
      final _Server server = _Server();
      await _open(tester, server, _Auth(email: 'user@example.com'));

      await tester.tap(find.byKey(_sendCode));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(_codeField), '12a4b6');
      await tester.pump();
      // The letters never make it into the field.
      expect(
        tester.widget<TextField>(find.byKey(_codeField)).controller!.text,
        '1246',
      );
    });

    testWidgets('a wrong code is explained under the fields', (tester) async {
      final _Server server = _Server()
        ..resetFailure = const PasswordResetException(
          PasswordResetFailureKind.invalidCode,
        );
      await _open(tester, server, _Auth(email: 'user@example.com'));

      await tester.tap(find.byKey(_sendCode));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(_codeField), '000000');
      await tester.enterText(find.byKey(_newPasswordField), 'Longpass123');
      await tester.enterText(find.byKey(_repeatField), 'Longpass123');
      await tester.pump();

      await tester.tap(find.byKey(_submit));
      await tester.pumpAndSettle();

      expect(server.resets, 1);
      expect(find.textContaining('Код неверный или устарел'), findsOneWidget);
      // The form stays for another attempt.
      expect(find.byKey(_codeField), findsOneWidget);
      expect(find.byKey(_done), findsNothing);
    });

    testWidgets('a weak password from the server is explained', (tester) async {
      final _Server server = _Server()
        ..resetFailure = const PasswordResetException(
          PasswordResetFailureKind.weakPassword,
        );
      await _open(tester, server, _Auth(email: 'user@example.com'));

      await tester.tap(find.byKey(_sendCode));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(_codeField), '123456');
      await tester.enterText(find.byKey(_newPasswordField), 'Longpass123');
      await tester.enterText(find.byKey(_repeatField), 'Longpass123');
      await tester.pump();

      await tester.tap(find.byKey(_submit));
      await tester.pumpAndSettle();

      expect(find.textContaining('Пароль не подходит'), findsOneWidget);
      expect(find.byKey(_done), findsNothing);
    });

    testWidgets('rate limiting on the request is explained, no form', (
      tester,
    ) async {
      final _Server server = _Server()
        ..requestFailure = const PasswordResetException(
          PasswordResetFailureKind.tooManyRequests,
        );
      await _open(tester, server, _Auth(email: 'user@example.com'));

      await tester.tap(find.byKey(_sendCode));
      await tester.pumpAndSettle();

      expect(server.requests, 1);
      expect(find.textContaining('Слишком много попыток'), findsOneWidget);
      expect(find.byKey(_codeField), findsNothing);
    });

    testWidgets('a code can be sent again from the form', (tester) async {
      final _Server server = _Server();
      await _open(tester, server, _Auth(email: 'user@example.com'));

      await tester.tap(find.byKey(_sendCode));
      await tester.pumpAndSettle();
      expect(server.requests, 1);

      // The letter may be late and the code expires: a new request replaces
      // the old one, as the intro says.
      await tester.tap(find.byKey(_resend));
      await tester.pumpAndSettle();
      expect(server.requests, 2);
      expect(find.byKey(_codeField), findsOneWidget);
    });

    testWidgets('a rejected request never blames a code that was not typed', (
      tester,
    ) async {
      final _Server server = _Server()
        ..requestFailure = const PasswordResetException(
          PasswordResetFailureKind.invalidCode,
        );
      await _open(tester, server, _Auth(email: 'user@example.com'));

      await tester.tap(find.byKey(_sendCode));
      await tester.pumpAndSettle();

      expect(find.textContaining('Код неверный или устарел'), findsNothing);
      expect(find.textContaining('Не получилось'), findsOneWidget);
      expect(find.byKey(_codeField), findsNothing);
    });

    testWidgets('an arriving profile is waited for, not called email-less', (
      tester,
    ) async {
      final _Server server = _Server();
      await _open(tester, server, _NoProfileAuth(), settle: false);

      expect(find.byType(AppLoadingIndicator), findsOneWidget);
      expect(find.byKey(_sendCode), findsNothing);
      expect(find.textContaining('Почта не указана'), findsNothing);
    });

    testWidgets('no email: explanation and a portal link, no send button', (
      tester,
    ) async {
      final _Server server = _Server();
      await _open(tester, server, _Auth(email: null));

      expect(find.textContaining('Почта не указана'), findsOneWidget);
      expect(find.byKey(_sendCode), findsNothing);
      expect(find.byKey(_openPortal), findsOneWidget);
      expect(server.requests, 0);
    });
  });
}
