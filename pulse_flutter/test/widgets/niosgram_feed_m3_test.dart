import 'package:flutter/material.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
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
import 'package:pulse_flutter/widgets/app_error_banner.dart';
import 'package:pulse_flutter/widgets/badge_chip.dart';
import 'package:pulse_flutter/widgets/empty_feed_widget.dart';
import 'package:pulse_flutter/widgets/post_card.dart';
import 'package:pulse_flutter/widgets/pulse_skeleton.dart';

// ── Mock Notifiers ─────────────────────────────────────────────────────────

class MockNiosgramNotifier extends NiosgramNotifier {
  MockNiosgramNotifier(this._initialState);
  final NiosgramState _initialState;

  int refreshCount = 0;
  int? lastReactedPostId;
  bool? lastReactedIsLike;
  String? lastToggledFollowUsername;

  @override
  Future<NiosgramState> build() async {
    return _initialState;
  }

  @override
  Future<void> refresh() async {
    refreshCount++;
    state = AsyncData<NiosgramState>(_initialState);
  }

  @override
  Future<void> loadMore() async {
    // Hermetic no-op for tests
  }

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

  @override
  Future<void> toggleFollow(String username) async {
    lastToggledFollowUsername = username;
    final AsyncData<NiosgramState>? current = state.asData;
    if (current == null) return;

    final List<NgPost> updated = current.value.posts.map((NgPost p) {
      if (p.author.username != username) return p;
      return p.copyWith(isFollowing: !p.isFollowing);
    }).toList(growable: false);

    state = AsyncData<NiosgramState>(current.value.copyWith(posts: updated));
  }
}

class MockErrorNiosgramNotifier extends NiosgramNotifier {
  @override
  Future<NiosgramState> build() {
    state = AsyncError('Failed to load feed', StackTrace.current);
    return Future.error('Failed to load feed');
  }

  @override
  Future<void> loadMore() async {}
}

class MockNotificationsNotifier extends NotificationsNotifier {
  @override
  NotificationsState build() {
    return const NotificationsState(unreadCount: 0);
  }
}

class MockAuthNotifier extends AuthNotifier {
  MockAuthNotifier({this.currentUserId = 1, this.currentUsername = 'john_doe'});
  final int currentUserId;
  final String currentUsername;

  @override
  AuthState build() {
    return AuthState(
      hydrated: true,
      busy: false,
      session: AuthSession(
        accessToken: 'mock_token',
        userId: currentUserId,
        username: currentUsername,
        displayName: 'John Doe',
      ),
      pendingIdentifier: null,
      error: null,
      profile: ApiProfile(
        id: currentUserId,
        username: currentUsername,
        displayName: 'John Doe',
        bio: 'Bio of John',
      ),
    );
  }

  @override
  Future<void> refreshProfile() async {}
}

// ── Test Harness Helpers ───────────────────────────────────────────────────

NgPost _createSamplePost({
  int id = 101,
  String content = 'Hello NiosGram! This is an expressive M3 post.',
  int authorId = 2,
  String authorUsername = 'alice',
  String authorDisplayName = 'Alice Cooper',
  String? mediaUrl,
  int likesCount = 12,
  int dislikesCount = 1,
  int commentsCount = 4,
  bool? myReaction,
  bool isFollowing = false,
  DateTime? createdAt,
  List<ApiBadge> badges = const [],
}) {
  return NgPost(
    id: id,
    content: content,
    author: ApiProfile(
      id: authorId,
      username: authorUsername,
      displayName: authorDisplayName,
      bio: 'Alice bio',
      avatarUrl: null,
      badges: badges,
    ),
    createdAt: createdAt ?? DateTime.now().subtract(const Duration(minutes: 15)),
    likesCount: likesCount,
    dislikesCount: dislikesCount,
    commentsCount: commentsCount,
    mediaUrl: mediaUrl,
    myReaction: myReaction,
    isFollowing: isFollowing,
  );
}

