import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/settings_navigation_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/screens/profile_screen.dart';
import 'package:pulse_flutter/screens/settings_account_screen.dart';
import 'package:pulse_flutter/screens/settings_appearance_screen.dart';
import 'package:pulse_flutter/screens/settings_privacy_screen.dart';
import 'package:pulse_flutter/screens/settings_storage_screen.dart';
import 'package:pulse_flutter/screens/settings_preferences_screen.dart';
import 'package:pulse_flutter/screens/settings_language_region_screen.dart';
import 'package:pulse_flutter/screens/settings_about_screen.dart';
import 'package:pulse_flutter/screens/e2ee_settings_screen.dart';
import 'package:pulse_flutter/screens/sessions_screen.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return const AuthState(
      hydrated: true,
      busy: false,
      session: AuthSession(
        accessToken: 'fake_jwt_token',
        userId: 1,
        username: 'alex_test',
        displayName: 'Alex Test',
        niosId: 'nios_123',
      ),
      pendingIdentifier: null,
      error: null,
      profile: ApiProfile(
        id: 1,
        username: 'alex_test',
        displayName: 'Alex Test',
        bio: 'Testing Master-Detail settings layout',
        avatarUrl: null,
      ),
    );
  }
}

Widget _buildProfileScreenTestHarness({
  required Size surfaceSize,
}) {
  final ThemeData theme = AppTheme.themed(
    const VisualThemeSettings(
      seedColor: Color(0xFF6750A4),
      themeMode: ThemeMode.light,
      useSystemDynamic: false,
      predictiveBackEnabled: false,
    ),
    Brightness.light,
  );

  final GoRouter router = GoRouter(
    initialLocation: '/main/profile',
    routes: <RouteBase>[
      GoRoute(
        path: '/main/profile',
        builder: (BuildContext context, GoRouterState state) =>
            const ProfileScreen(),
      ),
      GoRoute(
        path: '/settings/account',
        builder: (BuildContext context, GoRouterState state) =>
            const SettingsAccountScreen(),
      ),
      GoRoute(
        path: '/settings/appearance',
        builder: (BuildContext context, GoRouterState state) =>
            const SettingsAppearanceScreen(),
      ),
      GoRoute(
        path: '/settings/privacy',
        builder: (BuildContext context, GoRouterState state) =>
            const SettingsPrivacyScreen(),
      ),
      GoRoute(
        path: '/settings/storage',
        builder: (BuildContext context, GoRouterState state) =>
            const SettingsStorageScreen(),
      ),
      GoRoute(
        path: '/settings/preferences',
        builder: (BuildContext context, GoRouterState state) =>
            const SettingsPreferencesScreen(),
      ),
      GoRoute(
        path: '/settings/language-region',
        builder: (BuildContext context, GoRouterState state) =>
            const SettingsLanguageRegionScreen(),
      ),
      GoRoute(
        path: '/settings/about',
        builder: (BuildContext context, GoRouterState state) =>
            const SettingsAboutScreen(),
      ),
      GoRoute(
        path: '/settings/e2ee',
        builder: (BuildContext context, GoRouterState state) =>
            const E2eeSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/sessions',
        builder: (BuildContext context, GoRouterState state) =>
            const SessionsScreen(),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      authProvider.overrideWith(() => _FakeAuthNotifier()),
    ],
    child: MediaQuery(
      data: MediaQueryData(
        size: surfaceSize,
        padding: EdgeInsets.zero,
        viewInsets: EdgeInsets.zero,
      ),
      child: MaterialApp.router(
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
        routerConfig: router,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Tier 1: SettingsNavigationProvider Unit Tests', () {
    test('1.1 desktopSelectedSettingsSectionProvider defaults to account', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(desktopSelectedSettingsSectionProvider),
        equals(SettingsSectionId.account),
      );
    });

    test('1.2 setSelectedSection updates state across all sections', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      for (final section in SettingsSectionId.values) {
        container
            .read(desktopSelectedSettingsSectionProvider.notifier)
            .setSelectedSection(section);

        expect(
          container.read(desktopSelectedSettingsSectionProvider),
          equals(section),
        );
      }
    });
  });

  group('Tier 1: ProfileScreen Desktop Master-Detail Tests (>=760dp)', () {
    const Size desktopSize = Size(1024, 800);

    testWidgets(
        '1.3 Renders 2-pane Master-Detail layout on wide viewports with account screen embedded',
        (WidgetTester tester) async {
      tester.view.physicalSize = desktopSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _buildProfileScreenTestHarness(surfaceSize: desktopSize),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Master pane elements
      expect(find.text('Alex Test'), findsWidgets);
      expect(find.text('@alex_test'), findsWidgets);
      expect(find.text('Testing Master-Detail settings layout'), findsWidgets);

      // Verify master list tiles exist
      expect(find.byType(SettingsSection), findsWidgets);
      expect(find.byType(SettingsTile), findsWidgets);

      // Verify VerticalDivider exists between panes
      expect(find.byType(VerticalDivider), findsOneWidget);

      // Default embedded detail pane is SettingsAccountScreen
      expect(find.byType(SettingsAccountScreen), findsOneWidget);
      final SettingsAccountScreen accountScreen =
          tester.widget<SettingsAccountScreen>(
        find.byType(SettingsAccountScreen),
      );
      expect(accountScreen.isEmbedded, isTrue);
    });

    testWidgets(
        '1.4 Switching master pane section updates detail pane to target sub-screen in-place',
        (WidgetTester tester) async {
      tester.view.physicalSize = desktopSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _buildProfileScreenTestHarness(surfaceSize: desktopSize),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Initially on Account
      expect(find.byType(SettingsAccountScreen), findsOneWidget);
      expect(find.byType(SettingsAppearanceScreen), findsNothing);

      // Find and tap Appearance section in master pane
      final Finder appearanceTile = find.widgetWithText(
        SettingsTile,
        'Внешний вид',
      );
      expect(appearanceTile, findsWidgets);
      await tester.tap(appearanceTile.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Detail pane now renders SettingsAppearanceScreen with isEmbedded: true
      expect(find.byType(SettingsAppearanceScreen), findsOneWidget);
      final SettingsAppearanceScreen appearanceScreen =
          tester.widget<SettingsAppearanceScreen>(
        find.byType(SettingsAppearanceScreen),
      );
      expect(appearanceScreen.isEmbedded, isTrue);
    });

    testWidgets(
        '1.5 Selected master tile is styled with isSelected = true',
        (WidgetTester tester) async {
      tester.view.physicalSize = desktopSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _buildProfileScreenTestHarness(surfaceSize: desktopSize),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final Finder accountTiles = find.byWidgetPredicate(
        (Widget widget) => widget is SettingsTile && widget.isSelected == true,
      );
      expect(accountTiles, findsOneWidget);
      final SettingsTile selectedTile =
          tester.widget<SettingsTile>(accountTiles);
      expect(selectedTile.title, equals('Аккаунт'));
    });
  });

  group('Tier 1: ProfileScreen Mobile Fallback Tests (<760dp)', () {
    const Size mobileSize = Size(400, 800);

    testWidgets('1.6 Renders single-column stacked layout without VerticalDivider',
        (WidgetTester tester) async {
      tester.view.physicalSize = mobileSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _buildProfileScreenTestHarness(surfaceSize: mobileSize),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Mobile view uses CustomScrollView
      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(find.byType(VerticalDivider), findsNothing);

      // User info present in mobile header
      expect(find.text('Alex Test'), findsWidgets);
      expect(find.text('@alex_test'), findsWidgets);
    });
  });

  group('Tier 2: Master-Detail Boundary Viewports (360dp to 3840dp 4K)', () {
    final List<Map<String, dynamic>> testViewports = [
      {'name': 'Compact Mobile 360x640', 'size': const Size(360, 640), 'isWide': false},
      {'name': 'Standard Mobile 390x844', 'size': const Size(390, 844), 'isWide': false},
      {'name': 'Breakpoint Threshold 760x1024', 'size': const Size(760, 1024), 'isWide': true},
      {'name': 'Laptop 1366x768', 'size': const Size(1366, 768), 'isWide': true},
      {'name': 'Desktop Full HD 1920x1080', 'size': const Size(1920, 1080), 'isWide': true},
      {'name': 'Desktop 4K 3840x2160', 'size': const Size(3840, 2160), 'isWide': true},
    ];

    for (final vp in testViewports) {
      testWidgets('2.1 Master-detail layout on ${vp['name']} renders without overflow',
          (WidgetTester tester) async {
        final Size size = vp['size'] as Size;
        final bool isWide = vp['isWide'] as bool;

        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _buildProfileScreenTestHarness(surfaceSize: size),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        if (isWide) {
          expect(find.byType(VerticalDivider), findsOneWidget);
          expect(find.byType(SettingsAccountScreen), findsOneWidget);
        } else {
          expect(find.byType(VerticalDivider), findsNothing);
          expect(find.byType(CustomScrollView), findsOneWidget);
        }
      });
    }
  });
}
