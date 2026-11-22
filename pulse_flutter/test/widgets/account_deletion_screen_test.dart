import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/features/account_deletion/data/account_deletion_repository.dart';
import 'package:pulse_flutter/features/account_deletion/domain/account_deletion_status.dart';
import 'package:pulse_flutter/features/account_deletion/presentation/account_deletion_screen.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the fake server knows and what the screen asked it to do.
class _Server {
  _Server({this.pending = false});

  bool pending;
  int requests = 0;
  int cancels = 0;
  final List<String> codes = <String>[];
  ApiException? requestFailure;
  ApiException? confirmFailure;

  AccountDeletionStatus get status => AccountDeletionStatus(
    isPending: pending,
    graceDays: 31,
    scheduledAt: pending ? DateTime.utc(2026, 12, 23, 10) : null,
  );
}

class _Repo extends AccountDeletionRepository {
  _Repo(super.ref, this.server);
  final _Server server;

  @override
  Future<AccountDeletionStatus> status() async => server.status;

  @override
  Future<void> requestCode() async {
    server.requests++;
    final ApiException? failure = server.requestFailure;
    if (failure != null) throw failure;
  }

  @override
  Future<AccountDeletionStatus> confirm(String code) async {
    server.codes.add(code);
    final ApiException? failure = server.confirmFailure;
    if (failure != null) throw failure;
    server.pending = true;
    return server.status;
  }

  @override
  Future<void> cancel() async {
    server.cancels++;
    server.pending = false;
  }
}

class _Auth extends AuthNotifier {
  int logouts = 0;
  int refreshes = 0;

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

  @override
  Future<void> logout({bool eraseSecretData = true}) async {
    logouts++;
    state = const AuthState.initial().copyWith(hydrated: true);
  }

  @override
  Future<void> refreshProfile() async {
    refreshes++;
  }
}

ApiException _refusal(String message) =>
    ApiException(statusCode: 400, message: message);

const ValueKey<String> _sendCode = ValueKey<String>(
  'account-deletion-send-code',
);
const ValueKey<String> _codeField = ValueKey<String>('account-deletion-code');
const ValueKey<String> _confirm = ValueKey<String>('account-deletion-confirm');
const ValueKey<String> _cancel = ValueKey<String>('account-deletion-cancel');

Future<void> _open(WidgetTester tester, _Server server, _Auth auth) async {
  // Tall enough to keep every control on screen without scrolling.
  tester.view.physicalSize = const Size(600, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final GoRouter router = GoRouter(
    initialLocation: '/delete',
    routes: <RouteBase>[
      GoRoute(
        path: '/delete',
        builder: (_, _) => const AccountDeletionScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const Scaffold(body: Text('Login route')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(() => auth),
        accountDeletionRepositoryProvider.overrideWith(
          (Ref ref) => _Repo(ref, server),
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
  await tester.pumpAndSettle();
}

FilledButton _confirmButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(_confirm));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Account deletion screen', () {
    testWidgets('code, confirmation dialog, then sign-out', (tester) async {
      final _Server server = _Server();
      final _Auth auth = _Auth();
      await _open(tester, server, auth);

      // Nothing can be confirmed before a code was requested.
      expect(find.byKey(_codeField), findsNothing);
      await tester.tap(find.byKey(_sendCode));
      await tester.pumpAndSettle();
      expect(server.requests, 1);
      expect(find.byKey(_codeField), findsOneWidget);
      expect(_confirmButton(tester).onPressed, isNull);

      await tester.enterText(find.byKey(_codeField), '12345');
      await tester.pump();
      expect(_confirmButton(tester).onPressed, isNull);
      await tester.enterText(find.byKey(_codeField), '123456');
      await tester.pump();
      expect(_confirmButton(tester).onPressed, isNotNull);

      await tester.tap(find.byKey(_confirm));
      await tester.pumpAndSettle();
      expect(find.text('Удалить аккаунт?'), findsOneWidget);
      expect(find.textContaining('Через 31 день'), findsOneWidget);
      // The dialog is the last word: nothing reaches the server before it.
      expect(server.codes, isEmpty);

      await tester.tap(find.text('Удалить аккаунт').last);
      await tester.pumpAndSettle();
      expect(server.codes, <String>['123456']);
      expect(auth.logouts, 1);
      expect(find.text('Login route'), findsOneWidget);
    });

    testWidgets('declining the dialog sends nothing', (tester) async {
      final _Server server = _Server();
      final _Auth auth = _Auth();
      await _open(tester, server, auth);

      await tester.tap(find.byKey(_sendCode));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(_codeField), '123456');
      await tester.pump();
      await tester.tap(find.byKey(_confirm));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();

      expect(server.codes, isEmpty);
      expect(auth.logouts, 0);
      expect(find.byKey(_codeField), findsOneWidget);
    });

    testWidgets('a wrong code keeps the user signed in', (tester) async {
      final _Server server = _Server()
        ..confirmFailure = _refusal('Invalid or expired code');
      final _Auth auth = _Auth();
      await _open(tester, server, auth);

      await tester.tap(find.byKey(_sendCode));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(_codeField), '000000');
      await tester.pump();
      await tester.tap(find.byKey(_confirm));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Удалить аккаунт').last);
      await tester.pumpAndSettle();

      expect(server.codes, <String>['000000']);
      expect(find.textContaining('Код неверный или устарел'), findsOneWidget);
      expect(auth.logouts, 0);
      expect(find.text('Login route'), findsNothing);
      expect(find.byKey(_codeField), findsOneWidget);
    });

    testWidgets('an active Nios+ is explained in the app language', (
      tester,
    ) async {
      final _Server server = _Server()
        ..requestFailure = _refusal(
          'Cancel your Nios+ subscription before deleting the account',
        );
      final _Auth auth = _Auth();
      await _open(tester, server, auth);

      await tester.tap(find.byKey(_sendCode));
      await tester.pumpAndSettle();

      expect(server.requests, 1);
      expect(
        find.textContaining('Сначала отмените подписку Nios+'),
        findsOneWidget,
      );
      expect(find.textContaining('Cancel your Nios+'), findsNothing);
      expect(find.byKey(_codeField), findsNothing);
    });

    testWidgets('a scheduled deletion shows its date and can be cancelled', (
      tester,
    ) async {
      final _Server server = _Server(pending: true);
      final _Auth auth = _Auth();
      await _open(tester, server, auth);

      expect(find.textContaining('23 декабря 2026'), findsOneWidget);
      expect(find.byKey(_sendCode), findsNothing);

      await tester.tap(find.byKey(_cancel));
      await tester.pumpAndSettle();

      expect(server.cancels, 1);
      expect(auth.refreshes, 1);
      expect(auth.logouts, 0);
      expect(find.byKey(_cancel), findsNothing);
      expect(find.byKey(_sendCode), findsOneWidget);
    });
  });
}