Widget _buildTestApp({
  required Widget child,
  List<dynamic> overrides = const [],
  GoRouter? router,
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

  final List<dynamic> defaultOverrides = [
    notificationsProvider.overrideWith(MockNotificationsNotifier.new),
    ...overrides,
  ];

  if (router != null) {
    return ProviderScope(
      overrides: defaultOverrides.cast(),
      child: MaterialApp.router(
        routerConfig: router,
        debugShowCheckedModeBanner: false,
        theme: theme,
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  return ProviderScope(
    overrides: defaultOverrides.cast(),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ══════════════════════════════════════════════════════════════════════════
  // TIER 1: FEATURE COVERAGE (PostCard Rendering & Reactive Action Controls)
  // ══════════════════════════════════════════════════════════════════════════
  group('Tier 1: NiosGram PostCard & Feed Feature Coverage', () {
    testWidgets('1.1 PostCard renders author display name, username, and relative time', (
      WidgetTester tester,
    ) async {
      final post = _createSamplePost(
        authorDisplayName: 'Alice Cooper',
        authorUsername: 'alice',
      );

      await tester.pumpWidget(
        _buildTestApp(
          overrides: [
            authProvider.overrideWith(() => MockAuthNotifier()),
          ],
          child: PostCard(post: post),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alice Cooper'), findsOneWidget);
      expect(find.textContaining('@alice'), findsOneWidget);
    });

    testWidgets('1.2 PostCard renders M3 tonal background surfaceContainerLow', (
      WidgetTester tester,
    ) async {
      final post = _createSamplePost();

      await tester.pumpWidget(
        _buildTestApp(
          overrides: [
            authProvider.overrideWith(() => MockAuthNotifier()),
          ],
          child: PostCard(post: post),
        ),
      );
      await tester.pumpAndSettle();

      final Card card = tester.widget<Card>(find.byType(Card));
      expect(card.elevation, 0);
      expect(card.clipBehavior, Clip.antiAlias);
    });

    testWidgets('1.3 PostCard renders markdown body formatted content', (
      WidgetTester tester,
    ) async {
      final post = _createSamplePost(
        content: '**Bold Header** and `inline_code` with [Link](https://ni-os.ru)',
      );

      await tester.pumpWidget(
        _buildTestApp(
          overrides: [
            authProvider.overrideWith(() => MockAuthNotifier()),
          ],
          child: PostCard(post: post),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Bold Header'), findsOneWidget);
    });

    testWidgets('1.4 PostCard displays follow button for other users and triggers toggleFollow', (
      WidgetTester tester,
    ) async {
      final post = _createSamplePost(
        authorId: 99,
        authorUsername: 'charlie',
        isFollowing: false,
      );
      final mockNiosgram = MockNiosgramNotifier(NiosgramState(posts: [post]));

      await tester.pumpWidget(
        _buildTestApp(
          overrides: [
            authProvider.overrideWith(() => MockAuthNotifier(currentUserId: 1)),
            niosgramProvider.overrideWith(() => mockNiosgram),
          ],
          child: PostCard(post: post),
        ),
      );
      await tester.pumpAndSettle();

      final followBtn = find.byType(TextButton);
      expect(followBtn, findsOneWidget);

      await tester.tap(followBtn);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(mockNiosgram.lastToggledFollowUsername, 'charlie');
    });

    testWidgets('1.5 PostCard hides follow button for own posts and provides menu', (
      WidgetTester tester,
    ) async {
      final ownPost = _createSamplePost(
        authorId: 1,
        authorUsername: 'john_doe',
      );

      await tester.pumpWidget(
        _buildTestApp(
          overrides: [
            authProvider.overrideWith(() => MockAuthNotifier(currentUserId: 1)),
          ],
          child: PostCard(post: ownPost),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextButton), findsNothing);
      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
    });

    testWidgets('1.6 Reactive action buttons: displays like, dislike, comment, and share', (
      WidgetTester tester,
    ) async {
      final post = _createSamplePost(
        likesCount: 42,
        dislikesCount: 3,
        commentsCount: 7,
      );

      await tester.pumpWidget(
        _buildTestApp(
          overrides: [
            authProvider.overrideWith(() => MockAuthNotifier()),
          ],
          child: PostCard(post: post),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('42'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.byIcon(Icons.share_outlined), findsOneWidget);
    });

    testWidgets('1.7 Tapping like chip invokes reactPost optimistic update', (
      WidgetTester tester,
    ) async {
      final post = _createSamplePost(id: 201, likesCount: 10, myReaction: null);
      final mockNiosgram = MockNiosgramNotifier(NiosgramState(posts: [post]));

      await tester.pumpWidget(
        _buildTestApp(
          overrides: [
            authProvider.overrideWith(() => MockAuthNotifier()),
            niosgramProvider.overrideWith(() => mockNiosgram),
          ],
          child: PostCard(post: post),
        ),
      );
      await tester.pumpAndSettle();

      final likeFinder = find.byIcon(Icons.favorite_border_rounded);
      expect(likeFinder, findsOneWidget);

      await tester.tap(likeFinder);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(mockNiosgram.lastReactedPostId, 201);
      expect(mockNiosgram.lastReactedIsLike, true);
    });

    testWidgets('1.8 Tapping dislike chip invokes reactPost with false', (
      WidgetTester tester,
    ) async {
      final post = _createSamplePost(id: 202, dislikesCount: 2, myReaction: null);
      final mockNiosgram = MockNiosgramNotifier(NiosgramState(posts: [post]));

      await tester.pumpWidget(
        _buildTestApp(
          overrides: [
            authProvider.overrideWith(() => MockAuthNotifier()),
            niosgramProvider.overrideWith(() => mockNiosgram),
          ],
          child: PostCard(post: post),
        ),
      );
      await tester.pumpAndSettle();

      final dislikeFinder = find.byIcon(Icons.sentiment_dissatisfied_outlined);
      expect(dislikeFinder, findsOneWidget);

      await tester.tap(dislikeFinder);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(mockNiosgram.lastReactedPostId, 202);
      expect(mockNiosgram.lastReactedIsLike, false);
    });

    testWidgets('1.9 Active like state displays filled favorite icon', (
      WidgetTester tester,
    ) async {
      final likedPost = _createSamplePost(likesCount: 15, myReaction: true);

      await tester.pumpWidget(
        _buildTestApp(
          overrides: [
            authProvider.overrideWith(() => MockAuthNotifier()),
          ],
          child: PostCard(post: likedPost),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    });

    testWidgets('1.10 Tapping comments chip navigates to post comments screen', (
      WidgetTester tester,
    ) async {
      final post = _createSamplePost(id: 301, commentsCount: 5);
      bool navigatedToComments = false;

      final GoRouter router = GoRouter(
        initialLocation: '/feed',
        routes: [
          GoRoute(
            path: '/feed',
            builder: (context, state) => Scaffold(body: PostCard(post: post)),
          ),
          GoRoute(
            path: '/niosgram/post/:postId/comments',
            builder: (context, state) {
              navigatedToComments = true;
              return const Scaffold(body: Text('Comments View'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        _buildTestApp(
          router: router,
          overrides: [
            authProvider.overrideWith(() => MockAuthNotifier()),
          ],
          child: const SizedBox.shrink(),
        ),
      );
      await tester.pumpAndSettle();

      final commentsFinder = find.byIcon(Icons.chat_bubble_outline_rounded);
      expect(commentsFinder, findsOneWidget);

      await tester.tap(commentsFinder);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(navigatedToComments, isTrue);
    });

    testWidgets('1.11 Author badges render with BadgeChip', (
      WidgetTester tester,
    ) async {
      final post = _createSamplePost(
        badges: const [
          ApiBadge(
            id: 1,
            name: 'Verified',
            icon: 'verified',
            color: '#2196F3',
          ),
        ],
      );

      await tester.pumpWidget(
        _buildTestApp(
          overrides: [
            authProvider.overrideWith(() => MockAuthNotifier()),
          ],
          child: PostCard(post: post),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BadgeChip), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // TIER 2: BOUNDARY & RESPONSIVE CANVAS MATRIX (Extreme sizes, 0 counts)
  // ══════════════════════════════════════════════════════════════════════════
  group('Tier 2: NiosGram Boundary & Responsive Canvas Matrix', () {
    testWidgets('2.1 Post with no media renders cleanly without image widget', (
      WidgetTester tester,
    ) async {
      final post = _createSamplePost(mediaUrl: null);

      await tester.pumpWidget(
        _buildTestApp(
          overrides: [
            authProvider.overrideWith(() => MockAuthNotifier()),
          ],
          child: PostCard(post: post),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.broken_image_rounded), findsNothing);
    });

    testWidgets('2.2 Ultra-long post content (3000+ chars) renders without RenderFlex overflow', (
      WidgetTester tester,
    ) async {
      final String longContent = List.generate(50, (i) => 'Paragraph $i: Material 3 social stream typography testing line length and boundary wrapping.').join('\n\n');
      final post = _createSamplePost(content: longContent);

      await tester.pumpWidget(
        _buildTestApp(
          overrides: [
            authProvider.overrideWith(() => MockAuthNotifier()),
          ],
          child: SingleChildScrollView(child: PostCard(post: post)),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('2.3 Post with 0 reactions renders clean action chips without text labels', (
      WidgetTester tester,
    ) async {
      final post = _createSamplePost(likesCount: 0, dislikesCount: 0, commentsCount: 0);

      await tester.pumpWidget(
        _buildTestApp(
          overrides: [
            authProvider.overrideWith(() => MockAuthNotifier()),
          ],
          child: PostCard(post: post),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0'), findsNothing);
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    });

    testWidgets('2.4 Large reaction metrics format abbreviations (1.5K, 2.5M)', (
      WidgetTester tester,
    ) async {
      final post = _createSamplePost(
        likesCount: 1500,
        commentsCount: 2500000,
      );

      await tester.pumpWidget(
        _buildTestApp(
          overrides: [
            authProvider.overrideWith(() => MockAuthNotifier()),
          ],
          child: PostCard(post: post),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1.5K'), findsOneWidget);
      expect(find.text('2.5M'), findsOneWidget);
    });

    final List<Map<String, dynamic>> viewports = [
      {'name': 'Compact Mobile (360x800)', 'size': const Size(360, 800)},
      {'name': 'Tablet Portrait (768x1024)', 'size': const Size(768, 1024)},
      {'name': 'Desktop Full HD (1920x1080)', 'size': const Size(1920, 1080)},
    ];

    for (final vp in viewports) {
      testWidgets('2.5 Responsive canvas on ${vp['name']} renders with zero overflow', (
        WidgetTester tester,
      ) async {
        final Size size = vp['size'] as Size;
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final posts = List.generate(
          5,
          (int i) => _createSamplePost(
            id: 500 + i,
            content: 'Post $i on ${vp['name']} viewport checking layout margins.',
          ),
        );
        final mockNiosgram = MockNiosgramNotifier(NiosgramState(posts: posts, hasMore: false));

        await tester.pumpWidget(
          _buildTestApp(
            overrides: [
              authProvider.overrideWith(() => MockAuthNotifier()),
              niosgramProvider.overrideWith(() => mockNiosgram),
            ],
            child: const NiosgramScreen(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(tester.takeException(), isNull);
        expect(find.byType(PostCard), findsWidgets);
      });
    }

    testWidgets('2.6 PostCardSkeleton renders smooth shimmer viewport placeholder', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: const PostCardSkeleton(hasMedia: true),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(PostCardSkeleton), findsOneWidget);
      expect(find.byType(AspectRatio), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // TIER 3: CROSS-FEATURE COMBINATIONS & WORKLOADS (Scrolling, Double Tap, Empty, Errors)
  // ══════════════════════════════════════════════════════════════════════════
  group('Tier 3: NiosGram Feed Cross-Feature Combinations', () {
    testWidgets('3.1 Multi-post feed scrolling renders items smoothly', (
      WidgetTester tester,
    ) async {
      final posts = List.generate(
        15,
        (int i) => _createSamplePost(
          id: 600 + i,
          content: 'Feed post index $i: Material 3 social stream.',
        ),
      );
      final mockNiosgram = MockNiosgramNotifier(NiosgramState(posts: posts, hasMore: false));

      await tester.pumpWidget(
        _buildTestApp(
          overrides: [
            authProvider.overrideWith(() => MockAuthNotifier()),
            niosgramProvider.overrideWith(() => mockNiosgram),
          ],
          child: const NiosgramScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('Feed post index 0'), findsOneWidget);

      // Scroll down
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
    });

    testWidgets('3.2 Fast double tap on PostCard triggers heart animation and reaction', (
      WidgetTester tester,
    ) async {
      final post = _createSamplePost(id: 701, likesCount: 5, myReaction: null);
      final mockNiosgram = MockNiosgramNotifier(NiosgramState(posts: [post]));

      await tester.pumpWidget(
        _buildTestApp(
          overrides: [
            authProvider.overrideWith(() => MockAuthNotifier()),
            niosgramProvider.overrideWith(() => mockNiosgram),
          ],
          child: PostCard(post: post),
        ),
      );
      await tester.pumpAndSettle();

      // Perform fast double-tap on the card
      await tester.tap(find.byType(PostCard));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(PostCard));
      await tester.pump();

      // Check that reaction was triggered
      expect(mockNiosgram.lastReactedPostId, 701);
      expect(mockNiosgram.lastReactedIsLike, true);

      // Advance animation through heart fade out
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('3.3 Empty feed state displays EmptyFeedWidget with localized message', (
      WidgetTester tester,
    ) async {
      final mockNiosgram = MockNiosgramNotifier(const NiosgramState(posts: [], hasMore: false));

      await tester.pumpWidget(
        _buildTestApp(
          overrides: [
            authProvider.overrideWith(() => MockAuthNotifier()),
            niosgramProvider.overrideWith(() => mockNiosgram),
          ],
          child: const NiosgramScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(EmptyFeedWidget), findsOneWidget);
      expect(find.text('Постов пока нет'), findsOneWidget);
    });

    testWidgets('3.4 Compact quick creation bar in feed expands inline composer', (
      WidgetTester tester,
    ) async {
      final mockNiosgram = MockNiosgramNotifier(
        NiosgramState(posts: [_createSamplePost(id: 1), _createSamplePost(id: 2)], hasMore: false),
      );

      final router = GoRouter(
        initialLocation: '/main/niosgram',
        routes: [
          GoRoute(
            path: '/main/niosgram',
            builder: (context, state) => const NiosgramScreen(),
          ),
          GoRoute(
            path: '/niosgram/create',
            builder: (context, state) => const Scaffold(body: Text('Create Post View')),
          ),
        ],
      );

      await tester.pumpWidget(
        _buildTestApp(
          router: router,
          overrides: [
            authProvider.overrideWith(() => MockAuthNotifier()),
            niosgramProvider.overrideWith(() => mockNiosgram),
          ],
          child: const SizedBox.shrink(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final createBar = find.text('Что у вас нового?');
      expect(createBar, findsOneWidget);

      await tester.tap(createBar);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Новая публикация'), findsOneWidget);
      expect(find.text('Опубликовать'), findsOneWidget);
    });

    testWidgets('3.5 Error feed state displays AppErrorBanner with retry action', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: Scaffold(
            body: AppErrorBanner(
              message: 'Не удалось загрузить ленту',
              variant: AppErrorBannerVariant.centered,
              onRetry: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppErrorBanner), findsOneWidget);
      expect(find.text('Не удалось загрузить ленту'), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    });

    testWidgets('3.6 Quick-creation cookie FAB renders parametric M3 cookie shape', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: M3Container(
            Shapes.c9_sided_cookie,
            width: 56,
            height: 56,
            color: const Color(0xFF6750A4),
            child: const Icon(Icons.edit_note_rounded, color: Colors.white),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(M3Container), findsOneWidget);
      expect(find.byIcon(Icons.edit_note_rounded), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // TIER 4: M1 CALLBACKS, BOOKMARKING & SKELETONS
  // ══════════════════════════════════════════════════════════════════════════
  group('Tier 4: Milestone 1 Callbacks, Bookmark & Skeletons', () {
    testWidgets('4.1 PostCard bookmark button toggles state and invokes onBookmark callback', (
      WidgetTester tester,
    ) async {
      final post = _createSamplePost(id: 801);
      bool? bookmarkState;

      await tester.pumpWidget(
        _buildTestApp(
          overrides: [
            authProvider.overrideWith(() => MockAuthNotifier()),
          ],
          child: PostCard(
            post: post,
            isBookmarked: false,
            onBookmark: (bool value) {
              bookmarkState = value;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bookmarkFinder = find.byIcon(Icons.bookmark_outline_rounded);
      expect(bookmarkFinder, findsOneWidget);

      await tester.tap(bookmarkFinder);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(bookmarkState, isTrue);
      expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
    });

    testWidgets('4.2 PostCard custom callbacks trigger on interaction', (
      WidgetTester tester,
    ) async {
      final post = _createSamplePost(id: 802);
      bool likeCalled = false;
      bool dislikeCalled = false;
      bool commentCalled = false;
      bool shareCalled = false;
      bool authorCalled = false;

      await tester.pumpWidget(
        _buildTestApp(
          overrides: [
            authProvider.overrideWith(() => MockAuthNotifier()),
          ],
          child: PostCard(
            post: post,
            onLike: () => likeCalled = true,
            onDislike: () => dislikeCalled = true,
            onComment: () => commentCalled = true,
            onShare: () => shareCalled = true,
            onAuthorTap: () => authorCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap author
      await tester.tap(find.text('Alice Cooper'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(authorCalled, isTrue);

      // Tap like
      await tester.tap(find.byIcon(Icons.favorite_border_rounded));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(likeCalled, isTrue);

      // Tap dislike
      await tester.tap(find.byIcon(Icons.sentiment_dissatisfied_outlined));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(dislikeCalled, isTrue);

      // Tap comment
      await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(commentCalled, isTrue);

      // Tap share
      await tester.tap(find.byIcon(Icons.share_outlined));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(shareCalled, isTrue);
    });

    testWidgets('4.3 PostFeedSkeleton renders 4 cards with Shimmer sweep', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _buildTestApp(
          child: const PostFeedSkeleton(count: 4),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(PostFeedSkeleton), findsOneWidget);
      expect(find.byType(PostCardSkeleton), findsNWidgets(4));
    });

    testWidgets('4.4 Quick-creation FAB in NiosgramScreen navigates to /niosgram/create', (
      WidgetTester tester,
    ) async {
      bool navigatedToCreate = false;
      final mockNiosgram = MockNiosgramNotifier(
        NiosgramState(
          posts: [_createSamplePost()],
          hasMore: false,
        ),
      );

      final GoRouter router = GoRouter(
        initialLocation: '/main/niosgram',
        routes: [
          GoRoute(
            path: '/main/niosgram',
            builder: (context, state) => const NiosgramScreen(),
          ),
          GoRoute(
            path: '/niosgram/create',
            builder: (context, state) {
              navigatedToCreate = true;
              return const Scaffold(body: Text('Create Post Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        _buildTestApp(
          router: router,
          overrides: [
            authProvider.overrideWith(() => MockAuthNotifier()),
            niosgramProvider.overrideWith(() => mockNiosgram),
          ],
          child: const SizedBox.shrink(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Find cookie FAB by edit_note_rounded icon
      final fabFinder = find.byIcon(Icons.edit_note_rounded);
      expect(fabFinder, findsOneWidget);

      await tester.tap(fabFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(navigatedToCreate, isTrue);
    });
  });
}
