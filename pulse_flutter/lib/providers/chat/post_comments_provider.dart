import 'package:pulse_flutter/repositories/post_comments_repository.dart';
import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/niosgram_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';

import 'chat_shared.dart';

class PostCommentsArgs {
  const PostCommentsArgs({required this.channelId, required this.postId});

  final int channelId;
  final int postId;

  @override
  bool operator ==(Object other) {
    return other is PostCommentsArgs &&
        other.channelId == channelId &&
        other.postId == postId;
  }

  @override
  int get hashCode => Object.hash(channelId, postId);
}

class PostCommentsNotifier extends AsyncNotifier<List<ApiMessage>> {
  PostCommentsNotifier(this._args);
  final PostCommentsArgs _args;
  bool hasMore = false;
  int? totalCount;
  bool loadingMore = false;
  bool _refreshing = false;
  bool _refreshAgain = false;
  int _revision = 0;
  int _accountEpoch = 0;
  final _pendingMutations = <int, Future<void>>{};
  final _mutationIntents = <(int, String, String?, String?), Future<void>>{};
  final _pendingSends = <(String, int?), Future<void>>{};
  final _attemptKeys = <(String, int?), String>{};
  bool _current(int epoch) =>
      ref.mounted &&
      epoch == _accountEpoch &&
      !ref.read(authProvider.notifier).isLoggingOut;
  int _cursor = 0;
  PostCommentsRepository get _repository =>
      ref.read(postCommentsRepositoryProvider);

  @override
  Future<List<ApiMessage>> build() async {
    final account = ref.watch(
      authProvider.select((s) => (s.session?.userId, s.session?.accessToken)),
    );
    final epoch = ++_accountEpoch;
    _pendingMutations.clear();
    _mutationIntents.clear();
    _pendingSends.clear();
    _revision++;
    _refreshing = false;
    _refreshAgain = false;
    loadingMore = false;
    hasMore = false;
    totalCount = null;
    _cursor = 0;
    // Do not resolve provider.future with a placeholder before page one loads.
    // A fresh loading value also clears the previous account's comments.
    state = const AsyncLoading();
    if (account.$1 == null || account.$2 == null || account.$2!.isEmpty) {
      return const <ApiMessage>[];
    }
    final timer = Timer.periodic(const Duration(seconds: 8), (_) {
      unawaited(refresh(silent: true));
    });
    final connected = ref.read(webSocketClientProvider).onConnected.listen((_) {
      unawaited(refresh(silent: true));
    });
    final changes = ref.read(webSocketClientProvider).pushStream.listen((
      event,
    ) {
      final payload = event['payload'];
      if (event['action'] == 'feed_comment_changed' &&
          payload is Map &&
          payload['channel_id'] == _args.channelId &&
          payload['post_id'] == _args.postId) {
        unawaited(refresh(silent: true));
      }
    });
    ref.onDispose(() {
      timer.cancel();
      connected.cancel();
      changes.cancel();
    });
    final page = await _repository.page(_args.channelId, _args.postId);
    if (!_current(epoch)) return const [];
    hasMore = page.hasMore;
    totalCount = page.totalCount;
    _cursor = page.messages.isEmpty ? 0 : page.messages.last.id;
    return page.messages;
  }

  Future<void> refresh({bool silent = false}) async {
    if (_refreshing || loadingMore) {
      _refreshAgain = true;
      return;
    }
    _refreshing = true;
    final epoch = _accountEpoch;
    final revision = _revision;
    try {
      final target = _cursor;
      final items = <ApiMessage>[];
      bool more;
      int? nextTotal;
      do {
        final page = await _repository.page(
          _args.channelId,
          _args.postId,
          afterId: items.isEmpty ? 0 : items.last.id,
        );
        if (!_current(epoch)) return;
        items.addAll(page.messages);
        nextTotal = page.totalCount;
        more = page.hasMore && page.messages.isNotEmpty;
      } while (more && items.last.id < target);
      if (!_current(epoch) || revision != _revision) return;
      hasMore = more;
      totalCount = nextTotal;
      _cursor = items.isEmpty ? 0 : items.last.id;
      if (more) {
        items.addAll(
          (state.value ?? const <ApiMessage>[]).where((m) => m.id > _cursor),
        );
      }
      // A push/periodic refresh must not replace an in-flight local edit/delete.
      final pending = {
        for (final item in state.value ?? const <ApiMessage>[])
          if (_pendingMutations.containsKey(item.id)) item.id: item,
      };
      state = AsyncData([
        for (final item in items) pending[item.id] ?? item,
      ]);
    } catch (error, trace) {
      if (!silent &&
          _current(epoch) &&
          revision == _revision &&
          state.value == null) {
        state = AsyncError(error, trace);
      }
    } finally {
      if (_current(epoch)) {
        _refreshing = false;
        if (_refreshAgain && ref.mounted) {
          _refreshAgain = false;
          unawaited(refresh(silent: true));
        }
      }
    }
  }

  Future<void> loadMore() async {
    if (!hasMore || loadingMore || _refreshing) return;
    loadingMore = true;
    final epoch = _accountEpoch;
    try {
      final current = state.value ?? const <ApiMessage>[];
      final page = await _repository.page(
        _args.channelId,
        _args.postId,
        afterId: _cursor,
      );
      if (!_current(epoch)) return;
      final next = <int, ApiMessage>{
        for (final item in state.value ?? current) item.id: item,
      };
      for (final item in page.messages) {
        if (!_pendingMutations.containsKey(item.id)) next[item.id] = item;
      }
      hasMore = page.hasMore;
      totalCount = page.totalCount;
      if (page.messages.isNotEmpty) _cursor = page.messages.last.id;
      state = AsyncData(next.values.toList()..sort(compareMessages));
    } finally {
      if (_current(epoch)) {
        loadingMore = false;
        if (_refreshAgain && ref.mounted) {
          _refreshAgain = false;
          unawaited(refresh(silent: true));
        }
      }
    }
  }

