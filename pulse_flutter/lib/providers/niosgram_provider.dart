import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/storage/cache_service.dart';
import 'package:pulse_flutter/core/utils/shared_utilities.dart';
import 'package:pulse_flutter/providers/notifications_provider.dart';
import 'package:pulse_flutter/models/api/post_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';

class NiosgramState {
  const NiosgramState({
    this.posts = const <NgPost>[],
    this.isLoadingMore = false,
    this.hasMore = true,
    this.page = 1,
  });

  final List<NgPost> posts;
  final bool isLoadingMore;
  final bool hasMore;
  final int page;

  NiosgramState copyWith({
    List<NgPost>? posts,
    bool? isLoadingMore,
    bool? hasMore,
    int? page,
  }) => NiosgramState(
    posts: posts ?? this.posts,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    hasMore: hasMore ?? this.hasMore,
    page: page ?? this.page,
  );
}

class NiosgramNotifier extends AsyncNotifier<NiosgramState> {
  int _epoch = 0, _pageRevision = 0;
  int? _account;
  bool _refreshing = false;
  final _deletedIds = <int>{};
  final _mutations = <String, int>{};
  bool _current(int epoch) =>
      ref.mounted &&
      epoch == _epoch &&
      !ref.read(authProvider.notifier).isLoggingOut;
  int _operationCounter = 0;
  int _mutation(String key) {
    final revision = _mutations[key] = ++_operationCounter;
    while (_mutations.length > 4096) {
      _mutations.remove(_mutations.keys.first);
    }
    return revision;
  }

  bool _validMutation(int epoch, String key, int revision) =>
      _current(epoch) && _mutations[key] == revision;
  void _rememberDeletion(int id) {
    _deletedIds.add(id);
    while (_deletedIds.length > 4096) {
      _deletedIds.remove(_deletedIds.first);
    }
  }

  List<NgPost> _preserveChanges(
    List<NgPost> fresh,
    List<NgPost> before,
    List<NgPost> live,
  ) {
    final baseline = {for (final item in before) item.id: item};
    final currentIds = live.map((item) => item.id).toSet();
    final removed = baseline.keys
        .where((id) => !currentIds.contains(id))
        .toSet();
    final changed = live
        .where((item) => !identical(baseline[item.id], item))
        .toList();
    final changedIds = changed.map((item) => item.id).toSet();
    return [
      ...changed.where((item) => !_deletedIds.contains(item.id)),
      ...fresh.where(
        (item) =>
            !_deletedIds.contains(item.id) &&
            !removed.contains(item.id) &&
            !changedIds.contains(item.id),
      ),
    ];
  }

  @override
  Future<NiosgramState> build() async {
    final session = ref.watch(
      authProvider.select((a) => (a.session?.userId, a.session?.accessToken)),
    );
    if (_account != null && _account != session.$1) {
      // A loading transition alone retains the old account's personalized feed.
      // Clear its value before starting the new account's pending future.
      state = const AsyncData<NiosgramState>(NiosgramState());
      state = const AsyncLoading<NiosgramState>();
    }
    _account = session.$1;
    final epoch = ++_epoch;
    _pageRevision++;
    _deletedIds.clear();
    _mutations.clear();
    _refreshing = false;
    final subscription = ref.read(webSocketClientProvider).pushStream.listen((
      event,
    ) {
      if (_current(epoch)) _handlePush(event);
    });
    ref.onDispose(() {
      if (epoch == _epoch) _epoch++;
      subscription.cancel();
    });

    final CacheService cache = ref.read(cacheServiceProvider);
    final List<NgPost> cached = cache.getCachedFeed();
    if (cached.isNotEmpty) {
      state = AsyncData<NiosgramState>(
        NiosgramState(posts: cached, page: 1, hasMore: cached.length >= 20),
      );
    }

    try {
      final revision = _pageRevision;
      final List<NgPost> freshPosts = await _fetchPage(1);
      if (!_current(epoch)) return const NiosgramState();
      if (revision != _pageRevision) {
        return state.value ?? const NiosgramState();
      }
      final List<NgPost> reconciled = _reconcilePosts(
        cached,
        freshPosts,
      ).where((item) => !_deletedIds.contains(item.id)).toList();
      await cache.saveFeed(reconciled);
      if (!_current(epoch)) return const NiosgramState();
      return NiosgramState(
        posts: reconciled,
        page: 1,
        hasMore: freshPosts.length >= 20,
      );
    } catch (e) {
      if (!_current(epoch)) return const NiosgramState();
      debugPrint('[niosgram_provider] FEED_FETCH_FAILED: ${e.runtimeType}');
      if (cached.isNotEmpty) {
        return NiosgramState(
          posts: cached,
          page: 1,
          hasMore: cached.length >= 20,
        );
      }
      rethrow;
    }
  }

