import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/repositories/post_comments_repository.dart';

class _Auth extends AuthNotifier {
  void switchAccount(int id) => state = state.copyWith(
    session: AuthSession(
      accessToken: 'fixture-$id',
      userId: id,
      username: 'user$id',
      displayName: 'User $id',
    ),
  );
  @override
  AuthState build() => const AuthState.initial().copyWith(
    session: const AuthSession(
      accessToken: 'fixture',
      userId: 1,
      username: 'fixture',
      displayName: 'Test',
    ),
  );
}

ApiMessage message(int id) =>
    ApiMessage.fromJson({'id': id, 'sender_id': 1, 'content': 'Comment $id'});

class _Repository extends PostCommentsRepository {
  _Repository(super.ref);
  Completer<CommentsPage>? pending;
  Completer<ApiMessage>? pendingSend;
  Completer<ApiMessage?>? pendingMutation;
  int sends = 0;
  int mutations = 0;
  final cursors = <int>[];
  @override
  Future<CommentsPage> page(
    int channelId,
    int postId, {
    int afterId = 0,
  }) async {
    cursors.add(afterId);
    if (pending != null) {
      final value = pending!;
      pending = null;
      return value.future;
    }
    if (afterId == 0) return CommentsPage([message(1), message(2)], true);
    if (afterId == 2) return CommentsPage([message(3), message(4)], false);
    return const CommentsPage([], false);
  }

  @override
  Future<ApiMessage> send(
    int channelId,
    int postId,
    String content,
    int? replyToId,
  ) async {
    sends++;
    return pendingSend?.future ?? message(100);
  }

  @override
  Future<ApiMessage?> mutate(
    String action,
    int channelId,
    int postId,
    int commentId, {
    String? content,
    String? reaction,
  }) async {
    mutations++;
    if (pendingMutation != null) return pendingMutation!.future;
    throw StateError('Fixture server rejected action');
  }
}