  Future<void> send(String content, {int? replyToId}) {
    final text = content.trim();
    if (text.isEmpty) return Future.value();
    final key = (text, replyToId);
    final pending = _pendingSends[key];
    if (pending != null) return pending;
    late final Future<void> operation;
    operation = _send(text, replyToId: replyToId).whenComplete(() {
      if (identical(_pendingSends[key], operation)) _pendingSends.remove(key);
    });
    return _pendingSends[key] = operation;
  }

  Future<void> _send(String content, {int? replyToId}) async {
    final epoch = _accountEpoch;
    if (!_current(epoch)) throw StateError('COMMENT_ACCOUNT_CHANGED');
    // Idempotency: a retry of the same text after a lost response reuses the
    // key, so the server returns the original comment instead of a duplicate.
    final attempt = (content.trim(), replyToId);
    final String clientKey = _attemptKeys[attempt] ??= const Uuid().v4();
    if (_attemptKeys.length > 64) {
      _attemptKeys.remove(_attemptKeys.keys.first);
    }
    final created = await _repository.send(
      _args.channelId,
      _args.postId,
      content.trim(),
      replyToId,
      clientCommentId: clientKey,
    );
    if (!_current(epoch)) throw StateError('COMMENT_ACCOUNT_CHANGED');
    _attemptKeys.remove(attempt);
    _revision++;
    final exists = state.value?.any((item) => item.id == created.id) ?? false;
    if (totalCount != null && !exists) totalCount = totalCount! + 1;
    final next = <int, ApiMessage>{
      for (final item in state.value ?? const <ApiMessage>[]) item.id: item,
      created.id: created,
    };
    state = AsyncData(next.values.toList()..sort(compareMessages));
    if (_args.channelId == 0) ref.invalidate(niosgramProvider);
  }

  Future<void> deleteComment(int id) => _mutate('delete_post_comment', id);
  Future<void> editComment(int id, String content) =>
      _mutate('edit_post_comment', id, content: content);
  Future<void> react(int id, String reaction) =>
      _mutate('react_post_comment', id, reaction: reaction);
  Future<void> _mutate(
    String action,
    int id, {
    String? content,
    String? reaction,
  }) {
    final intent = (id, action, content, reaction);
    final identicalIntent = _mutationIntents[intent];
    if (identicalIntent != null) return identicalIntent;
    final pending = _pendingMutations[id];
    final epoch = _accountEpoch;
    Future<void> perform() {
      if (!_current(epoch)) throw StateError('COMMENT_ACCOUNT_CHANGED');
      return _performMutation(action, id, content: content, reaction: reaction);
    }
    late final Future<void> operation;
    final work = pending == null
        ? perform()
        : pending.then((_) {}, onError: (Object _, StackTrace _) {}).then((_) => perform());
    operation = work.whenComplete(() {
      if (identical(_mutationIntents[intent], operation)) {
        _mutationIntents.remove(intent);
      }
      if (identical(_pendingMutations[id], operation)) {
        _pendingMutations.remove(id);
      }
    });
    _mutationIntents[intent] = operation;
    return _pendingMutations[id] = operation;
  }

  Future<void> _performMutation(
    String action,
    int id, {
    String? content,
    String? reaction,
  }) async {
    final epoch = _accountEpoch;
    final before = state.value?.where((item) => item.id == id).firstOrNull;
    if (before == null || !_current(epoch)) return;
    final optimistic = action == 'edit_post_comment'
        ? before.copyWith(content: content, editedAt: DateTime.now())
        : action == 'delete_post_comment'
        ? before.copyWith(content: '', isDeleted: true)
        : before.copyWith(isSending: true);
    _revision++;
    state = AsyncData([
      for (final item in state.value ?? const <ApiMessage>[])
        item.id == id ? optimistic : item,
    ]);
    try {
      final confirmed = await _repository.mutate(
        action,
        _args.channelId,
        _args.postId,
        id,
        content: content,
        reaction: reaction,
      );
      if (!_current(epoch)) throw StateError('COMMENT_ACCOUNT_CHANGED');
      _revision++;
      if (confirmed != null && confirmed.id == id) {
        state = AsyncData([
          for (final item in state.value ?? const <ApiMessage>[])
            item.id == id ? confirmed : item,
        ]);
      } else {
        // Do not make the action wait for another full page round trip.
        if (action == 'react_post_comment') {
          state = AsyncData([
            for (final item in state.value ?? const <ApiMessage>[])
              item.id == id ? item.copyWith(isSending: false) : item,
          ]);
        }
        unawaited(refresh(silent: true));
      }
      if (_args.channelId == 0 && action == 'delete_post_comment') {
        ref.invalidate(niosgramProvider);
      }
    } catch (_) {
      if (_current(epoch)) {
        _revision++;
        state = AsyncData([
          for (final item in state.value ?? const <ApiMessage>[])
            item.id == id ? before : item,
        ]);
      }
      rethrow;
    }
  }
}

final postCommentsProvider = AsyncNotifierProvider.autoDispose
    .family<PostCommentsNotifier, List<ApiMessage>, PostCommentsArgs>(
      PostCommentsNotifier.new,
    );
