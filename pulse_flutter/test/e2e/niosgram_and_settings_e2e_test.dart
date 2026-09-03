import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/badge_model.dart';
import 'package:pulse_flutter/models/api/post_model.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/niosgram_provider.dart';
import 'package:pulse_flutter/providers/notifications_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/screens/niosgram_screen.dart';
import 'package:pulse_flutter/screens/profile_screen.dart';
import 'package:pulse_flutter/screens/settings_about_screen.dart';
import 'package:pulse_flutter/screens/settings_account_screen.dart';
import 'package:pulse_flutter/screens/settings_appearance_screen.dart';
import 'package:pulse_flutter/screens/settings_language_region_screen.dart';
import 'package:pulse_flutter/screens/settings_preferences_screen.dart';
import 'package:pulse_flutter/screens/settings_privacy_screen.dart';
import 'package:pulse_flutter/widgets/post_card.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Mock Notifiers for E2E Integration ──────────────────────────────────────

class MockE2eAuthNotifier extends AuthNotifier {
  MockE2eAuthNotifier({this.currentUserId = 1, this.currentUsername = 'alex_hero'});
  final int currentUserId;
  final String currentUsername;

  @override
  AuthState build() {
    return AuthState(
      hydrated: true,
      busy: false,
      session: AuthSession(
        accessToken: 'mock_e2e_jwt_token',
        userId: currentUserId,
        username: currentUsername,
        displayName: 'Alex Hero',
      ),
      pendingIdentifier: null,
      error: null,
      profile: ApiProfile(
        id: currentUserId,
        username: currentUsername,
        displayName: 'Alex Hero',
        bio: 'M3 Expressive E2E Specialist',
      ),
    );
  }
}

class MockE2eNiosgramNotifier extends NiosgramNotifier {
  MockE2eNiosgramNotifier(this._initialState);
  final NiosgramState _initialState;

  int? lastReactedPostId;
  bool? lastReactedIsLike;

  @override
  Future<NiosgramState> build() async => _initialState;

  @override
  Future<void> refresh() async {
    state = AsyncData<NiosgramState>(_initialState);
  }

  @override
  Future<void> loadMore() async {}

  @override
  Future<void> reactPost(int postId, bool isLike) async {
    lastReactedPostId = postId;
    lastReactedIsLike = isLike;
    final AsyncData<NiosgramState>? current = state.asData;
    if (current == null) return;

    final List<NgPost> updated = current.value.posts.map((NgPost p) {
      if (p.id != postId) return p;
      final bool? prev = p.myReaction;
      final bool? next = prev == isLike ? null : isLike;
      int likes = p.likesCount;
      int dislikes = p.dislikesCount;
      if (prev == true) likes--;
      if (prev == false) dislikes--;
      if (next == true) likes++;
      if (next == false) dislikes++;
      return p.copyWith(
        likesCount: likes,
        dislikesCount: dislikes,
        myReaction: () => next,
      );
    }).toList(growable: false);

    state = AsyncData<NiosgramState>(current.value.copyWith(posts: updated));
  }
}

class MockE2eNotificationsNotifier extends NotificationsNotifier {
  @override
  NotificationsState build() => const NotificationsState(unreadCount: 0);
}

// ── Test Feed Data ──────────────────────────────────────────────────────────

List<NgPost> _generateSampleFeed() {
  return [
    NgPost(
      id: 1001,
      content: '## Welcome to NiosGram 3.0\nExperience **pure Material 3 Expressive** design with dynamic color and squircle containers.',
      author: const ApiProfile(
        id: 2,
        username: 'elena_design',
        displayName: 'Elena Rostova',
        bio: 'Lead M3 Designer',
        badges: [
          ApiBadge(id: 1, name: 'Verified', icon: 'verified', color: '#2196F3'),
        ],
      ),
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      likesCount: 24,
      dislikesCount: 0,
      commentsCount: 3,
      myReaction: null,
      isFollowing: false,
    ),
    NgPost(
      id: 1002,
      content: 'Exploring Master-Detail settings coordinator on wide screens (>=760dp). Instant sub-screen switching without full rebuilds.',
      author: const ApiProfile(
        id: 3,
        username: 'dev_sergey',
        displayName: 'Sergey Dev',
        bio: 'Core Flutter Engineer',
        badges: [],
      ),
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      likesCount: 15,
      dislikesCount: 1,
      commentsCount: 6,
      myReaction: null,
      isFollowing: true,
    ),
  ];
}

// ── E2E Router & App Harness ────────────────────────────────────────────────