  List<NgPost> _reconcilePosts(List<NgPost> cached, List<NgPost> fresh) {
    if (fresh.isEmpty) return cached;
    if (cached.isEmpty) return fresh;

    final Set<int> freshIds = fresh.map((NgPost p) => p.id).toSet();
    final List<NgPost> olderPosts = cached
        .where((NgPost p) => !freshIds.contains(p.id))
        .toList(growable: false);

    return <NgPost>[...fresh, ...olderPosts];
  }

  Future<List<NgPost>> _fetchPage(int page) async {
    final dynamic response = await ref
        .read(webSocketClientProvider)
        .request('get_feed', payload: <String, dynamic>{'page': page});
    final dynamic posts = response is Map ? response['posts'] : response;
    if (response is Map && response['error'] != null) {
      throw StateError('feed_request_failed');
    }
    if (posts is! List) return <NgPost>[];
    return posts
        .whereType<Map>()
        .map(
          (Map item) => NgPost.fromJson(
            item.map((dynamic k, dynamic v) => MapEntry(k.toString(), v)),
          ),
        )
        .toList(growable: false);
  }

  void _handlePush(dynamic event) {
    if (event is! Map) return;
    final Map<String, dynamic> msg = asStringMap(event);
    final String action = (msg['action'] ?? '').toString();

    // Check for deleted post push
    if (action == 'delete_ng_post' ||
        action == 'ng_post_deleted' ||
        action == 'delete_post') {
      final dynamic data = msg['payload'] ?? msg['data'] ?? msg;
      final int? postId = (data is Map)
          ? ((data['post_id'] as num?)?.toInt() ??
                (data['id'] as num?)?.toInt())
          : null;
      if (postId != null) {
        _rememberDeletion(postId);
        _mutation('delete:$postId');
        final AsyncData<NiosgramState>? current = state.asData;
        if (current != null) {
          final List<NgPost> filtered = current.value.posts
              .where((NgPost p) => p.id != postId)
              .toList(growable: false);
          state = AsyncData<NiosgramState>(
            current.value.copyWith(posts: filtered),
          );
          ref.read(cacheServiceProvider).saveFeed(filtered);
        }
      }
      return;
    }

    if (action != 'new_ng_post') return;
    final dynamic data = msg['payload'] ?? msg['data'];
    if (data is! Map) return;
    final NgPost post = NgPost.fromJson(
      data.map((dynamic k, dynamic v) => MapEntry(k.toString(), v)),
    );
    if (_deletedIds.contains(post.id)) return;
    final AsyncData<NiosgramState>? current = state.asData;
    if (current == null) return;
    final List<NgPost> updated = <NgPost>[
      post,
      ...current.value.posts.where((NgPost p) => p.id != post.id),
    ];
    state = AsyncData<NiosgramState>(current.value.copyWith(posts: updated));
    ref.read(cacheServiceProvider).saveFeed(updated);

    final String myUsername = ref.read(authProvider).session?.username ?? '';
    if (myUsername.isNotEmpty && post.content.contains('@$myUsername')) {
      final String authorName = post.author.displayName.isNotEmpty
          ? post.author.displayName
          : post.author.username;
      ref.read(notificationsProvider.notifier).accept({
        'event_id': 'mention:${post.id}:$myUsername',
        'type': 'post_comment',
        'title': 'NiosGram',
        'body': '$authorName: ${post.content}',
        'route': '/niosgram/post/${post.id}/comments',
      });
    }
  }

