import 'package:pulse_flutter/models/api/profile_model.dart';

class NgPost {
  const NgPost({
    required this.id,
    required this.content,
    required this.author,
    required this.createdAt,
    required this.likesCount,
    required this.dislikesCount,
    required this.commentsCount,
    this.mediaUrl,
    this.myReaction,
    this.isFollowing = false,
  });

  final int id;
  final String content;
  final String? mediaUrl;
  final int likesCount;
  final int dislikesCount;
  final int commentsCount;
  /// true = liked, false = disliked, null = no reaction
  final bool? myReaction;
  final bool isFollowing;
  final ApiProfile author;
  final DateTime createdAt;

  factory NgPost.fromJson(Map<String, dynamic> json) {
    final dynamic authorRaw = json['author'];
    final ApiProfile author = authorRaw is Map
        ? ApiProfile.fromJson(
            authorRaw.map(
              (dynamic k, dynamic v) => MapEntry(k.toString(), v),
            ),
          )
        : const ApiProfile(
            id: 0,
            username: '',
            displayName: '',
            bio: '',
          );

    final dynamic reactionRaw = json['my_reaction'];
    bool? myReaction;
    if (reactionRaw == 'like' || reactionRaw == true) {
      myReaction = true;
    } else if (reactionRaw == 'dislike' || reactionRaw == false) {
      myReaction = false;
    }

    return NgPost(
      id: json['id'] as int? ?? 0,
      content: json['content'] as String? ?? '',
      mediaUrl: json['media_url'] as String?,
      likesCount: json['likes_count'] as int? ?? 0,
      dislikesCount: json['dislikes_count'] as int? ?? 0,
      commentsCount: json['comments_count'] as int? ?? 0,
      myReaction: myReaction,
      isFollowing: json['is_following'] as bool? ?? false,
      author: author,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'content': content,
        'media_url': mediaUrl,
        'likes_count': likesCount,
        'dislikes_count': dislikesCount,
        'comments_count': commentsCount,
        'my_reaction': myReaction == null
            ? null
            : (myReaction! ? 'like' : 'dislike'),
        'is_following': isFollowing,
        'created_at': createdAt.toIso8601String(),
      };

  NgPost copyWith({
    int? id,
    String? content,
    String? mediaUrl,
    int? likesCount,
    int? dislikesCount,
    int? commentsCount,
    bool? Function()? myReaction,
    bool? isFollowing,
    ApiProfile? author,
    DateTime? createdAt,
  }) {
    return NgPost(
      id: id ?? this.id,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      likesCount: likesCount ?? this.likesCount,
      dislikesCount: dislikesCount ?? this.dislikesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      myReaction: myReaction != null ? myReaction() : this.myReaction,
      isFollowing: isFollowing ?? this.isFollowing,
      author: author ?? this.author,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
