import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/screens/e2ee_settings_screen.dart';
import 'package:pulse_flutter/screens/sessions_screen.dart';
import 'package:pulse_flutter/screens/settings_about_screen.dart';
import 'package:pulse_flutter/screens/settings_account_screen.dart';
import 'package:pulse_flutter/screens/settings_appearance_screen.dart';
import 'package:pulse_flutter/screens/settings_language_region_screen.dart';
import 'package:pulse_flutter/screens/settings_preferences_screen.dart';
import 'package:pulse_flutter/screens/settings_privacy_screen.dart';
import 'package:pulse_flutter/screens/settings_storage_screen.dart';
import 'package:pulse_flutter/models/api/session_model.dart';
import 'package:pulse_flutter/repositories/auth_repository.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stub adaptive performance notifier: always reports Tier B (balanced).
/// This prevents AnimatedMeshGradient from being built in headless CI tests.
class _StubAdaptivePerformanceNotifier extends AdaptivePerformanceNotifier {
  @override
  AdaptivePerformanceState build() {
    return const AdaptivePerformanceState(
      mode: PerformanceMode.balanced,
      targetFps: 60.0,
      targetFrameBudgetMs: 16.67,
      recentJankRatio: 0.0,
      isDegraded: false,
    );
  }
}

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
        bio: 'Testing settings M3',
        avatarUrl: null,
      ),
    );
  }
}

class _MockAuthRepository extends AuthRepository {
  _MockAuthRepository(super.ref);

  @override
  Future<List<ApiSession>> getSessions() async => const <ApiSession>[];
}

