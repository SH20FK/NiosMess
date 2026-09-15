import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/screens/onboarding_screen.dart';
import 'package:pulse_flutter/widgets/app_logo_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthNotifier extends AuthNotifier {
  MockAuthNotifier({this.authenticated = false});

  final bool authenticated;

  @override
  AuthState build() {
    return AuthState(
      hydrated: true,
      busy: false,
      session: authenticated
          ? const AuthSession(
              accessToken: 'mock_token',
              userId: 1,
              username: 'testuser',
              displayName: 'Test User',
            )
          : null,
      pendingIdentifier: null,
      error: null,
      profile: authenticated
          ? const ApiProfile(
              id: 1,
              username: 'testuser',
              displayName: 'Test User',
              bio: 'test bio',
            )
          : null,
    );
  }

  @override
  Future<void> refreshProfile() async {}
}

Widget _buildTestApp({
  required String initialLocation,
  List<dynamic> overrides = const [],
}) {
  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/onboarding',
        builder: (BuildContext context, GoRouterState state) =>
            const OnboardingScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('Register Target')),
      ),
      GoRoute(
        path: '/login',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('Login Target')),
      ),
      GoRoute(
        path: '/main/chats',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('Chats Target')),
      ),
    ],
  );

  return ProviderScope(
    overrides: overrides.cast(),
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

Future<void> _pumpFrames(WidgetTester tester, [int count = 6]) async {
  for (int i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Unified Onboarding Screen (4 slides with Language & Timezone)', () {
    testWidgets('Renders Hero header with AppLogoMark, indicators and navigation buttons', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(initialLocation: '/onboarding'),
      );
      await _pumpFrames(tester, 4);

      // Hero brand logo
      expect(find.byType(AppLogoMark), findsOneWidget);
      expect(find.text('NiosMess'), findsOneWidget);

      // Slide 1 Content
      expect(find.text('Fast calls with less friction'), findsOneWidget);

      // Indicators and Buttons
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('Swiping carousel slides advances through slides to region and language setup', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(initialLocation: '/onboarding'),
      );
      await _pumpFrames(tester, 4);

      expect(find.text('Fast calls with less friction'), findsOneWidget);

      // Drag to slide 2 (Chats)
      await tester.drag(find.byType(PageView), const Offset(-450, 0));
      await _pumpFrames(tester, 12);
      expect(find.text('Organized conversations'), findsOneWidget);

      // Drag to slide 3 (Speed)
      await tester.drag(find.byType(PageView), const Offset(-450, 0));
      await _pumpFrames(tester, 12);
      expect(find.text('Designed for daily rhythm'), findsOneWidget);

      // Drag to slide 4 (Language & Timezone setup)
      await tester.drag(find.byType(PageView), const Offset(-450, 0));
      await _pumpFrames(tester, 12);
      expect(find.text('Choose your language'), findsOneWidget);
      expect(find.text('Start messaging'), findsOneWidget);
    });

    testWidgets('Tapping Skip jumps directly to slide 4 (Language & Timezone)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(initialLocation: '/onboarding'),
      );
      await _pumpFrames(tester, 4);

      expect(find.text('Fast calls with less friction'), findsOneWidget);

      // Tap Skip on Slide 0
      await tester.tap(find.widgetWithText(TextButton, 'Skip'));
      await _pumpFrames(tester, 8);

      expect(find.text('Choose your language'), findsOneWidget);
      expect(find.text('Start messaging'), findsOneWidget);
    });

    testWidgets('Completing onboarding on slide 4 navigates to /login', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(initialLocation: '/onboarding'),
      );
      await _pumpFrames(tester, 4);

      // Skip to slide 4
      await tester.tap(find.widgetWithText(TextButton, 'Skip'));
      await _pumpFrames(tester, 8);

      expect(find.text('Login Target'), findsNothing);

      // Tap Start messaging
      await tester.tap(find.widgetWithText(FilledButton, 'Start messaging'));
      await _pumpFrames(tester, 6);

      expect(find.text('Login Target'), findsOneWidget);
    });

    testWidgets('When already authenticated, completing onboarding routes to /main/chats', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          initialLocation: '/onboarding',
          overrides: [
            authProvider.overrideWith(() => MockAuthNotifier(authenticated: true)),
          ],
        ),
      );
      await _pumpFrames(tester, 4);

      // Skip to slide 4
      await tester.tap(find.widgetWithText(TextButton, 'Skip'));
      await _pumpFrames(tester, 8);

      expect(find.text('Chats Target'), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'Start messaging'));
      await _pumpFrames(tester, 6);

      expect(find.text('Chats Target'), findsOneWidget);
    });
  });
}