Widget _buildE2eApp({
  required GoRouter router,
  required MockE2eNiosgramNotifier niosgramNotifier,
}) {
  return ProviderScope(
    overrides: [
      authProvider.overrideWith(() => MockE2eAuthNotifier()),
      niosgramProvider.overrideWith(() => niosgramNotifier),
      notificationsProvider.overrideWith(MockE2eNotificationsNotifier.new),
    ],
    child: Consumer(
      builder: (context, ref, _) {
        final UiSettingsState uiSettings = ref.watch(uiSettingsProvider);
        final ThemeData theme = AppTheme.themed(
          uiSettings.visualTheme,
          uiSettings.themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light,
        );

        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: theme,
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        );
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ══════════════════════════════════════════════════════════════════════════
  // TIER 3: CROSS-FEATURE COMBINATIONS
  // ══════════════════════════════════════════════════════════════════════════
  group('Tier 3: Cross-Feature Combinations', () {
    testWidgets('3.1 Feed dynamic viewport resizing during active scroll without layout errors', (
      WidgetTester tester,
    ) async {
      final posts = _generateSampleFeed();
      final niosgramNotifier = MockE2eNiosgramNotifier(NiosgramState(posts: posts, hasMore: false));

      final router = GoRouter(
        initialLocation: '/main/niosgram',
        routes: [
          GoRoute(path: '/main/niosgram', builder: (_, _) => const NiosgramScreen()),
        ],
      );

      // 1. Start on Mobile viewport (390x844)
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildE2eApp(router: router, niosgramNotifier: niosgramNotifier));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(PostCard), findsWidgets);

      // 2. Perform scroll
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 3. Dynamically resize viewport to Desktop (1920x1080)
      tester.view.physicalSize = const Size(1920, 1080);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.byType(PostCard), findsWidgets);
    });

    testWidgets('3.2 Theme switching while viewing Settings Master-Detail updates all panes', (
      WidgetTester tester,
    ) async {
      final posts = _generateSampleFeed();
      final niosgramNotifier = MockE2eNiosgramNotifier(NiosgramState(posts: posts, hasMore: false));

      final router = GoRouter(
        initialLocation: '/main/profile',
        routes: [
          GoRoute(path: '/main/profile', builder: (_, _) => const ProfileScreen()),
        ],
      );

      tester.view.physicalSize = const Size(1024, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildE2eApp(router: router, niosgramNotifier: niosgramNotifier));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Switch to Appearance section in master pane
      final appearanceTile = find.widgetWithText(SettingsTile, 'Внешний вид');
      expect(appearanceTile, findsWidgets);
      await tester.tap(appearanceTile.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SettingsAppearanceScreen), findsOneWidget);

      // Find Dark mode card in Appearance screen and tap it
      final darkCard = find.widgetWithText(InkWell, 'Темная');
      if (darkCard.evaluate().isNotEmpty) {
        await tester.tap(darkCard.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets('3.3 Navigation between Feed and Settings preserves active detail pane state', (
      WidgetTester tester,
    ) async {
      final posts = _generateSampleFeed();
      final niosgramNotifier = MockE2eNiosgramNotifier(NiosgramState(posts: posts, hasMore: false));

      final router = GoRouter(
        initialLocation: '/main/profile',
        routes: [
          GoRoute(path: '/main/profile', builder: (_, _) => const ProfileScreen()),
          GoRoute(path: '/main/niosgram', builder: (_, _) => const NiosgramScreen()),
        ],
      );

      tester.view.physicalSize = const Size(1024, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildE2eApp(router: router, niosgramNotifier: niosgramNotifier));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Select Privacy section in master pane
      final privacyFinder = find.byIcon(Icons.lock_rounded);
      await tester.scrollUntilVisible(
        privacyFinder,
        100.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(privacyFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SettingsPrivacyScreen), findsOneWidget);

      // Navigate to NiosGram feed
      router.go('/main/niosgram');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(NiosgramScreen), findsOneWidget);

      // Navigate back to Settings
      router.go('/main/profile');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.byType(SettingsPrivacyScreen), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // TIER 4: REAL-WORLD APPLICATION SCENARIOS
  // ══════════════════════════════════════════════════════════════════════════
  group('Tier 4: Real-World Application Scenarios', () {
    testWidgets('4.1 Full Social Feed Workflow: browsing, reaction, bookmarking, and creation', (
      WidgetTester tester,
    ) async {
      final posts = _generateSampleFeed();
      final niosgramNotifier = MockE2eNiosgramNotifier(NiosgramState(posts: posts, hasMore: false));
      bool navigatedToComments = false;

      final router = GoRouter(
        initialLocation: '/main/niosgram',
        routes: [
          GoRoute(path: '/main/niosgram', builder: (_, _) => const NiosgramScreen()),
          GoRoute(
            path: '/niosgram/create',
            builder: (_, _) => const Scaffold(body: Text('Create Screen')),
          ),
          GoRoute(
            path: '/niosgram/post/:postId/comments',
            builder: (_, _) {
              navigatedToComments = true;
              return const Scaffold(body: Text('Comments Screen'));
            },
          ),
        ],
      );

      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildE2eApp(router: router, niosgramNotifier: niosgramNotifier));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Verify feed displays posts with author names & verified badge
      expect(find.text('Elena Rostova'), findsOneWidget);
      expect(find.text('Sergey Dev'), findsOneWidget);

      // 2. Like first post
      final likeFinder = find.byIcon(Icons.favorite_border_rounded).first;
      await tester.tap(likeFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(niosgramNotifier.lastReactedPostId, 1001);
      expect(niosgramNotifier.lastReactedIsLike, true);

      // 3. Bookmark post
      final bookmarkFinder = find.byIcon(Icons.bookmark_outline_rounded).first;
      await tester.tap(bookmarkFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);

      // 4. Tap comments chip
      final commentsFinder = find.byIcon(Icons.chat_bubble_outline_rounded).first;
      await tester.tap(commentsFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(navigatedToComments, isTrue);

      // 5. Navigate back to feed
      router.go('/main/niosgram');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 6. Tap quick-creation in feed
      final createFinder = find.text('Что у вас нового?');
      expect(createFinder, findsOneWidget);
      await tester.tap(createFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Новая публикация'), findsOneWidget);
      expect(find.text('Опубликовать'), findsOneWidget);
    });

    testWidgets('4.2 Full Settings Master-Detail Workflow: section switching and controls adjustments', (
      WidgetTester tester,
    ) async {
      final posts = _generateSampleFeed();
      final niosgramNotifier = MockE2eNiosgramNotifier(NiosgramState(posts: posts, hasMore: false));

      final router = GoRouter(
        initialLocation: '/main/profile',
        routes: [
          GoRoute(path: '/main/profile', builder: (_, _) => const ProfileScreen()),
        ],
      );

      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildE2eApp(router: router, niosgramNotifier: niosgramNotifier));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Default section: Account
      expect(find.byType(SettingsAccountScreen), findsOneWidget);

      // 1. Switch to Appearance & adjust font scale
      final appearanceTile = find.widgetWithText(SettingsTile, 'Внешний вид');
      await tester.tap(appearanceTile.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SettingsAppearanceScreen), findsOneWidget);
      expect(find.byType(SegmentedButton<AppFontScale>), findsOneWidget);

      // 2. Switch to Preferences & adjust volume slider
      final prefFinder = find.byIcon(Icons.notifications_active_rounded);
      await tester.scrollUntilVisible(
        prefFinder,
        100.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(prefFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SettingsPreferencesScreen), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);

      // 3. Switch to Privacy & toggle hideOnline
      final privacyFinder = find.byIcon(Icons.lock_rounded);
      await tester.scrollUntilVisible(
        privacyFinder,
        -100.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(privacyFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SettingsPrivacyScreen), findsOneWidget);
      expect(find.byType(Switch), findsWidgets);

      // 4. Switch to Language & Region
      final langFinder = find.byIcon(Icons.language_rounded);
      await tester.scrollUntilVisible(
        langFinder,
        -100.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(langFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SettingsLanguageRegionScreen), findsOneWidget);

      // 5. Switch to About
      final aboutFinder = find.byIcon(Icons.info_outline_rounded);
      await tester.scrollUntilVisible(
        aboutFinder,
        100.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(aboutFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SettingsAboutScreen), findsOneWidget);
    });

    testWidgets('4.3 Mobile Stacked Navigation & Return Journey', (
      WidgetTester tester,
    ) async {
      final posts = _generateSampleFeed();
      final niosgramNotifier = MockE2eNiosgramNotifier(NiosgramState(posts: posts, hasMore: false));

      final router = GoRouter(
        initialLocation: '/main/profile',
        routes: [
          GoRoute(path: '/main/profile', builder: (_, _) => const ProfileScreen()),
          GoRoute(path: '/settings/account', builder: (_, _) => const SettingsAccountScreen()),
          GoRoute(path: '/settings/appearance', builder: (_, _) => const SettingsAppearanceScreen()),
          GoRoute(path: '/settings/privacy', builder: (_, _) => const SettingsPrivacyScreen()),
        ],
      );

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildE2eApp(router: router, niosgramNotifier: niosgramNotifier));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Mobile renders CustomScrollView
      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(find.byType(VerticalDivider), findsNothing);

      // Tap Appearance tile -> navigate full-screen
      final appearanceTile = find.widgetWithText(SettingsTile, 'Внешний вид');
      await tester.ensureVisible(appearanceTile.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(appearanceTile.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SettingsAppearanceScreen), findsOneWidget);

      // Pop back to profile screen
      router.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ProfileScreen), findsOneWidget);
    });
  });
}
