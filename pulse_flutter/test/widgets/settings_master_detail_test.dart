import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/platform/client_capabilities.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/settings_navigation_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/screens/settings_account_screen.dart';
import 'package:pulse_flutter/screens/settings_appearance_screen.dart';
import 'package:pulse_flutter/screens/settings_wallpaper_screen.dart';
import 'package:pulse_flutter/screens/settings_privacy_screen.dart';
import 'package:pulse_flutter/screens/settings_storage_screen.dart';
import 'package:pulse_flutter/screens/settings_notifications_screen.dart';
import 'package:pulse_flutter/screens/settings_language_region_screen.dart';
import 'package:pulse_flutter/screens/settings_about_screen.dart';
import 'package:pulse_flutter/screens/e2ee_settings_screen.dart';
import 'package:pulse_flutter/screens/sessions_screen.dart';
import 'package:pulse_flutter/screens/profile_screen.dart';
import 'package:pulse_flutter/features/sessions/data/sessions_repository.dart';
import 'package:pulse_flutter/features/sessions/domain/session_model.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:pulse_flutter/l10n/app_localizations_ru.dart';
import 'package:pulse_flutter/widgets/nav/shell_window_title.dart';
import 'package:pulse_flutter/widgets/nav/app_nav_item.dart';
import 'package:pulse_flutter/core/services/desktop_window_service.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/features/settings/application/settings_anchor_controller.dart';
import 'package:pulse_flutter/features/settings/application/settings_health_controller.dart';
import 'package:pulse_flutter/features/settings/domain/settings_issue.dart';
import 'package:pulse_flutter/features/settings/presentation/settings_issue_card.dart';
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

  @override
  Future<void> refreshProfile() async {}
}

// The hub shows how many devices are signed in, so it asks for the list.
class _NoSessions extends SessionsRepository {
  _NoSessions(super.ref);

  @override
  Future<({int? currentSessionId, List<AccountSession> sessions})>
  getSessions() async =>
      (currentSessionId: null, sessions: const <AccountSession>[]);
}

