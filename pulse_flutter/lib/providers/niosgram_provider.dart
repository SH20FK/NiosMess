import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/storage/cache_service.dart';
import 'package:pulse_flutter/core/utils/shared_utilities.dart';
import 'package:pulse_flutter/core/storage/notification_storage.dart';
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
  }) =>
      NiosgramState(
        posts: posts ?? this.posts,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        page: page ?? this.page,
      );
}

class NiosgramNotifier extends AsyncNotifier<NiosgramState> {
  StreamSubscription<dynamic>? _pushSub;

  @override
  Future<NiosgramState> build() async {
    _pushSub = ref.read(webSocketClientProvider).pushStream.listen(_handlePush);
    ref.onDispose(() => _pushSub?.cancel());

    final CacheService cache = ref.read(cacheServiceProvider);
    final List<NgPost> cached = cache.getCachedFeed();
    if (cached.isNotEmpty) {
      state = AsyncData<NiosgramState>(
        NiosgramState(
          posts: cached,
          page: 1,
          hasMore: cached.length >= 20,
        ),
      );
    }

    try {
      final List<NgPost> freshPosts = await _fetchPage(1);
      final List<NgPost> reconciled = _reconcilePosts(cached, freshPosts);
      await cache.saveFeed(reconciled);
      return NiosgramState(
        posts: reconciled,
        page: 1,
        hasMore: freshPosts.length >= 20,
      );
    } catch (e) {
      debugPrint('[niosgram_provider] Error fetching fresh feed in build: $e');
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
    final int minFreshId =
        fresh.map((NgPost p) => p.id).reduce((int a, int b) => a < b ? a : b);

    // Any cached post whose id is within the fresh range (>= minFreshId)
    // but not returned in fresh was deleted on the server!
    final List<NgPost> olderPosts = cached.where((NgPost p) {
      if (freshIds.contains(p.id)) return false;
      if (p.id >= minFreshId) return false; // Deleted on backend
      return true;
    }).toList(growable: false);

    return <NgPost>[...fresh, ...olderPosts];
  }

  Future<List<NgPost>> _fetchPage(int page) async {
    final dynamic response = await ref
        .read(webSocketClientProvider)
        .request(
          'get_feed',
          payload: <String, dynamic>{'page': page},
        );
    final dynamic posts = response is Map ? response['posts'] : response;
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
          ? ((data['post_id'] as num?)?.toInt() ?? (data['id'] as num?)?.toInt())
          : null;
      if (postId != null) {
        final AsyncData<NiosgramState>? current = state.asData;
        if (current != null) {
          final List<NgPost> filtered = current.value.posts
              .where((NgPost p) => p.id != postId)
              .toList(growable: false);
          state = AsyncData<NiosgramState>(current.value.copyWith(posts: filtered));
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
    final AsyncData<NiosgramState>? current = state.asData;
    if (current == null) return;
    final List<NgPost> updated = <NgPost>[
      post,
      ...current.value.posts.where((NgPost p) => p.id != post.id),
    ];
    state = AsyncData<NiosgramState>(
      current.value.copyWith(
        posts: updated,
      ),
    );
    ref.read(cacheServiceProvider).saveFeed(updated);

    final String myUsername = ref.read(authProvider).session?.username ?? '';
    if (myUsername.isNotEmpty && post.content.contains('@$myUsername')) {
      final String authorName = post.author.displayName.isNotEmpty
          ? post.author.displayName
          : post.author.username;
      NotificationStorage.createAndSave(
        title: 'NiosGram',
        body: '$authorName mentioned you in a post',
        route: '/niosgram/post/${post.id}/comments',
      );
    }
  }

  Future<void> refresh() async {
    final AsyncData<NiosgramState>? current = state.asData;
    final List<NgPost> existing = current?.value.posts ??
        ref.read(cacheServiceProvider).getCachedFeed();

    final List<NgPost> freshPosts = await _fetchPage(1);
    final List<NgPost> reconciled = _reconcilePosts(existing, freshPosts);
    await ref.read(cacheServiceProvider).saveFeed(reconciled);

    state = AsyncData<NiosgramState>(
      NiosgramState(
        posts: reconciled,
        page: 1,
        hasMore: freshPosts.length >= 20,
      ),
    );
  }

  Future<void> loadMore() async {
    final AsyncData<NiosgramState>? current = state.asData;
    if (current == null || current.value.isLoadingMore || !current.value.hasMore) return;

    state = AsyncData<NiosgramState>(current.value.copyWith(isLoadingMore: true));
    final int nextPage = current.value.page + 1;
    try {
      final List<NgPost> more = await _fetchPage(nextPage);
      state = AsyncData<NiosgramState>(
        current.value.copyWith(
          posts: <NgPost>[...current.value.posts, ...more],
          page: nextPage,
          hasMore: more.length >= 20,
          isLoadingMore: false,
        ),
      );
    } catch (e) {
      debugPrint('[niosgram_provider] Load more error: $e');
      state = AsyncData<NiosgramState>(
        current.value.copyWith(isLoadingMore: false),
      );
    }
  }

  Future<void> reactPost(int postId, bool isLike) async {
    final AsyncData<NiosgramState>? current = state.asData;
    if (current == null) return;

    // Optimistic update
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

    try {
      final dynamic response = await ref.read(webSocketClientProvider).request(
        'react_post',
        payload: <String, dynamic>{
          'post_id': postId,
          'reaction': isLike ? 'like' : 'dislike',
          'is_like': isLike,
        },
      );
      if (response is Map) {
        final dynamic respPayload = response['payload'] ?? response;
        if (respPayload is Map) {
          final int? likes = respPayload['likes'] as int? ??
              respPayload['likes_count'] as int?;
          final int? dislikes = respPayload['dislikes'] as int? ??
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
            final List<NgPost> synced = fresh.value.posts.map((NgPost p) {
              if (p.id != postId) return p;
              return p.copyWith(
                likesCount: likes ?? p.likesCount,
                dislikesCount: dislikes ?? p.dislikesCount,
                myReaction: () => serverReaction,
              );
            }).toList(growable: false);
            state =
                AsyncData<NiosgramState>(fresh.value.copyWith(posts: synced));
          }
        }
      }
    } catch (e) {
      debugPrint('[niosgram_provider] Like error: $e');
      final NgPost? originalPost = current.value.posts.where((p) => p.id == postId).firstOrNull;
      if (originalPost != null) {
        final AsyncData<NiosgramState>? fresh = state.asData;
        if (fresh != null) {
          final List<NgPost> reverted = fresh.value.posts
              .map((NgPost p) => p.id == postId ? originalPost : p)
              .toList(growable: false);
          state = AsyncData<NiosgramState>(fresh.value.copyWith(posts: reverted));
        }
      }
    }
  }

  Future<void> createPost(
    String text, {
    dynamic uploadId,
    List<dynamic>? uploadIds,
    List<String>? aiTags,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'content': text.trim(),
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
    final dynamic response = await ref.read(webSocketClientProvider).request(
      'create_post',
      payload: payload,
    );
    if (response is! Map) return;
    if (response['error'] != null) {
      throw Exception(response['error'].toString());
    }

    final dynamic respData =
        response['payload'] ?? response['data'] ?? response;
    if (respData is Map && respData['id'] != null && respData['author'] != null) {
      final NgPost post = NgPost.fromJson(
        respData.map((dynamic k, dynamic v) => MapEntry(k.toString(), v)),
      );
      final AsyncData<NiosgramState>? current = state.asData;
      if (current != null) {
        final List<NgPost> updatedList = <NgPost>[
          post,
          ...current.value.posts.where((NgPost p) => p.id != post.id),
        ];
        state = AsyncData<NiosgramState>(
          current.value.copyWith(
            posts: updatedList,
          ),
        );
        ref.read(cacheServiceProvider).saveFeed(updatedList);
      }
    }

    try {
      final List<NgPost> freshPosts = await _fetchPage(1);
      final AsyncData<NiosgramState>? current = state.asData;
      if (current != null && freshPosts.isNotEmpty) {
        final List<NgPost> reconciled = _reconcilePosts(current.value.posts, freshPosts);
        await ref.read(cacheServiceProvider).saveFeed(reconciled);
        state = AsyncData<NiosgramState>(
          current.value.copyWith(
            posts: reconciled,
            page: 1,
            hasMore: freshPosts.length >= 20,
          ),
        );
      }
    } catch (e) {
      debugPrint('[niosgram_provider] Error refreshing feed after createPost: $e');
    }
  }

  Future<void> deletePost(int postId) async {
    final AsyncData<NiosgramState>? current = state.asData;
    if (current == null) return;
    final List<NgPost> filtered = current.value.posts
        .where((NgPost p) => p.id != postId)
        .toList(growable: false);
    state = AsyncData<NiosgramState>(
      current.value.copyWith(
        posts: filtered,
      ),
    );
    ref.read(cacheServiceProvider).saveFeed(filtered);
    try {
      await ref.read(webSocketClientProvider).request(
        'delete_post',
        payload: <String, dynamic>{'post_id': postId},
      );
    } catch (_) {
      final NgPost? originalPost = current.value.posts.where((p) => p.id == postId).firstOrNull;
      if (originalPost != null) {
        final AsyncData<NiosgramState>? fresh = state.asData;
        if (fresh != null && !fresh.value.posts.any((p) => p.id == postId)) {
          final List<NgPost> reverted = <NgPost>[...fresh.value.posts, originalPost];
          reverted.sort((a, b) => b.id.compareTo(a.id));
          state = AsyncData<NiosgramState>(fresh.value.copyWith(posts: reverted));
          ref.read(cacheServiceProvider).saveFeed(reverted);
        }
      }
    }
  }

  Future<void> editPost(int postId, String text) async {
    final AsyncData<NiosgramState>? current = state.asData;
    if (current == null) return;
    final String trimmed = text.trim();
    final NgPost? originalPost = current.value.posts.where((p) => p.id == postId).firstOrNull;
    state = AsyncData<NiosgramState>(
      current.value.copyWith(
        posts: current.value.posts
            .map((NgPost p) => p.id == postId ? p.copyWith(content: trimmed) : p)
            .toList(growable: false),
      ),
    );
    try {
      final dynamic response = await ref.read(webSocketClientProvider).request(
        'edit_post',
        payload: <String, dynamic>{'post_id': postId, 'content': trimmed},
      );
      if (response is Map) {
        final NgPost updated = NgPost.fromJson(
          response.map((dynamic k, dynamic v) => MapEntry(k.toString(), v)),
        );
        final AsyncData<NiosgramState>? fresh = state.asData;
        if (fresh != null) {
          state = AsyncData<NiosgramState>(
            fresh.value.copyWith(
              posts: fresh.value.posts
                  .map((NgPost p) => p.id == postId ? updated : p)
                  .toList(growable: false),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[niosgram_provider] Edit post error: $e');
      if (originalPost != null) {
        final AsyncData<NiosgramState>? fresh = state.asData;
        if (fresh != null) {
          final List<NgPost> reverted = fresh.value.posts
              .map((NgPost p) => p.id == postId ? originalPost : p)
              .toList(growable: false);
          state = AsyncData<NiosgramState>(fresh.value.copyWith(posts: reverted));
        }
      }
    }
  }

  Future<void> toggleFollow(String username) async {
    final AsyncData<NiosgramState>? current = state.asData;
    if (current == null) return;

    final NgPost? targetPost = current.value.posts
        .where((NgPost p) => p.author.username == username)
        .firstOrNull;
    if (targetPost == null) return;

    final bool wasFollowing = targetPost.isFollowing;
    final int userId = targetPost.author.id;

    final List<NgPost> updated = current.value.posts.map((NgPost p) {
      if (p.author.username != username) return p;
      return p.copyWith(isFollowing: !wasFollowing);
    }).toList(growable: false);
    state = AsyncData<NiosgramState>(current.value.copyWith(posts: updated));

    try {
      await ref.read(webSocketClientProvider).request(
        wasFollowing ? 'unfollow_user' : 'follow_user',
        payload: <String, dynamic>{'user_id': userId},
      );
    } catch (e) {
      debugPrint('[niosgram_provider] Follow/unfollow error: $e');
      final AsyncData<NiosgramState>? fresh = state.asData;
      if (fresh != null) {
        final List<NgPost> reverted = fresh.value.posts.map((NgPost p) {
          if (p.author.username != username) return p;
          return p.copyWith(isFollowing: wasFollowing);
        }).toList(growable: false);
        state = AsyncData<NiosgramState>(fresh.value.copyWith(posts: reverted));
      }
    }
  }
}

final AsyncNotifierProvider<NiosgramNotifier, NiosgramState>
    niosgramProvider =
    AsyncNotifierProvider<NiosgramNotifier, NiosgramState>(
  NiosgramNotifier.new,
);
