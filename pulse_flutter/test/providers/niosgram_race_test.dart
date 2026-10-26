import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/core/storage/cache_service.dart';
import 'package:pulse_flutter/models/api/post_model.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/niosgram_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';

Map<String, dynamic> post(int id) => {
  'id': id,
  'content': 'Fixture $id',
  'likes': 0,
  'dislikes': 0,
  'created_at': '2026-10-26T00:00:00Z',
  'author': {'id': 5, 'username': 'fixture', 'display_name': 'Fixture'},
};

class _Auth extends AuthNotifier {
  bool loggingOut = false;
  @override
  bool get isLoggingOut => loggingOut;
  @override
  AuthState build() => const AuthState.initial().copyWith(
    session: const AuthSession(
      accessToken: 'one',
      userId: 1,
      username: 'one',
      displayName: 'One',
    ),
  );
  void switchAccount() => state = state.copyWith(
    session: const AuthSession(
      accessToken: 'two',
      userId: 2,
      username: 'two',
      displayName: 'Two',
    ),
  );
}

class _Cache extends CacheService {
  List<NgPost> saved = [];
  @override
  List<NgPost> getCachedFeed() => [];
  @override
  Future<void> saveFeed(List<NgPost> posts) async {
    saved = posts;
  }
}

class _Socket extends WebSocketClient {
  _Socket()
    : super(baseUrl: 'https://invalid.test', readToken: () => 'fixture');
  final events = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  @override
  Stream<Map<String, dynamic>> get pushStream => events.stream;
  Future<dynamic> Function(String, Map<String, dynamic>?)? response;
  @override
  Future<dynamic> request(
    String action, {
    Map<String, dynamic>? payload,
    Duration timeout = const Duration(seconds: 15),
    int maxRetries = 2,
  }) async {
    if (response != null) return response!(action, payload);
    return {
      'posts': [for (var id = 20; id > 0; id--) post(id)],
    };
  }

  void push(int id, {bool deleted = false}) => events.add({
    'action': deleted ? 'ng_post_deleted' : 'new_ng_post',
    'payload': deleted ? {'post_id': id} : post(id),
  });
  void disposeFixture() {
    events.close();
    close();
  }
}