  Future<void> refresh() async {
    final epoch = _epoch, revision = ++_pageRevision;
    if (!_current(epoch)) return;
    final before = state.value?.posts ?? const <NgPost>[];
    _refreshing = true;
    try {
      final fresh = await _fetchPage(1);
      if (!_current(epoch) || revision != _pageRevision) return;
      final merged = _preserveChanges(
        fresh,
        before,
        state.value?.posts ?? before,
      );
      state = AsyncData(
        NiosgramState(posts: merged, page: 1, hasMore: fresh.length >= 20),
      );
      await ref.read(cacheServiceProvider).saveFeed(merged);
    } finally {
      if (_current(epoch) && revision == _pageRevision) {
        _refreshing = false;
        final live = state.value;
        if (live != null && live.isLoadingMore) {
          state = AsyncData(live.copyWith(isLoadingMore: false));
        }
      }
    }
  }

  Future<void> loadMore() async {
    final current = state.asData;
    if (current == null ||
        current.value.isLoadingMore ||
        !current.value.hasMore ||
        _refreshing) {
      return;
    }
    final epoch = _epoch, revision = _pageRevision;
    if (!_current(epoch)) return;
    state = AsyncData(current.value.copyWith(isLoadingMore: true));
    final nextPage = current.value.page + 1;
    try {
      final more = await _fetchPage(nextPage);
      if (!_current(epoch) || revision != _pageRevision) return;
      final live = state.value ?? current.value;
      final ids = live.posts.map((item) => item.id).toSet();
      final combined = [
        ...live.posts,
        ...more.where(
          (item) => !ids.contains(item.id) && !_deletedIds.contains(item.id),
        ),
      ];
      state = AsyncData(
        live.copyWith(
          posts: combined,
          page: nextPage,
          hasMore: more.length >= 20,
          isLoadingMore: false,
        ),
      );
      await ref.read(cacheServiceProvider).saveFeed(combined);
    } catch (error) {
      if (!_current(epoch) || revision != _pageRevision) return;
      debugPrint('[niosgram_provider] FEED_PAGE_FAILED: ${error.runtimeType}');
      state = AsyncData(
        (state.value ?? current.value).copyWith(isLoadingMore: false),
      );
    }
  }

