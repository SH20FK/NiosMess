import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';

class CommentsPage {
  const CommentsPage(this.messages, this.hasMore, [this.totalCount]);
  final List<ApiMessage> messages;
  final bool hasMore;
  final int? totalCount;
}

class PostCommentsRepository {
  const PostCommentsRepository(this.ref);
  final Ref ref;

  Future<Map<String, dynamic>> request(
    String action,
    int channelId,
    int postId,
    Map<String, dynamic> extra,
  ) async {
    final dynamic result = await ref
        .read(webSocketClientProvider)
        .request(
          action,
          payload: <String, dynamic>{
            'post_id': postId,
            if (channelId > 0) 'channel_id': channelId,
            ...extra,
          },
        );
    if (result is! Map) throw StateError('Не удалось получить комментарии');
    final map = result.map((dynamic k, dynamic v) => MapEntry(k.toString(), v));
    if (map['error'] != null) throw StateError(map['error'].toString());
    return map;
  }

  Future<CommentsPage> page(
    int channelId,
    int postId, {
    int afterId = 0,
  }) async {
    final data = await request(
      channelId > 0 ? 'get_comments' : 'get_post_comments',
      channelId,
      postId,
      <String, dynamic>{'after_id': afterId, 'page_size': 80},
    );
    final items = (data['comments'] as List? ?? const <dynamic>[])
        .whereType<Map>()
        .map(
          (Map item) => ApiMessage.fromJson(
            item.map((dynamic k, dynamic v) => MapEntry(k.toString(), v)),
          ),
        )
        .toList(growable: false);
    return CommentsPage(
      items,
      data['has_more'] == true,
      data['total_count'] as int?,
    );
  }

  Future<ApiMessage> send(
    int channelId,
    int postId,
    String content,
    int? replyToId,
  ) async {
    return ApiMessage.fromJson(
      await request(
        channelId > 0 ? 'post_comment' : 'comment_post',
        channelId,
        postId,
        <String, dynamic>{'content': content, 'reply_to_id': replyToId},
      ),
    );
  }

  Future<void> mutate(
    String action,
    int channelId,
    int postId,
    int commentId, {
    String? content,
    String? reaction,
  }) async {
    await request(action, channelId, postId, <String, dynamic>{
      'comment_id': commentId,
      'content': ?content,
      'reaction': ?reaction,
    });
  }
}

final postCommentsRepositoryProvider = Provider<PostCommentsRepository>(
  PostCommentsRepository.new,
);