void main() {
  Future<(ProviderContainer, _Repository, WebSocketClient)> fixture() async {
    final socket = WebSocketClient(
      baseUrl: 'https://fixture.invalid',
      readToken: () => null,
    );
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_Auth.new),
        webSocketClientProvider.overrideWithValue(socket),
        postCommentsRepositoryProvider.overrideWith(_Repository.new),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(socket.close);
    return (
      container,
      container.read(postCommentsRepositoryProvider) as _Repository,
      socket,
    );
  }

  test(
    'repeated send shares one pending write and one returned comment',
    () async {
      final (container, repository, _) = await fixture();
      final provider = postCommentsProvider(
        const PostCommentsArgs(channelId: 0, postId: 1),
      );
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);
      await container.read(provider.future);
      repository.pendingSend = Completer<ApiMessage>();
      final notifier = container.read(provider.notifier);
      final first = notifier.send('same text', replyToId: 2);
      final second = notifier.send('same text', replyToId: 2);
      expect(repository.sends, 1);
      repository.pendingSend!.complete(message(100));
      await Future.wait([first, second]);
      expect(
        container.read(provider).requireValue.where((item) => item.id == 100),
        hasLength(1),
      );
    },
  );

  test(
    'edit is immediate, rejects stale refresh, and rolls back on failure',
    () async {
      final (container, repository, _) = await fixture();
      final provider = postCommentsProvider(
        const PostCommentsArgs(channelId: 0, postId: 1),
      );
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);
      await container.read(provider.future);
      repository.pendingMutation = Completer<ApiMessage?>();
      final notifier = container.read(provider.notifier);
      final operation = notifier.editComment(1, 'edited');
      expect(container.read(provider).requireValue.first.content, 'edited');
      await notifier.refresh();
      expect(container.read(provider).requireValue.first.content, 'edited');
      repository.pendingMutation!.completeError(StateError('offline'));
      await expectLater(operation, throwsStateError);
      expect(container.read(provider).requireValue.first.content, 'Comment 1');
    },
  );

  test(
    'reaction result updates in place without a second page round trip',
    () async {
      final (container, repository, _) = await fixture();
      final provider = postCommentsProvider(
        const PostCommentsArgs(channelId: 0, postId: 1),
      );
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);
      await container.read(provider.future);
      repository.pendingMutation = Completer<ApiMessage?>();
      final notifier = container.read(provider.notifier);
      final first = notifier.react(1, 'like');
      final second = notifier.react(1, 'like');
      expect(repository.mutations, 1);
      repository.pendingMutation!.complete(
        message(1).copyWith(reactions: {'👍': 1}),
      );
      await Future.wait([first, second]);
      expect(container.read(provider).requireValue.first.reactions, {'👍': 1});
      expect(repository.cursors, [0]);
    },
  );

  test('a different comment action waits for the first operation', () async {
    final (container, repository, _) = await fixture();
    final provider = postCommentsProvider(
      const PostCommentsArgs(channelId: 0, postId: 1),
    );
    final sub = container.listen(provider, (_, _) {});
    addTearDown(sub.close);
    await container.read(provider.future);
    final firstResponse = Completer<ApiMessage?>();
    repository.pendingMutation = firstResponse;
    final notifier = container.read(provider.notifier);
    final first = notifier.react(1, 'like');
    final edit = notifier.editComment(1, 'changed after reaction');
    expect(repository.mutations, 1);
    final editResponse = Completer<ApiMessage?>();
    repository.pendingMutation = editResponse;
    firstResponse.complete(message(1).copyWith(reactions: {'👍': 1}));
    await first;
    await Future<void>.delayed(Duration.zero);
    expect(repository.mutations, 2);
    expect(
      container.read(provider).requireValue.first.content,
      'changed after reaction',
    );
    editResponse.complete(
      message(
        1,
      ).copyWith(content: 'changed after reaction', reactions: {'👍': 1}),
    );
    await edit;
    expect(container.read(provider).requireValue.first.reactions, {'👍': 1});
  });

  test(
    'sending after the first page never skips intervening comments',
    () async {
      late _Repository repo;
      final socket = WebSocketClient(
        baseUrl: 'https://fixture.invalid',
        readToken: () => null,
      );
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_Auth.new),
          webSocketClientProvider.overrideWithValue(socket),
          postCommentsRepositoryProvider.overrideWith(
            (ref) => repo = _Repository(ref),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(socket.close);
      const args = PostCommentsArgs(channelId: 0, postId: 1);
      final provider = postCommentsProvider(args);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      await container.read(provider.future);
      final notifier = container.read(provider.notifier);
      await notifier.send('new');
      await notifier.refresh();
      expect(container.read(provider).value!.map((m) => m.id), [1, 2, 100]);
      await notifier.loadMore();
      expect(repo.cursors.last, 2);
      expect(container.read(provider).value!.map((m) => m.id), [
        1,
        2,
        3,
        4,
        100,
      ]);
    },
  );
  test(
    'a failed delete preserves the existing comment and exposes the error',
    () async {
      final socket = WebSocketClient(
        baseUrl: 'https://fixture.invalid',
        readToken: () => null,
      );
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_Auth.new),
          webSocketClientProvider.overrideWithValue(socket),
          postCommentsRepositoryProvider.overrideWith(_Repository.new),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(socket.close);
      final provider = postCommentsProvider(
        const PostCommentsArgs(channelId: 0, postId: 1),
      );
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      await container.read(provider.future);
      await expectLater(
        container.read(provider.notifier).deleteComment(1),
        throwsStateError,
      );
      expect(container.read(provider).value!.map((m) => m.id), [1, 2]);
    },
  );
  test(
    'account switch discards a delayed page from the previous authenticated account',
    () async {
      late _Repository repo;
      final socket = WebSocketClient(
        baseUrl: 'https://fixture.invalid',
        readToken: () => null,
      );
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_Auth.new),
          webSocketClientProvider.overrideWithValue(socket),
          postCommentsRepositoryProvider.overrideWith(
            (ref) => repo = _Repository(ref),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(socket.close);
      final provider = postCommentsProvider(
        const PostCommentsArgs(channelId: 0, postId: 1),
      );
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);
      await container.read(provider.future);
      final pending = Completer<CommentsPage>();
      repo.pending = pending;
      final refresh = container.read(provider.notifier).refresh();
      (container.read(authProvider.notifier) as _Auth).switchAccount(2);
      await container.read(provider.future);
      pending.complete(CommentsPage([message(999)], false));
      await refresh;
      expect(container.read(provider).requireValue.map((m) => m.id), [1, 2]);
    },
  );
}
