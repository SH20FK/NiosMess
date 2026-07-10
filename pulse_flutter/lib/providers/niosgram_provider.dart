import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final List<NgPost> posts = await _fetchPage(1);
    return NiosgramState(
      posts: posts,
      page: 1,
      hasMore: posts.length >= 20,
    );
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
    if (msg['action'] != 'new_ng_post') return;
    final dynamic data = msg['data'];
    if (data is! Map) return;
    final NgPost post = NgPost.fromJson(
      data.map((dynamic k, dynamic v) => MapEntry(k.toString(), v)),
    );
    final AsyncData<NiosgramState>? current = state.asData;
    if (current == null) return;
    state = AsyncData<NiosgramState>(
      current.value.copyWith(
        posts: <NgPost>[post, ...current.value.posts],
      ),
    );

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
    state = const AsyncLoading<NiosgramState>();
    state = await AsyncValue.guard(() async {
      final List<NgPost> posts = await _fetchPage(1);
      return NiosgramState(
        posts: posts,
        page: 1,
        hasMore: posts.length >= 20,
      );
    });
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
    } catch (_) {
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
      await ref.read(webSocketClientProvider).request(
        'react_post',
        payload: <String, dynamic>{
          'post_id': postId,
          'is_like': isLike,
        },
      );
    } catch (_) {
      // Rollback on error
      state = AsyncData<NiosgramState>(current.value);
    }
  }

  Future<void> createPost(String text, {int? uploadId}) async {
    final Map<String, dynamic> payload = <String, dynamic>{'content': text.trim()};
    if (uploadId != null) payload['upload_id'] = uploadId;
    final dynamic response = await ref.read(webSocketClientProvider).request(
      'create_post',
      payload: payload,
    );
    if (response is! Map) return;
    final NgPost post = NgPost.fromJson(
      response.map((dynamic k, dynamic v) => MapEntry(k.toString(), v)),
    );
    final AsyncData<NiosgramState>? current = state.asData;
    if (current == null) return;
    state = AsyncData<NiosgramState>(
      current.value.copyWith(
        posts: <NgPost>[post, ...current.value.posts],
      ),
    );
  }

  Future<void> deletePost(int postId) async {
    final AsyncData<NiosgramState>? current = state.asData;
    if (current == null) return;
    state = AsyncData<NiosgramState>(
      current.value.copyWith(
        posts: current.value.posts
            .where((NgPost p) => p.id != postId)
            .toList(growable: false),
      ),
    );
    try {
      await ref.read(webSocketClientProvider).request(
        'delete_post',
        payload: <String, dynamic>{'post_id': postId},
      );
    } catch (_) {
      state = AsyncData<NiosgramState>(current.value);
    }
  }

  Future<void> editPost(int postId, String text) async {
    final AsyncData<NiosgramState>? current = state.asData;
    if (current == null) return;
    final String trimmed = text.trim();
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
        state = AsyncData<NiosgramState>(
          current.value.copyWith(
            posts: current.value.posts
                .map((NgPost p) => p.id == postId ? updated : p)
                .toList(growable: false),
          ),
        );
      }
    } catch (_) {
      state = AsyncData<NiosgramState>(current.value);
    }
  }

  Future<void> toggleFollow(String username) async {
    final AsyncData<NiosgramState>? current = state.asData;
    if (current == null) return;

    final List<NgPost> updated = current.value.posts.map((NgPost p) {
      if (p.author.username != username) return p;
      return p.copyWith(isFollowing: !p.isFollowing);
    }).toList(growable: false);
    state = AsyncData<NiosgramState>(current.value.copyWith(posts: updated));

    final int userId = current.value.posts
        .firstWhere((NgPost p) => p.author.username == username)
        .author.id;
    try {
      await ref.read(webSocketClientProvider).request(
        'follow_user',
        payload: <String, dynamic>{'user_id': userId},
      );
    } catch (_) {
      state = AsyncData<NiosgramState>(current.value);
    }
  }
}

final AsyncNotifierProvider<NiosgramNotifier, NiosgramState>
    niosgramProvider =
    AsyncNotifierProvider<NiosgramNotifier, NiosgramState>(
  NiosgramNotifier.new,
);