  Future<void> reactPost(int postId, bool isLike) async {
    final epoch = _epoch;
    if (!_current(epoch)) return;
    final key = 'react:$postId';
    final revision = _mutation(key);
    final current = state.asData ?? const AsyncData(NiosgramState());

    final NgPost? target = current.value.posts
        .where((NgPost p) => p.id == postId)
        .firstOrNull;
    final bool? prev = target?.myReaction;
    final bool? next = prev == isLike ? null : isLike;

    if (next == false) {
      // Disliked post: exclude immediately from user's feed
      final List<NgPost> filtered = current.value.posts
          .where((NgPost p) => p.id != postId)
          .toList(growable: false);
      state = AsyncData<NiosgramState>(current.value.copyWith(posts: filtered));
      ref.read(cacheServiceProvider).saveFeed(filtered);
    } else {
      // Optimistic update of single post card in-place without reloading feed
      final List<NgPost> updated = current.value.posts
          .map((NgPost p) {
            if (p.id != postId) return p;
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
          })
          .toList(growable: false);

      state = AsyncData<NiosgramState>(current.value.copyWith(posts: updated));
    }

    try {
      final dynamic response = await ref
          .read(webSocketClientProvider)
          .request(
            'react_post',
            payload: <String, dynamic>{
              'post_id': postId,
              'reaction': isLike ? 'like' : 'dislike',
              'is_like': isLike,
            },
          );
      if (!_validMutation(epoch, key, revision) ||
          _deletedIds.contains(postId)) {
        return;
      }
      if (response is Map && response['error'] != null) {
        throw StateError('reaction_failed');
      }
      if (response is Map) {
        final dynamic respPayload = response['payload'] ?? response;
        if (respPayload is Map) {
          final int? likes =
              respPayload['likes'] as int? ??
              respPayload['likes_count'] as int?;
          final int? dislikes =
              respPayload['dislikes'] as int? ??
              respPayload['dislikes_count'] as int?;
          final dynamic reactionRaw = respPayload['my_reaction'];
          bool? serverReaction;
          if (reactionRaw == 'like' || reactionRaw == true) {
            serverReaction = true;
          } else if (reactionRaw == 'dislike' || reactionRaw == false) {
            serverReaction = false;
          }

          final AsyncData<NiosgramState>? fresh = state.asData;
          if (fresh != null) {
            if (serverReaction == false) {
              // Ensure post remains excluded from feed if server confirms dislike
              final List<NgPost> withoutDisliked = fresh.value.posts
                  .where((NgPost p) => p.id != postId)
                  .toList(growable: false);
              state = AsyncData<NiosgramState>(
                fresh.value.copyWith(posts: withoutDisliked),
              );
              ref.read(cacheServiceProvider).saveFeed(withoutDisliked);
            } else {
              // Update only the post card in place
              final List<NgPost> synced = fresh.value.posts
                  .map((NgPost p) {
                    if (p.id != postId) return p;
                    return p.copyWith(
                      likesCount: likes ?? p.likesCount,
                      dislikesCount: dislikes ?? p.dislikesCount,
                      myReaction: () => serverReaction,
                    );
                  })
                  .toList(growable: false);
              state = AsyncData<NiosgramState>(
                fresh.value.copyWith(posts: synced),
              );
            }
          }
        }
      }
    } catch (e) {
      if (!_validMutation(epoch, key, revision) ||
          _deletedIds.contains(postId)) {
        return;
      }
      debugPrint('[niosgram_provider] REACTION_FAILED: ${e.runtimeType}');
      if (target != null) {
        final AsyncData<NiosgramState>? fresh = state.asData;
        if (fresh != null) {
          final bool exists = fresh.value.posts.any(
            (NgPost p) => p.id == postId,
          );
          final List<NgPost> reverted = exists
              ? fresh.value.posts
                    .map(
                      (NgPost p) => p.id == postId
                          ? p.copyWith(
                              likesCount: target.likesCount,
                              dislikesCount: target.dislikesCount,
                              myReaction: () => target.myReaction,
                            )
                          : p,
                    )
                    .toList(growable: false)
              : <NgPost>[...fresh.value.posts, target];
          state = AsyncData<NiosgramState>(
            fresh.value.copyWith(posts: reverted),
          );
        }
      }
    }
  }

