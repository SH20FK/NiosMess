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
  ) async => message(100);
  @override
  Future<void> mutate(
    String action,
    int channelId,
    int postId,
    int commentId, {
    String? content,
    String? reaction,
  }) async {
    throw StateError('Fixture server rejected action');
  }
}

void main() {
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
}