Widget _buildProfileScreenTestHarness({
  required Size surfaceSize,
  bool desktop = false,
  List<SettingsHealthIssue>? issues,
}) {
  final ThemeData theme = AppTheme.themed(
    const VisualThemeSettings(
      seedColor: Color(0xFF6750A4),
      themeMode: ThemeMode.light,
      useSystemDynamic: false,
    ),
    Brightness.light,
  );

  final GoRouter router = GoRouter(
    initialLocation: '/settings',
    routes: <RouteBase>[
      GoRoute(
        path: '/settings',
        builder: (BuildContext context, GoRouterState state) =>
            const ProfileScreen(),
      ),
      GoRoute(
        path: '/main/profile',
        builder: (BuildContext context, GoRouterState state) =>
            const ProfileScreen(),
      ),
      GoRoute(
        path: '/main/chats',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('chats-tab')),
      ),
      GoRoute(
        path: '/settings/wallpaper',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('wallpaper-route')),
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
        path: '/settings/notifications',
        builder: (BuildContext context, GoRouterState state) =>
            const SettingsNotificationsScreen(),
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

  addTearDown(router.dispose);
  return ProviderScope(
    overrides: [
      authProvider.overrideWith(() => _FakeAuthNotifier()),
      sessionsRepositoryProvider.overrideWith(_NoSessions.new),
      if (issues != null) settingsHealthProvider.overrideWithValue(issues),
      if (desktop)
        clientCapabilitiesProvider.overrideWithValue(
          const ClientCapabilities(
            isWeb: false,
            platform: TargetPlatform.windows,
          ),
        ),
    ],
    child: MaterialApp.router(
      theme: theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ru'),
      routerConfig: router,
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(size: surfaceSize),
          child: SizedBox(
            width: surfaceSize.width,
            height: surfaceSize.height,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final previous = UiSettingsNotifier.cachedPrefs;
    UiSettingsNotifier.cachedPrefs = await SharedPreferences.getInstance();
    addTearDown(() => UiSettingsNotifier.cachedPrefs = previous);
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

  group('Tier 1: the open section is remembered between launches', () {
    test('1.2a a chosen section is stored and read back by a new session', () async {
      final ProviderContainer first = ProviderContainer();
      addTearDown(first.dispose);
      first
          .read(desktopSelectedSettingsSectionProvider.notifier)
          .setSelectedSection(SettingsSectionId.privacy);
      await Future<void>.delayed(Duration.zero);
      expect(
        UiSettingsNotifier.cachedPrefs!.getString(
          DesktopSettingsSectionNotifier.storageKey,
        ),
        'privacy',
      );

      final ProviderContainer second = ProviderContainer();
      addTearDown(second.dispose);
      expect(
        second.read(desktopSelectedSettingsSectionProvider),
        SettingsSectionId.privacy,
      );
    });

    test('1.2b a stored name of a dissolved or unknown section still opens '
        'a real one', () async {
      final prefs = UiSettingsNotifier.cachedPrefs!;
      await prefs.setString(
        DesktopSettingsSectionNotifier.storageKey,
        'energySaving',
      );
      final ProviderContainer renamed = ProviderContainer();
      addTearDown(renamed.dispose);
      expect(
        renamed.read(desktopSelectedSettingsSectionProvider),
        SettingsSectionId.chats,
      );

      await prefs.setString(
        DesktopSettingsSectionNotifier.storageKey,
        'no-such-section',
      );
      final ProviderContainer unknown = ProviderContainer();
      addTearDown(unknown.dispose);
      expect(
        unknown.read(desktopSelectedSettingsSectionProvider),
        SettingsSectionId.account,
      );
    });
  });

  group('Tier 1: ProfileScreen Desktop Master-Detail Tests (>=840dp)', () {
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
        expect(
          find.text('Testing Master-Detail settings layout'),
          findsNothing,
        ); // Bio belongs in profile editing.

        // Verify master list tiles exist
        expect(find.byType(SettingsSection), findsWidgets);
        expect(find.byType(SettingsListItem), findsWidgets);

        // A persistent navigation pane and detail occupy adjacent regions.
        final master = tester.getRect(
          find.byKey(const ValueKey('settings-master-pane')),
        );
        final detail = tester.getRect(find.byType(SettingsAccountScreen));
        expect(master.width, greaterThanOrEqualTo(300));
        expect(master.right, closeTo(detail.left, .1));
        expect(detail.width, greaterThan(0));

        // Default embedded detail pane is SettingsAccountScreen
        expect(find.byType(SettingsAccountScreen), findsOneWidget);
        final SettingsAccountScreen accountScreen = tester
            .widget<SettingsAccountScreen>(find.byType(SettingsAccountScreen));
        expect(accountScreen.isEmbedded, isTrue);
      },
    );

    testWidgets(
      '1.3a On a very wide window the column of the section stays beside the '
      'list instead of drifting into the middle of its pane',
      (WidgetTester tester) async {
        const Size wide = Size(2560, 1440);
        tester.view.physicalSize = wide;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _buildProfileScreenTestHarness(surfaceSize: wide),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final Rect master = tester.getRect(
          find.byKey(const ValueKey('settings-master-pane')),
        );
        // The shell's column, not the pane that carries it: the pane fills the
        // whole free width, so only the column shows where it was put.
        final Finder column = find.descendant(
          of: find.byType(SettingsAccountScreen),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is ConstrainedBox &&
                widget.constraints.maxWidth == 860.0,
          ),
        );
        expect(column, findsOneWidget);
        final Rect content = tester.getRect(column);
        expect(content.width, 860.0);

        final double leftGap = content.left - master.right;
        final double rightGap = wide.width - content.right;
        // The pane is everything right of the list; the column may not use all
        // of it. The two gaps are what a centred column would split evenly.
        final double freeSpace = (wide.width - master.right) - content.width;
        // Right beside the list, give or take the gutters of the shell.
        expect(leftGap, lessThan(100));
        // The emptiness of a wide window belongs on the right: the gap on the
        // left is far less than the half of what the column leaves free.
        expect(leftGap, lessThan(freeSpace / 2 - 200));
        expect(rightGap, greaterThan(freeSpace / 2 + 200));
        expect(content.left, lessThan(wide.width / 2));
        expect(tester.takeException(), isNull);
      },
    );

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
          SettingsListItem,
          'Оформление',
        );
        expect(appearanceTile, findsWidgets);
        // Sixth row of the flat list: below the fold of an 800 dp window.
        await tester.ensureVisible(appearanceTile.first);
        await tester.pump();
        await tester.tap(appearanceTile.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Detail pane now renders SettingsAppearanceScreen with isEmbedded: true
        expect(find.byType(SettingsAppearanceScreen), findsOneWidget);
        final SettingsAppearanceScreen appearanceScreen = tester
            .widget<SettingsAppearanceScreen>(
              find.byType(SettingsAppearanceScreen),
            );
        expect(appearanceScreen.isEmbedded, isTrue);
      },
    );

    testWidgets('1.5 Selected master tile is styled with isSelected = true', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = desktopSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _buildProfileScreenTestHarness(surfaceSize: desktopSize),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The centered profile opens editing. Selection belongs to a real section.
      final master = find.byKey(const ValueKey('settings-master-pane'));
      final appearance = find.descendant(
        of: master,
        matching: find.widgetWithText(SettingsListItem, 'Оформление'),
      );
      expect(appearance, findsOneWidget);
      await tester.ensureVisible(appearance);
      await tester.pump();
      await tester.tap(appearance);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.widget<SettingsListItem>(appearance).isSelected, isTrue);
      expect(
        find.descendant(
          of: master,
          matching: find.byWidgetPredicate(
            (widget) => widget is SettingsListItem && widget.isSelected,
          ),
        ),
        findsOneWidget,
      );
      expect(find.byType(SettingsAppearanceScreen), findsOneWidget);
      expect(find.byType(SettingsAccountScreen), findsNothing);
    });

    testWidgets('1.5a Both panes carry a scrollbar in a desktop window', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = desktopSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _buildProfileScreenTestHarness(surfaceSize: desktopSize, desktop: true),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('settings-master-pane')),
          matching: find.byType(Scrollbar),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(SettingsAccountScreen),
          matching: find.byType(Scrollbar),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.5b A touch device gets no scrollbar in either pane', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = desktopSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _buildProfileScreenTestHarness(surfaceSize: desktopSize),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const ValueKey('settings-master-pane')),
        findsOneWidget,
      );
      expect(find.byType(Scrollbar), findsNothing);
    });

    testWidgets('1.5c Arrow keys in the list open the next and previous '
        'section and carry the focus along', (WidgetTester tester) async {
      tester.view.physicalSize = desktopSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _buildProfileScreenTestHarness(surfaceSize: desktopSize),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(ProfileScreen)),
      );

      Focus.of(
        tester.element(
          find
              .descendant(
                of: find.byKey(const ValueKey('settings-destination-account')),
                matching: find.byType(AnimatedContainer),
              )
              .first,
        ),
      ).requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        container.read(desktopSelectedSettingsSectionProvider),
        SettingsSectionId.sessions,
      );

      // Up steps from the row the focus moved to. Had the focus stayed on
      // the first row, there would be nothing above it to open.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        container.read(desktopSelectedSettingsSectionProvider),
        SettingsSectionId.account,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.5d The search key of the shell opens the settings search', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = desktopSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _buildProfileScreenTestHarness(surfaceSize: desktopSize),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final BuildContext hub = tester.element(find.byType(ProfileScreen));
      final String emptyHint = hub.l10n.settingsV2SearchEmpty;
      expect(find.text(emptyHint), findsNothing);

      ProviderScope.containerOf(hub)
          .read(settingsKeyCommandProvider.notifier)
          .send(SettingsKeyCommand.search);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(emptyHint), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.5e The back key of the shell leaves a top-level section '
        'for the chats', (WidgetTester tester) async {
      tester.view.physicalSize = desktopSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _buildProfileScreenTestHarness(surfaceSize: desktopSize),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('chats-tab'), findsNothing);

      ProviderScope.containerOf(tester.element(find.byType(ProfileScreen)))
          .read(settingsKeyCommandProvider.notifier)
          .send(SettingsKeyCommand.back);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('chats-tab'), findsOneWidget);
      expect(find.byType(ProfileScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.5i Beside a section the list is navigation: low rows '
        'without chevrons, the account pinned at its foot', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = desktopSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _buildProfileScreenTestHarness(surfaceSize: desktopSize),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final Finder master = find.byKey(const ValueKey('settings-master-pane'));
      final Finder account = find.byKey(
        const ValueKey('settings-destination-account'),
      );
      expect(
        find.descendant(
          of: master,
          matching: find.byIcon(Icons.chevron_right_rounded),
        ),
        findsNothing,
      );
      expect(tester.getSize(account).height, lessThan(AppHeights.rowCompact));

      final Finder card = find.byKey(
        const ValueKey<String>('settings-profile-card'),
      );
      expect(find.descendant(of: master, matching: card), findsOneWidget);
      // Outside the scrolling list, so it does not leave with the rows.
      expect(
        find.ancestor(of: card, matching: find.byType(ListView)),
        findsNothing,
      );
      expect(
        tester.getRect(card).top,
        greaterThan(tester.getRect(account).bottom),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.5j A problem marks the row of its section instead of '
        'showing a card, and the row leads to the fix', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = desktopSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final SemanticsHandle semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        _buildProfileScreenTestHarness(
          surfaceSize: desktopSize,
          issues: const <SettingsHealthIssue>[
            SettingsHealthIssue.deletionPending(null),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SettingsIssueCard), findsNothing);
      final Finder account = find.byKey(
        const ValueKey('settings-destination-account'),
      );
      final String? said = tester.widget<SettingsListItem>(account).attention;
      expect(said, isNotNull);
      expect(said, isNotEmpty);
      expect(
        tester
            .widget<SettingsListItem>(
              find.byKey(const ValueKey('settings-destination-privacy')),
            )
            .attention,
        isNull,
      );
      // The dot is silent: a screen reader hears what is wrong on the row.
      expect(
        find.descendant(
          of: account,
          matching: find.bySemanticsLabel(RegExp(RegExp.escape(said!))),
        ),
        findsWidgets,
      );

      await tester.tap(account);
      await tester.pump();
      expect(
        ProviderScope.containerOf(
          tester.element(find.byType(ProfileScreen)),
        ).read(settingsAnchorControllerProvider).highlightedAnchor,
        'account.delete',
      );
      // The highlight clears itself after a second.
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('1.5k A single column keeps the card for the same problem', (
      WidgetTester tester,
    ) async {
      const Size phone = Size(400, 800);
      tester.view.physicalSize = phone;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _buildProfileScreenTestHarness(
          surfaceSize: phone,
          issues: const <SettingsHealthIssue>[
            SettingsHealthIssue.deletionPending(null),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SettingsIssueCard), findsOneWidget);
      expect(
        tester
            .widget<SettingsListItem>(
              find.byKey(const ValueKey('settings-destination-account')),
            )
            .attention,
        isNull,
      );
      // Rows that push a screen keep their chevrons.
      expect(find.byIcon(Icons.chevron_right_rounded), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    test('1.5l the smallest window still fits both panes', () {
      // What the frame takes from the window: resize borders at the sides,
      // the title bar on top.
      const Size frame = Size(16, 40);
      const Size smallest = DesktopWindowService.minimumWindowSize;
      expect(
        Breakpoints.settingsTwoPane(
          Size(
            smallest.width - frame.width - AppNavMetrics.railWidth - 1,
            smallest.height - frame.height,
          ),
        ),
        isTrue,
      );
    });

    Future<void> openWallpaperInPane(WidgetTester tester) async {
      tester.view.physicalSize = desktopSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _buildProfileScreenTestHarness(surfaceSize: desktopSize),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final Finder appearance = find.byKey(
        const ValueKey('settings-destination-appearance'),
      );
      await tester.ensureVisible(appearance);
      await tester.pump();
      await tester.tap(appearance);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final Finder entry = find.byKey(
        const ValueKey('settings-wallpaper-entry'),
      );
      await tester.ensureVisible(entry);
      await tester.pump();
      await tester.tap(entry);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('1.5m A screen under a section opens in the pane beside the '
        'list, and the link above it returns to the section', (
      WidgetTester tester,
    ) async {
      await openWallpaperInPane(tester);
      final Finder master = find.byKey(const ValueKey('settings-master-pane'));
      expect(master, findsOneWidget);
      expect(find.byType(SettingsWallpaperScreen), findsOneWidget);
      expect(find.byType(SettingsAppearanceScreen), findsNothing);
      // Not the pushed page: that one would cover the list.
      expect(find.text('wallpaper-route'), findsNothing);
      expect(
        tester.getRect(find.byType(SettingsWallpaperScreen)).left,
        greaterThanOrEqualTo(tester.getRect(master).right),
      );

      final Finder back = find.byKey(
        const ValueKey<String>('settings-subpage-back'),
      );
      expect(
        find.descendant(of: back, matching: find.text('Оформление')),
        findsOneWidget,
      );
      await tester.tap(back);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SettingsWallpaperScreen), findsNothing);
      expect(find.byType(SettingsAppearanceScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.5n Closing the opened screen from inside it returns to '
        'the section and leaves the settings tab alone', (
      WidgetTester tester,
    ) async {
      await openWallpaperInPane(tester);
      final String discard = tester
          .element(find.byType(ProfileScreen))
          .l10n
          .wallpaperDiscard;
      await tester.tap(find.widgetWithText(OutlinedButton, discard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SettingsWallpaperScreen), findsNothing);
      expect(find.byType(SettingsAppearanceScreen), findsOneWidget);
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('chats-tab'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.5o The back key closes the opened screen before it '
        'leaves the settings', (WidgetTester tester) async {
      await openWallpaperInPane(tester);
      ProviderScope.containerOf(tester.element(find.byType(ProfileScreen)))
          .read(settingsKeyCommandProvider.notifier)
          .send(SettingsKeyCommand.back);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SettingsWallpaperScreen), findsNothing);
      expect(find.byType(SettingsAppearanceScreen), findsOneWidget);
      expect(find.text('chats-tab'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.5p Choosing a section drops the screen opened under the '
        'previous one', (WidgetTester tester) async {
      await openWallpaperInPane(tester);
      final Finder account = find.byKey(
        const ValueKey('settings-destination-account'),
      );
      await tester.ensureVisible(account);
      await tester.pump();
      await tester.tap(account);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SettingsAccountScreen), findsOneWidget);
      expect(find.byType(SettingsWallpaperScreen), findsNothing);

      final Finder appearance = find.byKey(
        const ValueKey('settings-destination-appearance'),
      );
      await tester.ensureVisible(appearance);
      await tester.pump();
      await tester.tap(appearance);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // The section itself, not the screen that was left open under it.
      expect(find.byType(SettingsAppearanceScreen), findsOneWidget);
      expect(find.byType(SettingsWallpaperScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.5q In a single column the same entry pushes its page', (
      WidgetTester tester,
    ) async {
      const Size phone = Size(400, 800);
      tester.view.physicalSize = phone;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _buildProfileScreenTestHarness(surfaceSize: phone),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final Finder appearance = find.byKey(
        const ValueKey('settings-destination-appearance'),
      );
      await tester.ensureVisible(appearance);
      await tester.pump();
      await tester.tap(appearance);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      final Finder entry = find.byKey(
        const ValueKey('settings-wallpaper-entry'),
      );
      await tester.ensureVisible(entry);
      await tester.pump();
      await tester.tap(entry);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('wallpaper-route'), findsOneWidget);
      expect(find.byType(SettingsWallpaperScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Tier 1: the window title names the open section', () {
    test('1.5f the title is built from the tab and the section', () {
      final l10n = AppLocalizationsRu();
      expect(
        ShellWindowTitle.compose(
          l10n,
          settingsOpen: false,
          section: SettingsSectionId.appearance,
        ),
        'NiosMess',
      );
      expect(
        ShellWindowTitle.compose(l10n, settingsOpen: true),
        '${l10n.tabSettings} — NiosMess',
      );
      expect(
        ShellWindowTitle.compose(
          l10n,
          settingsOpen: true,
          section: SettingsSectionId.appearance,
        ),
        '${l10n.tabSettings} · Оформление — NiosMess',
      );
    });

    Widget titled({required bool web, required SettingsSectionId section}) =>
        ProviderScope(
          overrides: [
            clientCapabilitiesProvider.overrideWithValue(
              ClientCapabilities(isWeb: web, platform: TargetPlatform.windows),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ShellWindowTitle(
              settingsOpen: true,
              sectionVisible: true,
              webSection: section,
              child: const SizedBox.shrink(),
            ),
          ),
        );

    testWidgets('1.5g a browser tab is titled with the section from the '
        'address', (WidgetTester tester) async {
      await tester.pumpWidget(
        titled(web: true, section: SettingsSectionId.appearance),
      );
      await tester.pump();
      final l10n = AppLocalizationsRu();
      expect(
        tester.widgetList<Title>(find.byType(Title)).last.title,
        '${l10n.tabSettings} · Оформление — NiosMess',
      );

      // Device diagnostics do not exist in a browser: the link shows About.
      await tester.pumpWidget(
        titled(web: true, section: SettingsSectionId.systemDevice),
      );
      await tester.pump();
      expect(
        tester.widgetList<Title>(find.byType(Title)).last.title,
        ShellWindowTitle.compose(
          l10n,
          settingsOpen: true,
          section: SettingsSectionId.about,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.5h a desktop window adds no browser title of its own', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        titled(web: false, section: SettingsSectionId.appearance),
      );
      await tester.pump();
      // Only the one the app itself always carries.
      expect(find.byType(Title), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Tier 1: ProfileScreen Mobile Fallback Tests (<840dp)', () {
    const Size mobileSize = Size(400, 800);

    testWidgets(
      '1.6 Renders single-column stacked layout without VerticalDivider',
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
        expect(
          find.byKey(const ValueKey('settings-master-pane')),
          findsNothing,
        );

        // User info present in mobile header
        expect(find.text('Alex Test'), findsWidgets);
        expect(find.text('@alex_test'), findsWidgets);
      },
    );
  });

  group('Tier 2: Master-Detail Boundary Viewports (360dp to 3840dp 4K)', () {
    final List<Map<String, dynamic>> testViewports = [
      {
        'name': 'Compact Mobile 360x640',
        'size': const Size(360, 640),
        'isWide': false,
      },
      {
        'name': 'Standard Mobile 390x844',
        'size': const Size(390, 844),
        'isWide': false,
      },
      // The rail breakpoint alone no longer splits settings: the open section
      // would get 500 dp, less than a phone.
      {
        'name': 'Below Split Threshold 840x1024',
        'size': const Size(840, 1024),
        'isWide': false,
      },
      {
        'name': 'Split Threshold 860x1024',
        'size': const Size(860, 1024),
        'isWide': true,
      },
      {
        'name': 'Wide But Low 1200x400',
        'size': const Size(1200, 400),
        'isWide': false,
      },
      {
        'name': 'Laptop 1366x768',
        'size': const Size(1366, 768),
        'isWide': true,
      },
      {
        'name': 'Desktop Full HD 1920x1080',
        'size': const Size(1920, 1080),
        'isWide': true,
      },
      {
        'name': 'Desktop 4K 3840x2160',
        'size': const Size(3840, 2160),
        'isWide': true,
      },
    ];

    for (final vp in testViewports) {
      testWidgets(
        '2.1 Master-detail layout on ${vp['name']} renders without overflow',
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
            final master = find.byKey(const ValueKey('settings-master-pane'));
            expect(master, findsOneWidget);
            expect(find.byType(SettingsAccountScreen), findsOneWidget);
            expect(
              tester.getRect(master).right,
              closeTo(
                tester.getRect(find.byType(SettingsAccountScreen)).left,
                .1,
              ),
            );
          } else {
            expect(
              find.byKey(const ValueKey('settings-master-pane')),
              findsNothing,
            );
            expect(find.byType(CustomScrollView), findsOneWidget);
          }
        },
      );
    }
  });
}