  Future<void> createPost(
    String text, {
    dynamic uploadId,
    List<dynamic>? uploadIds,
    List<String>? aiTags,
    Map<String, dynamic>? poll,
  }) async {
    final epoch = _epoch;
    if (!_current(epoch)) return;
    final Map<String, dynamic> payload = <String, dynamic>{
      'content': text.trim(),
      'poll': ?poll,
    };
    final List<dynamic> effectiveUploadIds = <dynamic>[
      ...?uploadIds,
      if (uploadIds == null && uploadId != null) uploadId,
    ];
    if (effectiveUploadIds.isNotEmpty) {
      payload['upload_ids'] = effectiveUploadIds;
      payload['upload_id'] = effectiveUploadIds.first;
    }
    if (aiTags != null && aiTags.isNotEmpty) {
      payload['ai_tags'] = aiTags;
    }
    final dynamic response = await ref
        .read(webSocketClientProvider)
        .request('create_post', payload: payload);
    if (!_current(epoch)) return;
    if (response is! Map) return;
    if (response['error'] != null) {
      throw Exception(response['error'].toString());
    }

    final dynamic respData =
        response['payload'] ?? response['data'] ?? response;
    if (respData is Map &&
        respData['id'] != null &&
        respData['author'] != null) {
      final NgPost post = NgPost.fromJson(
        respData.map((dynamic k, dynamic v) => MapEntry(k.toString(), v)),
      );
      final AsyncData<NiosgramState>? current = state.asData;
      if (current != null) {
        final List<NgPost> updatedList = <NgPost>[
          post,
          ...current.value.posts.where((NgPost p) => p.id != post.id),
        ];
        if (!_current(epoch)) return;
        state = AsyncData<NiosgramState>(
          (state.value ?? current.value).copyWith(posts: updatedList),
        );
        ref.read(cacheServiceProvider).saveFeed(updatedList);
      }
    }

    try {
      final List<NgPost> freshPosts = await _fetchPage(1);
      if (!_current(epoch)) return;
      final AsyncData<NiosgramState>? current = state.asData;
      if (current != null && freshPosts.isNotEmpty) {
        final List<NgPost> reconciled = _reconcilePosts(
          current.value.posts,
          freshPosts,
        );
        state = AsyncData<NiosgramState>(
          (state.value ?? current.value).copyWith(
            posts: reconciled,
            page: 1,
            hasMore: freshPosts.length >= 20,
          ),
        );
        await ref.read(cacheServiceProvider).saveFeed(reconciled);
      }
    } catch (e) {
      debugPrint('[niosgram_provider] POST_REFRESH_FAILED: ${e.runtimeType}');
    }
  }

  Future<void> deletePost(int postId) async {
    final epoch = _epoch;
    if (!_current(epoch)) return;
    final key = 'delete:$postId';
    final revision = _mutation(key);
    final current = state.asData ?? const AsyncData(NiosgramState());
    _rememberDeletion(postId);
    final List<NgPost> filtered = current.value.posts
        .where((NgPost p) => p.id != postId)
        .toList(growable: false);
    state = AsyncData<NiosgramState>(current.value.copyWith(posts: filtered));
    ref.read(cacheServiceProvider).saveFeed(filtered);
    try {
      final response = await ref
          .read(webSocketClientProvider)
          .request(
            'delete_post',
            payload: <String, dynamic>{'post_id': postId},
          );
      if (response is Map && response['error'] != null) {
        throw StateError('delete_failed');
      }
    } catch (_) {
      if (!_validMutation(epoch, key, revision)) return;
      _deletedIds.remove(postId);
      final NgPost? originalPost = current.value.posts
          .where((p) => p.id == postId)
          .firstOrNull;
      if (originalPost != null) {
        final AsyncData<NiosgramState>? fresh = state.asData;
        if (fresh != null && !fresh.value.posts.any((p) => p.id == postId)) {
          final List<NgPost> reverted = <NgPost>[
            ...fresh.value.posts,
            originalPost,
          ];
          state = AsyncData<NiosgramState>(
            fresh.value.copyWith(posts: reverted),
          );
          ref.read(cacheServiceProvider).saveFeed(reverted);
        }
      }
      rethrow;
    }
  }

