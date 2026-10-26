import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/core/storage/cache_service.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:pulse_flutter/models/api/post_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/screens/feed_post_screen.dart';
import 'package:pulse_flutter/widgets/post_card.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState.initial().copyWith(
    hydrated: true,
    session: const AuthSession(
      accessToken: 'fixture',
      userId: 7,
      username: 'fixture',
      displayName: 'Fixture',
    ),
    profile: const ApiProfile(
      id: 7,
      username: 'fixture',
      displayName: 'Fixture',
      bio: '',
    ),
  );
}

class _Settings extends UiSettingsNotifier {
  @override
  UiSettingsState build() => const UiSettingsState.defaults().copyWith(
    haptics: false,
    soundEffects: false,
  );
}

class _Cache extends CacheService {
  @override
  List<NgPost> getCachedFeed() => [];
  @override
  Future<void> saveFeed(List<NgPost> _) async {}
}

class _Socket extends WebSocketClient {
  _Socket()
    : super(baseUrl: 'https://invalid.test', readToken: () => 'fixture');
  String content = 'Shared fixture';
  bool liked = false, deleted = false, failEdit = false;
  int detailReads = 0, feedReads = 0, editCalls = 0, deleteCalls = 0;
  final initialFeed = Completer<dynamic>();
  @override
  Future<dynamic> request(
    String action, {
    Map<String, dynamic>? payload,
    Duration timeout = const Duration(seconds: 15),
    int maxRetries = 2,
  }) async {
    if (action == 'get_feed') {
      feedReads++;
      return initialFeed.future;
    }
    if (action == 'get_feed_post') {
      detailReads++;
      return {
        'posts': deleted
            ? []
            : [
                {
                  'id': 42,
                  'content': content,
                  'likes': liked ? 1 : 0,
                  'my_reaction': liked ? 'like' : null,
                  'author': {
                    'id': 7,
                    'username': 'fixture',
                    'display_name': 'Fixture',
                  },
                  'created_at': '2026-10-26T00:00:00Z',
                },
              ],
      };
    }
    if (action == 'react_post') {
      liked = !liked;
      return {'likes': liked ? 1 : 0, 'my_reaction': liked ? 'like' : null};
    }
    if (action == 'edit_post') {
      editCalls++;
      if (failEdit) return {'error': 'fixture denied'};
      content = payload!['content'] as String;
      return {'post_id': 42, 'message': 'Post edited successfully'};
    }
    if (action == 'delete_post') {
      deleteCalls++;
      deleted = true;
      return {'message': 'Post deleted successfully'};
    }
    throw StateError('Unexpected fixture request: $action');
  }
}

void main() {
  group('shared post route independent of loaded feed', () {
    late _Socket socket;
    late GoRouter router;
    Future<void> open(WidgetTester tester) async {
      socket = _Socket();
      router = GoRouter(
        initialLocation: '/niosgram/post/42',
        routes: [
          GoRoute(
            path: '/niosgram/post/:id',
            builder: (_, _) => const FeedPostScreen(postId: 42),
          ),
          GoRoute(
            path: '/main/niosgram',
            builder: (_, _) => const Scaffold(body: Text('Feed destination')),
          ),
        ],
      );
      addTearDown(router.dispose);
      addTearDown(socket.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(_Auth.new),
            uiSettingsProvider.overrideWith(_Settings.new),
            webSocketClientProvider.overrideWithValue(socket),
            cacheServiceProvider.overrideWithValue(_Cache()),
          ],
          child: MaterialApp.router(
            locale: const Locale('en'),
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PostCard), findsOneWidget);
      expect(tester.widget<PostCard>(find.byType(PostCard)).post.author.id, 7);
      expect(socket.feedReads, 0);
    }

    testWidgets(
      'like updates the visible shared card using only its detail refresh',
      (tester) async {
        await open(tester);
        await tester.tap(find.byIcon(Icons.favorite_border_rounded));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        expect(socket.liked, isTrue);
        expect(socket.detailReads, 2);
        expect(
          tester.widget<PostCard>(find.byType(PostCard)).post.myReaction,
          isTrue,
        );
        expect(socket.feedReads, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets(
      'successful edit acknowledgement refreshes the displayed post without a loaded global feed',
      (tester) async {
        await open(tester);
        await tester.tap(find.byIcon(Icons.more_horiz_rounded));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Edited shared fixture');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(socket.editCalls, 1);
        expect(find.byType(TextField), findsNothing);
        expect(
          tester.widget<PostCard>(find.byType(PostCard)).post.content,
          'Edited shared fixture',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets('failed edit keeps the typed draft and edit sheet open', (
      tester,
    ) async {
      await open(tester);
      socket.failEdit = true;
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Unsaved fixture');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(socket.editCalls, 1);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Unsaved fixture',
      );
      expect(socket.content, 'Shared fixture');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets(
      'confirmed deletion reaches the API and leaves a deleted shared route',
      (tester) async {
        await open(tester);
        await tester.tap(find.byIcon(Icons.more_horiz_rounded));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete').last);
        await tester.pumpAndSettle();
        expect(socket.deleteCalls, 1);
        expect(find.text('Feed destination'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });
}
