import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/screens/onboarding_screen.dart';
import 'package:pulse_flutter/screens/setup_onboarding_screen.dart';
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
        path: '/setup',
        builder: (BuildContext context, GoRouterState state) =>
            const SetupOnboardingScreen(),
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
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
      ),
    ),
  );
}

Future<void> _pumpFrames(WidgetTester tester, [int count = 6]) async {
  for (int i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Milestone 1: Onboarding Carousel Screen (R1)', () {
    testWidgets('Renders hero logo, brand name, slide 1 content and 28dp pill action buttons', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(initialLocation: '/onboarding'),
      );
      await _pumpFrames(tester, 4);

      // Brand Logo & Header
      expect(find.byType(AppLogoMark), findsOneWidget);
      expect(find.text('NiosMess'), findsOneWidget);
      expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);

      // Slide 1 title & description
      expect(find.text('Fast calls with less friction'), findsOneWidget);

      // Slide indicator pills
      final Finder animatedContainers = find.byType(AnimatedContainer);
      expect(animatedContainers, findsWidgets);

      // Buttons
      expect(find.text('Get started'), findsOneWidget);

      // Geometry check: 28dp radius on action button
      final Finder primaryButtonFinder = find.widgetWithText(FilledButton, 'Get started');
      expect(primaryButtonFinder, findsOneWidget);
      final FilledButton primaryButton = tester.widget<FilledButton>(primaryButtonFinder);
      final RoundedRectangleBorder border = primaryButton.style?.shape?.resolve(const <WidgetState>{}) as RoundedRectangleBorder;
      expect((border.borderRadius as BorderRadius).topLeft.x, equals(28.0));
    });

    testWidgets('Swiping carousel slides advances to slide 2 and slide 3', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(initialLocation: '/onboarding'),
      );
      await _pumpFrames(tester, 4);

      expect(find.text('Fast calls with less friction'), findsOneWidget);

      // Drag to slide 2
      await tester.drag(find.byType(PageView), const Offset(-450, 0));
      await _pumpFrames(tester, 6);

      expect(find.text('Organized conversations'), findsOneWidget);

      // Drag to slide 3
      await tester.drag(find.byType(PageView), const Offset(-450, 0));
      await _pumpFrames(tester, 6);

      expect(find.text('Designed for daily rhythm'), findsOneWidget);
    });

    testWidgets('Tapping Get started completes onboarding in session and navigates to /login', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(initialLocation: '/onboarding'),
      );
      await _pumpFrames(tester, 4);

      expect(find.text('Login Target'), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'Get started'));
      await _pumpFrames(tester, 6);

      expect(find.text('Login Target'), findsOneWidget);
    });

    testWidgets('When already authenticated, action buttons route to /main/chats', (
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

      expect(find.text('Chats Target'), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'Get started'));
      await _pumpFrames(tester, 6);

      expect(find.text('Chats Target'), findsOneWidget);
    });
  });

  group('Milestone 1: Setup Wizard Screen (R1)', () {
    testWidgets('Renders Step 0 Welcome step with waving hand hero badge', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(initialLocation: '/setup'),
      );
      await _pumpFrames(tester, 4);

      // Welcome hero badge
      expect(find.byIcon(Icons.waving_hand_rounded), findsOneWidget);
      expect(find.text('Nice to meet you!'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('Advances from Step 0 to Step 1 and changes language', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(initialLocation: '/setup'),
      );
      await _pumpFrames(tester, 4);

      expect(find.text('Nice to meet you!'), findsOneWidget);

      // Tap Continue to go to Step 1
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await _pumpFrames(tester, 8);

      expect(find.text('Choose your language'), findsOneWidget);
      expect(find.byIcon(Icons.language_rounded), findsOneWidget);
      expect(find.text('Russian'), findsOneWidget);

      // Select Russian
      await tester.tap(find.text('Russian'));
      await _pumpFrames(tester, 4);

      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('Advances from Step 1 to Step 2 Timezone with live clock', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(initialLocation: '/setup'),
      );
      await _pumpFrames(tester, 4);

      // Step 0 -> Step 1
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await _pumpFrames(tester, 8);

      // Step 1 -> Step 2
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await _pumpFrames(tester, 8);

      expect(find.text('Your time zone'), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
      expect(find.text('Automatic'), findsOneWidget);
      expect(find.text('Manual'), findsOneWidget);
      expect(find.text('Current time in app'), findsOneWidget);
      expect(find.text('Start messaging'), findsOneWidget);
    });

    testWidgets('Tapping Start messaging on Step 2 completes onboarding and routes to /main/chats', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(initialLocation: '/setup'),
      );
      await _pumpFrames(tester, 4);

      // Step 0 -> Step 1 -> Step 2
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await _pumpFrames(tester, 8);
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await _pumpFrames(tester, 8);

      expect(find.text('Chats Target'), findsNothing);

      // Step 2 finish
      await tester.tap(find.widgetWithText(FilledButton, 'Start messaging'));
      await _pumpFrames(tester, 8);

      expect(find.text('Chats Target'), findsOneWidget);
    });

    testWidgets('Tapping Skip on Step 0 completes onboarding and navigates to /main/chats', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(initialLocation: '/setup'),
      );
      await _pumpFrames(tester, 4);

      expect(find.text('Chats Target'), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, 'Skip'));
      await _pumpFrames(tester, 8);

      expect(find.text('Chats Target'), findsOneWidget);
    });
  });
}