void main() {
  group('NiosGram concurrent events', () {
    late _Socket socket;
    late _Cache cache;
    late ProviderContainer container;
    Future<NiosgramNotifier> start() async {
      socket = _Socket();
      cache = _Cache();
      container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_Auth.new),
          webSocketClientProvider.overrideWithValue(socket),
          cacheServiceProvider.overrideWithValue(cache),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(socket.disposeFixture);
      await container.read(niosgramProvider.future);
      return container.read(niosgramProvider.notifier);
    }

    test(
      'page response preserves intervening push and cannot resurrect deleted IDs',
      () async {
        final notifier = await start();
        final pending = Completer<dynamic>();
        socket.response = (_, _) => pending.future;
        final page = notifier.loadMore();
        socket.push(30);
        socket.push(19, deleted: true);
        pending.complete({
          'posts': [post(19), post(21)],
        });
        await page;
        final ids = container
            .read(niosgramProvider)
            .value!
            .posts
            .map((p) => p.id);
        expect(ids, containsAll([30, 21]));
        expect(ids, isNot(contains(19)));
        expect(ids.toSet().length, ids.length);
      },
    );
    test('failed page leaves new push and clears only loading state', () async {
      final notifier = await start();
      final pending = Completer<dynamic>();
      socket.response = (_, _) => pending.future;
      final page = notifier.loadMore();
      socket.push(30);
      pending.completeError(StateError('fixture failure'));
      await page;
      expect(container.read(niosgramProvider).value!.posts.first.id, 30);
      expect(container.read(niosgramProvider).value!.isLoadingMore, isFalse);
    });
    test(
      'refresh preserves a new post and reaction changed during the request',
      () async {
        final notifier = await start();
        final pending = Completer<dynamic>();
        socket.response = (action, _) async => action == 'get_feed'
            ? pending.future
            : {'likes': 1, 'dislikes': 0, 'my_reaction': 'like'};
        final refresh = notifier.refresh();
        socket.push(30);
        await notifier.reactPost(20, true);
        pending.complete({
          'posts': [post(20)],
        });
        await refresh;
        final state = container.read(niosgramProvider).value!;
        expect(state.posts.first.id, 30);
        expect(state.posts.singleWhere((p) => p.id == 20).myReaction, isTrue);
      },
    );
    test(
      'latest refresh wins even if an older response arrives later',
      () async {
        final notifier = await start();
        final pending = <Completer<dynamic>>[];
        socket.response = (_, _) {
          final job = Completer<dynamic>();
          pending.add(job);
          return job.future;
        };
        final first = notifier.refresh(), second = notifier.refresh();
        pending[1].complete({
          'posts': [post(42)],
        });
        await second;
        pending[0].complete({
          'posts': [post(41)],
        });
        await first;
        expect(container.read(niosgramProvider).value!.posts.map((p) => p.id), [
          42,
        ]);
      },
    );
    test(
      'older reaction acknowledgement cannot override the newer action',
      () async {
        final notifier = await start();
        final pending = <Completer<dynamic>>[];
        socket.response = (_, _) {
          final job = Completer<dynamic>();
          pending.add(job);
          return job.future;
        };
        final first = notifier.reactPost(20, true),
            second = notifier.reactPost(20, true);
        pending[1].complete({'likes': 0, 'dislikes': 0, 'my_reaction': null});
        await second;
        pending[0].complete({'likes': 1, 'dislikes': 0, 'my_reaction': 'like'});
        await first;
        final item = container.read(niosgramProvider).value!.posts.first;
        expect(item.myReaction, isNull);
        expect(item.likesCount, 0);
      },
    );
    test(
      'a failed reaction cannot resurrect a post deleted by a push',
      () async {
        final notifier = await start();
        final pending = Completer<dynamic>();
        socket.response = (_, _) => pending.future;
        final reaction = notifier.reactPost(20, true);
        socket.push(20, deleted: true);
        pending.completeError(StateError('fixture failure'));
        await reaction;
        expect(
          container.read(niosgramProvider).value!.posts.any((p) => p.id == 20),
          isFalse,
        );
      },
    );
    test(
      'production edit acknowledgement preserves post identity and metadata',
      () async {
        final notifier = await start();
        final original = container.read(niosgramProvider).value!.posts.first;
        socket.response = (_, _) async => {
          'message': 'Post edited successfully',
          'post_id': 20,
        };
        await notifier.editPost(20, 'Edited fixture');
        final item = container.read(niosgramProvider).value!.posts.first;
        expect(item.id, 20);
        expect(item.content, 'Edited fixture');
        expect(item.author.id, original.author.id);
        expect(item.createdAt, original.createdAt);
      },
    );
    test(
      'structured edit failure restores text instead of creating an empty card',
      () async {
        final notifier = await start();
        socket.response = (_, _) async => {'error': 'fixture denied'};
        await expectLater(
          notifier.editPost(20, 'Edited fixture'),
          throwsStateError,
        );
        final item = container.read(niosgramProvider).value!.posts.first;
        expect(item.id, 20);
        expect(item.content, 'Fixture 20');
      },
    );
    test(
      'failed edit keeps a reaction updated while the edit was pending',
      () async {
        final notifier = await start();
        final pending = Completer<dynamic>();
        socket.response = (action, _) => action == 'edit_post'
            ? pending.future
            : Future.value({'likes': 1, 'my_reaction': 'like'});
        final edit = notifier.editPost(20, 'Edited fixture');
        await notifier.reactPost(20, true);
        final failed = expectLater(edit, throwsStateError);
        pending.complete({'error': 'fixture denied'});
        await failed;
        final item = container.read(niosgramProvider).value!.posts.first;
        expect(item.content, 'Fixture 20');
        expect(item.myReaction, isTrue);
        expect(item.likesCount, 1);
      },
    );
    test(
      'failed refresh superseding a page never leaves pagination permanently busy',
      () async {
        final notifier = await start();
        final pagePending = Completer<dynamic>(),
            refreshPending = Completer<dynamic>();
        var calls = 0;
        socket.response = (_, _) =>
            ++calls == 1 ? pagePending.future : refreshPending.future;
        final page = notifier.loadMore();
        final refresh = notifier.refresh();
        final failure = expectLater(refresh, throwsStateError);
        refreshPending.completeError(StateError('fixture failure'));
        await failure;
        pagePending.complete({
          'posts': [post(21)],
        });
        await page;
        expect(container.read(niosgramProvider).value!.isLoadingMore, isFalse);
        socket.response = (_, _) async => {
          'posts': [post(22)],
        };
        await notifier.loadMore();
        expect(
          container.read(niosgramProvider).value!.posts.any((p) => p.id == 22),
          isTrue,
        );
      },
    );
    test('account switch fences the old pending page', () async {
      final notifier = await start();
      final pending = Completer<dynamic>();
      var calls = 0;
      socket.response = (_, _) => ++calls == 1
          ? pending.future
          : Future.value({
              'posts': [post(99)],
            });
      final page = notifier.loadMore();
      (container.read(authProvider.notifier) as _Auth).switchAccount();
      final nextAccount = container.read(niosgramProvider.future);
      expect(container.read(niosgramProvider).value?.posts ?? [], isEmpty);
      await nextAccount;
      pending.complete({
        'posts': [post(21)],
      });
      await page;
      expect(container.read(niosgramProvider).value!.posts.map((p) => p.id), [
        99,
      ]);
    });
    test(
      'confirmed logout ignores a pending ack and blocks new mutations',
      () async {
        final notifier = await start();
        final pending = Completer<dynamic>();
        socket.response = (_, _) => pending.future;
        final edit = notifier.editPost(20, 'Pending fixture');
        (container.read(authProvider.notifier) as _Auth).loggingOut = true;
        pending.complete({...post(20), 'content': 'Late server fixture'});
        await edit;
        expect(
          container.read(niosgramProvider).value!.posts.first.content,
          'Pending fixture',
        );
        var calls = 0;
        socket.response = (_, _) async {
          calls++;
          return {};
        };
        await notifier.createPost('Never send fixture');
        await notifier.editPost(20, 'Never edit fixture');
        await notifier.reactPost(20, true);
        await notifier.deletePost(20);
        await notifier.toggleFollow('fixture');
        await notifier.refresh();
        await notifier.loadMore();
        expect(calls, 0);
      },
    );
  });
}