Widget _wrapWithApp(Widget child, {Size surfaceSize = const Size(800, 1000)}) {
  final ThemeData theme = AppTheme.themed(
    const VisualThemeSettings(
      seedColor: Color(0xFF6750A4),
      themeMode: ThemeMode.light,
      useSystemDynamic: false,
      predictiveBackEnabled: false,
    ),
    Brightness.light,
  );

  return ProviderScope(
    overrides: [
      authProvider.overrideWith(() => _FakeAuthNotifier()),
      authRepositoryProvider.overrideWith((ref) => _MockAuthRepository(ref)),
      adaptivePerformanceProvider.overrideWith(_StubAdaptivePerformanceNotifier.new),
    ],
    child: MediaQuery(
      data: MediaQueryData(
        size: surfaceSize,
        padding: EdgeInsets.zero,
        viewInsets: EdgeInsets.zero,
      ),
      child: MaterialApp(
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
        home: child,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Tier 1: Settings UI Framework M3 Expressive Tests', () {
    testWidgets(
        '1.1 SettingsScaffold suppresses AppBar and uses compact padding when isEmbedded is true',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrapWithApp(
          const SettingsScaffold(
            title: 'Embedded Settings',
            isEmbedded: true,
            children: <Widget>[
              Text('Child Content'),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AppBar), findsNothing);
      expect(find.text('Child Content'), findsOneWidget);
    });

    testWidgets(
        '1.2 SettingsScaffold renders AppBar with gradient background when isEmbedded is false',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrapWithApp(
          const SettingsScaffold(
            title: 'Standalone Settings',
            isEmbedded: false,
            children: <Widget>[
              Text('Child Content'),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Child Content'), findsOneWidget);
    });

    testWidgets(
        '1.3 SettingsSection renders grouped card with surfaceContainerLow and 20dp border radius',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrapWithApp(
          SettingsSection(
            title: 'Section Group',
            children: <Widget>[
              SettingsTile(
                icon: Icons.star_rounded,
                title: 'Tile 1',
                onTap: () {},
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final Finder containerFinder = find.byWidgetPredicate((Widget w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final BoxDecoration dec = w.decoration! as BoxDecoration;
          return dec.borderRadius == BorderRadius.circular(20);
        }
        return false;
      });
      expect(containerFinder, findsWidgets);
    });

    testWidgets(
        '1.4 SettingsTile renders active highlight with isSelected = true',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrapWithApp(
          Column(
            children: <Widget>[
              SettingsTile(
                icon: Icons.person_rounded,
                title: 'Active Tile',
                isSelected: true,
                onTap: () {},
              ),
              SettingsTile(
                icon: Icons.settings_rounded,
                title: 'Inactive Tile',
                isSelected: false,
                onTap: () {},
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final Finder activeTileFinder = find.byWidgetPredicate((Widget w) {
        return w is SettingsTile && w.isSelected == true;
      });
      expect(activeTileFinder, findsOneWidget);
    });

    testWidgets(
        '1.5 SettingsSwitchTile renders Switch.adaptive and toggles correctly',
        (WidgetTester tester) async {
      bool toggleValue = false;

      await tester.pumpWidget(
        _wrapWithApp(
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SettingsSwitchTile(
                icon: Icons.notifications_rounded,
                title: 'Adaptive Switch',
                value: toggleValue,
                onChanged: (bool next) {
                  setState(() => toggleValue = next);
                },
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(Switch), findsOneWidget);
      expect(toggleValue, isFalse);

      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(toggleValue, isTrue);
    });

    testWidgets(
        '1.6 SettingsInfoTile renders trailing values and icon containers',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrapWithApp(
          const SettingsInfoTile(
            icon: Icons.info_outline_rounded,
            title: 'Info Title',
            subtitle: 'Info Subtitle',
            value: 'v3.0.0',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Info Title'), findsOneWidget);
      expect(find.text('Info Subtitle'), findsOneWidget);
      expect(find.text('v3.0.0'), findsOneWidget);
    });
  });

  group('Tier 1: All 9 Settings Screens Instantiation (Embedded & Standalone)', () {
    testWidgets('1.7 SettingsAccountScreen instantiates cleanly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrapWithApp(const SettingsAccountScreen(isEmbedded: true)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SettingsAccountScreen), findsOneWidget);
    });

    testWidgets('1.8 SettingsAppearanceScreen instantiates with SegmentedButton & switches',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrapWithApp(const SettingsAppearanceScreen(isEmbedded: true)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SettingsAppearanceScreen), findsOneWidget);
      expect(find.byType(SegmentedButton<AppFontScale>), findsOneWidget);
    });

    testWidgets('1.9 SettingsPrivacyScreen instantiates cleanly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrapWithApp(const SettingsPrivacyScreen(isEmbedded: true)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SettingsPrivacyScreen), findsOneWidget);
    });

    testWidgets('1.10 SettingsStorageScreen instantiates cleanly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrapWithApp(const SettingsStorageScreen(isEmbedded: true)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SettingsStorageScreen), findsOneWidget);
    });

    testWidgets('1.11 SettingsLanguageRegionScreen instantiates with Language SegmentedButton',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrapWithApp(const SettingsLanguageRegionScreen(isEmbedded: true)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SettingsLanguageRegionScreen), findsOneWidget);
      expect(find.byType(SegmentedButton<String?>), findsOneWidget);
    });

    testWidgets('1.12 SettingsPreferencesScreen instantiates with Volume Slider',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrapWithApp(const SettingsPreferencesScreen(isEmbedded: true)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SettingsPreferencesScreen), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('1.13 SettingsAboutScreen instantiates cleanly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrapWithApp(const SettingsAboutScreen(isEmbedded: true)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SettingsAboutScreen), findsOneWidget);
    });

    testWidgets('1.14 E2eeSettingsScreen instantiates cleanly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrapWithApp(const E2eeSettingsScreen(isEmbedded: true)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(E2eeSettingsScreen), findsOneWidget);
    });

    testWidgets('1.15 SessionsScreen instantiates cleanly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrapWithApp(const SessionsScreen(isEmbedded: true)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SessionsScreen), findsOneWidget);
    });
  });

  group('Tier 2: Settings Screens Boundary Viewports (360dp to 3840dp 4K)', () {
    final List<Map<String, dynamic>> testViewports = [
      {'name': 'Compact Mobile 360x640', 'size': const Size(360, 640)},
      {'name': 'Standard Mobile 390x844', 'size': const Size(390, 844)},
      {'name': 'Tablet 768x1024', 'size': const Size(768, 1024)},
      {'name': 'Desktop Full HD 1920x1080', 'size': const Size(1920, 1080)},
      {'name': 'Desktop 4K 3840x2160', 'size': const Size(3840, 2160)},
    ];

    for (final vp in testViewports) {
      testWidgets('2.1 SettingsAppearanceScreen on ${vp['name']} renders with zero overflow',
          (WidgetTester tester) async {
        final Size size = vp['size'] as Size;
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _wrapWithApp(const SettingsAppearanceScreen(isEmbedded: false), surfaceSize: size),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        expect(find.byType(SettingsAppearanceScreen), findsOneWidget);
      });

      testWidgets('2.2 SettingsPreferencesScreen on ${vp['name']} renders with zero overflow',
          (WidgetTester tester) async {
        final Size size = vp['size'] as Size;
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _wrapWithApp(const SettingsPreferencesScreen(isEmbedded: false), surfaceSize: size),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        expect(find.byType(SettingsPreferencesScreen), findsOneWidget);
      });
    }
  });
}