  Future<void> editPost(int postId, String text) async {
    final epoch = _epoch;
    if (!_current(epoch)) return;
    final key = 'edit:$postId';
    final revision = _mutation(key);
    final current = state.asData ?? const AsyncData(NiosgramState());
    final String trimmed = text.trim();
    final NgPost? originalPost = current.value.posts
        .where((p) => p.id == postId)
        .firstOrNull;
    state = AsyncData<NiosgramState>(
      current.value.copyWith(
        posts: current.value.posts
            .map(
              (NgPost p) => p.id == postId ? p.copyWith(content: trimmed) : p,
            )
            .toList(growable: false),
      ),
    );
    try {
      final dynamic response = await ref
          .read(webSocketClientProvider)
          .request(
            'edit_post',
            payload: <String, dynamic>{'post_id': postId, 'content': trimmed},
          );
      if (!_validMutation(epoch, key, revision) ||
          _deletedIds.contains(postId)) {
        return;
      }
      if (response is! Map || response['error'] != null) {
        throw StateError('edit_failed');
      }
      final payload = response['payload'] ?? response['data'] ?? response;
      if (payload is! Map || payload['error'] != null) {
        throw StateError('edit_failed');
      }
      // The production edit API acknowledges with post_id, not a full post.
      // Never turn that acknowledgement into an empty id=0 card.
      final id = (payload['id'] ?? payload['post_id']) as num?;
      if (id?.toInt() != postId) throw StateError('edit_id_mismatch');
      final fresh = state.asData;
      if (fresh != null) {
        final content = payload['content'] is String
            ? payload['content'] as String
            : trimmed;
        final posts = fresh.value.posts
            .map(
              (item) =>
                  item.id == postId ? item.copyWith(content: content) : item,
            )
            .toList(growable: false);
        state = AsyncData(fresh.value.copyWith(posts: posts));
        unawaited(ref.read(cacheServiceProvider).saveFeed(posts));
      }
    } catch (e) {
      if (!_validMutation(epoch, key, revision)) return;
      debugPrint('[niosgram_provider] EDIT_FAILED: ${e.runtimeType}');
      if (originalPost != null) {
        final AsyncData<NiosgramState>? fresh = state.asData;
        if (fresh != null) {
          final List<NgPost> reverted = fresh.value.posts
              .map(
                (NgPost p) => p.id == postId
                    ? p.copyWith(content: originalPost.content)
                    : p,
              )
              .toList(growable: false);
          state = AsyncData<NiosgramState>(
            fresh.value.copyWith(posts: reverted),
          );
        }
      }
      rethrow;
    }
  }

  Future<void> toggleFollow(String username) async {
    final epoch = _epoch;
    if (!_current(epoch)) return;
    final key = 'follow:$username';
    final revision = _mutation(key);
    final AsyncData<NiosgramState>? current = state.asData;
    if (current == null) return;

    final NgPost? targetPost = current.value.posts
        .where((NgPost p) => p.author.username == username)
        .firstOrNull;
    if (targetPost == null) return;

    final bool wasFollowing = targetPost.isFollowing;
    final int userId = targetPost.author.id;

    final List<NgPost> updated = current.value.posts
        .map((NgPost p) {
          if (p.author.username != username) return p;
          return p.copyWith(isFollowing: !wasFollowing);
        })
        .toList(growable: false);
    state = AsyncData<NiosgramState>(current.value.copyWith(posts: updated));

    try {
      await ref
          .read(webSocketClientProvider)
          .request(
            wasFollowing ? 'unfollow_user' : 'follow_user',
            payload: <String, dynamic>{'user_id': userId},
          );
    } catch (e) {
      if (!_validMutation(epoch, key, revision)) return;
      debugPrint('[niosgram_provider] FOLLOW_FAILED: ${e.runtimeType}');
      final AsyncData<NiosgramState>? fresh = state.asData;
      if (fresh != null) {
        final List<NgPost> reverted = fresh.value.posts
            .map((NgPost p) {
              if (p.author.username != username) return p;
              return p.copyWith(isFollowing: wasFollowing);
            })
            .toList(growable: false);
        state = AsyncData<NiosgramState>(fresh.value.copyWith(posts: reverted));
      }
    }
  }
}

final AsyncNotifierProvider<NiosgramNotifier, NiosgramState> niosgramProvider =
    AsyncNotifierProvider<NiosgramNotifier, NiosgramState>(
      NiosgramNotifier.new,
    );
