import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/models/api/post_model.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:pulse_flutter/providers/niosgram_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/core/storage/cache_service.dart';
import 'package:pulse_flutter/widgets/post_card.dart';
import 'package:universal_io/io.dart';

class _FeedAuthFixture extends AuthNotifier {
  @override
  AuthState build() => const AuthState.initial().copyWith(
    hydrated: true,
    session: const AuthSession(
      accessToken: 'fixture',
      userId: 1,
      username: 'fixture',
      displayName: 'Fixture',
    ),
  );
}

class MockWebSocketClient extends WebSocketClient {
  MockWebSocketClient()
    : super(baseUrl: 'wss://test', readToken: () => 'token');

  final List<Map<String, dynamic>> sentRequests = <Map<String, dynamic>>[];
  dynamic nextResponse;

  @override
  bool get isConnected => true;

  @override
  Stream<Map<String, dynamic>> get pushStream =>
      const Stream<Map<String, dynamic>>.empty();

  @override
  Future<dynamic> request(
    String action, {
    Map<String, dynamic>? payload,
    Duration timeout = const Duration(seconds: 10),
    int maxRetries = 2,
  }) async {
    sentRequests.add(<String, dynamic>{'action': action, 'payload': payload});
    if (action == 'get_feed') return <String, dynamic>{'posts': <dynamic>[]};
    return nextResponse ?? <String, dynamic>{'status': 'ok'};
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('niosgram_test_hive_');
    Hive.init(hiveDir.path);
    await const CacheService().ensureInitialized();
  });

  tearDownAll(() async {
    try {
      await Hive.close();
      if (hiveDir.existsSync()) await hiveDir.delete(recursive: true);
    } catch (_) {}
  });

  group('NgPost Model - Media & Reactions', () {
    test(
      'public feed cache strips account flags without changing live posts',
      () {
        final post = NgPost.fromJson({
          'id': 700,
          'content': 'Fixture',
          'my_reaction': 'like',
          'is_following': true,
          'poll': {
            'my_choices': [1],
            'correct': 1,
            'explanation': 'Fixture answer',
          },
        });
        final public = post.toPublicCacheJson();
        expect(public['my_reaction'], isNull);
        expect(public['is_following'], isFalse);
        expect(post.myReaction, isTrue);
        expect(post.isFollowing, isTrue);
      },
    );

    test(
      'legacy shared Hive feed cache never exposes the previous account flags',
      () async {
        final box = Hive.box<List<dynamic>>('feed_cache_box');
        await box.put('feed', [
          {
            'id': 701,
            'content': 'Fixture',
            'my_reaction': 'like',
            'is_following': true,
            'poll': {
              'my_choices': [1],
              'correct': 1,
              'explanation': 'Fixture answer',
            },
          },
        ]);
        try {
          final post = const CacheService().getCachedFeed().single;
          expect(post.id, 701);
          expect(post.myReaction, isNull);
          expect(post.isFollowing, isFalse);
          expect(post.poll!['my_choices'], isEmpty);
          expect(post.poll!.containsKey('correct'), isFalse);
        } finally {
          await box.clear();
        }
      },
    );

    test('parses multiple mediaUrls, aiTags, and mediaType correctly', () {
      final json = <String, dynamic>{
        'id': 101,
        'content': 'Check out these photos!',
        'media_urls': <String>[
          'https://example.com/photo1.jpg',
          'https://example.com/photo2.jpg',
          'https://example.com/photo3.jpg',
        ],
        'ai_tags': <String>['nature', 'sunset', 'mountain'],
        'media_type': 'image',
        'likes_count': 15,
        'dislikes_count': 2,
        'my_reaction': 'like',
        'comments_count': 4,
        'author': <String, dynamic>{
          'id': 7,
          'username': 'photographer',
          'display_name': 'Photo Pro',
        },
      };

      final post = NgPost.fromJson(json);

      expect(post.id, 101);
      expect(post.content, 'Check out these photos!');
      expect(post.mediaUrls.length, 3);
      expect(post.mediaUrls[0], 'https://example.com/photo1.jpg');
      expect(post.mediaUrl, 'https://example.com/photo1.jpg');
      expect(post.aiTags, <String>['nature', 'sunset', 'mountain']);
      expect(post.mediaType, 'image');
      expect(post.isVideo, false);
      expect(post.likesCount, 15);
      expect(post.dislikesCount, 2);
      expect(post.myReaction, true);
    });

    test('falls back to media_url and handles video mediaType', () {
      final json = <String, dynamic>{
        'id': 102,
        'content': 'Short clip',
        'media_url': 'https://example.com/video.mp4',
        'media_type': 'video',
        'likes': 42,
        'dislikes': 0,
        'my_reaction': null,
      };

      final post = NgPost.fromJson(json);
      expect(post.id, 102);
      expect(post.mediaUrl, 'https://example.com/video.mp4');
      expect(post.mediaUrls, <String>['https://example.com/video.mp4']);
      expect(post.isVideo, true);
      expect(post.likesCount, 42);
      expect(post.dislikesCount, 0);
      expect(post.myReaction, isNull);
    });
    test('parses backend media array with object dictionaries', () {
      final json = <String, dynamic>{
        'id': 103,
        'content': 'Post with backend media objects',
        'media_url': '/static/posts/1_first.jpg',
        'media': <dynamic>[
          <String, dynamic>{
            'url': '/static/posts/1_first.jpg',
            'path': 'posts/1_first.jpg',
          },
          <String, dynamic>{
            'url': '/static/posts/1_second.jpg',
            'path': 'posts/1_second.jpg',
          },
          <String, dynamic>{
            'url': '/static/posts/1_third.jpg',
            'path': 'posts/1_third.jpg',
          },
        ],
        'likes': 10,
        'dislikes': 0,
      };

      final post = NgPost.fromJson(json);
      expect(post.id, 103);
      expect(post.mediaUrls.length, 3);
      expect(post.mediaUrls[0], '/static/posts/1_first.jpg');
      expect(post.mediaUrls[1], '/static/posts/1_second.jpg');
      expect(post.mediaUrls[2], '/static/posts/1_third.jpg');
      expect(post.mediaUrl, '/static/posts/1_first.jpg');
    });
  });

  group('NiosgramNotifier - Reactive Reactions & Multimedia Creation', () {
    test('following state is read from the server author payload', () {
      final post = NgPost.fromJson({
        'id': 1,
        'author': {
          'id': 5,
          'username': 'fixture',
          'display_name': 'Fixture',
          'is_followed': true,
        },
      });
      expect(post.isFollowing, isTrue);
    });
    test('reactPost sends correct action and reaction payload', () async {
      final mockWs = MockWebSocketClient();
      mockWs.nextResponse = <String, dynamic>{
        'likes': 10,
        'dislikes': 1,
        'my_reaction': 'like',
      };

      final container = ProviderContainer(
        overrides: [
          webSocketClientProvider.overrideWithValue(mockWs),
          authProvider.overrideWith(_FeedAuthFixture.new),
        ],
      );
      addTearDown(container.dispose);

      await container.read(niosgramProvider.future);
      final notifier = container.read(niosgramProvider.notifier);
      await notifier.reactPost(10, true);

      final req = mockWs.sentRequests.firstWhere(
        (Map<String, dynamic> r) => r['action'] == 'react_post',
      );
      expect(req['action'], 'react_post');
      expect(req['payload']['post_id'], 10);
      expect(req['payload']['reaction'], 'like');
    });

    test('createPost sends string UUID upload_ids and ai_tags', () async {
      final mockWs = MockWebSocketClient();
      mockWs.nextResponse = <String, dynamic>{
        'message': 'Post created successfully',
        'post_id': 202,
      };

      final container = ProviderContainer(
        overrides: [
          webSocketClientProvider.overrideWithValue(mockWs),
          authProvider.overrideWith(_FeedAuthFixture.new),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(niosgramProvider.notifier);
      await notifier.createPost(
        'New post with UUID photos',
        uploadIds: <String>[
          'f47ac10b93bc44a8b7c938166d03227e',
          '9a8b7c6d5e4f3a2b1c0d',
        ],
        aiTags: ['sunset', 'mountain'],
      );

      final req = mockWs.sentRequests.firstWhere(
        (Map<String, dynamic> r) => r['action'] == 'create_post',
      );
      expect(req['action'], 'create_post');
      expect(req['payload']['content'], 'New post with UUID photos');
      expect(req['payload']['upload_ids'], <String>[
        'f47ac10b93bc44a8b7c938166d03227e',
        '9a8b7c6d5e4f3a2b1c0d',
      ]);
      expect(req['payload']['upload_id'], 'f47ac10b93bc44a8b7c938166d03227e');
      expect(req['payload']['ai_tags'], ['sunset', 'mountain']);
    });

    test('video duration reaches the server with the upload ID', () async {
      final mockWs = MockWebSocketClient()..nextResponse = {'post_id': 203};
      final container = ProviderContainer(
        overrides: [
          webSocketClientProvider.overrideWithValue(mockWs),
          authProvider.overrideWith(_FeedAuthFixture.new),
        ],
      );
      addTearDown(container.dispose);
      await container.read(niosgramProvider.future);
      await container
          .read(niosgramProvider.notifier)
          .createPost('', uploadIds: ['video-upload'], mediaDurations: [3.25]);
      final request = mockWs.sentRequests.firstWhere(
        (r) => r['action'] == 'create_post',
      );
      expect(request['payload']['media_durations'], [3.25]);
    });

    test(
      'malformed publication acknowledgement is not treated as success',
      () async {
        final mockWs = MockWebSocketClient()
          ..nextResponse = {'message': 'unknown'};
        final container = ProviderContainer(
          overrides: [
            webSocketClientProvider.overrideWithValue(mockWs),
            authProvider.overrideWith(_FeedAuthFixture.new),
          ],
        );
        addTearDown(container.dispose);
        await container.read(niosgramProvider.future);
        await expectLater(
          container
              .read(niosgramProvider.notifier)
              .createPost('This is a post'),
          throwsStateError,
        );
      },
    );

    test('createPost sends upload_ids and ai_tags', () async {
      final mockWs = MockWebSocketClient();
      mockWs.nextResponse = <String, dynamic>{
        'id': 201,
        'content': 'New post with 3 images',
        'media_urls': [
          'https://example.com/1.png',
          'https://example.com/2.png',
        ],
        'author': {'id': 1, 'username': 'testuser', 'display_name': 'Tester'},
      };

      final container = ProviderContainer(
        overrides: [
          webSocketClientProvider.overrideWithValue(mockWs),
          authProvider.overrideWith(_FeedAuthFixture.new),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(niosgramProvider.notifier);
      await notifier.createPost(
        'New post with 3 images',
        uploadIds: [101, 102, 103],
        aiTags: ['test', 'flutter'],
      );

      final req = mockWs.sentRequests.firstWhere(
        (Map<String, dynamic> r) => r['action'] == 'create_post',
      );
      expect(req['action'], 'create_post');
      expect(req['payload']['content'], 'New post with 3 images');
      expect(req['payload']['upload_ids'], [101, 102, 103]);
      expect(req['payload']['ai_tags'], ['test', 'flutter']);
    });
  });

  group('PostCard Widget - Carousel & Video Badge', () {
    testWidgets(
      'renders carousel indicator and counter when multiple mediaUrls present',
      (WidgetTester tester) async {
        final post = NgPost(
          id: 301,
          content: 'Post with multiple images',
          author: const ApiProfile(
            id: 1,
            username: 'author',
            displayName: 'Author Name',
            bio: '',
          ),
          createdAt: DateTime.now(),
          likesCount: 5,
          dislikesCount: 0,
          commentsCount: 2,
          mediaUrls: const <String>[
            'https://example.com/img1.png',
            'https://example.com/img2.png',
            'https://example.com/img3.png',
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(child: PostCard(post: post)),
              ),
            ),
          ),
        );

        // Should show page counter text "1/3"
        expect(find.text('1/3'), findsOneWidget);
      },
    );

    testWidgets('renders VIDEO badge when post is a video', (
      WidgetTester tester,
    ) async {
      final post = NgPost(
        id: 302,
        content: 'Check out this video',
        author: const ApiProfile(
          id: 1,
          username: 'author',
          displayName: 'Author Name',
          bio: '',
        ),
        createdAt: DateTime.now(),
        likesCount: 12,
        dislikesCount: 1,
        commentsCount: 0,
        mediaType: 'video',
        mediaUrls: const <String>['https://example.com/clip.mp4'],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: PostCard(post: post)),
            ),
          ),
        ),
      );

      expect(find.text('VIDEO'), findsOneWidget);
    });
  });
}
