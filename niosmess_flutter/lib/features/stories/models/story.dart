import 'package:flutter/foundation.dart';

/// Модель истории (Story/Status)
@immutable
class Story {
  final String id;
  final String userId;
  final String username;
  final String? avatarUrl;
  final List<StoryMedia> media;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int viewsCount;
  final List<String> viewedBy;
  final bool isViewed; // Просмотрена текущим пользователем

  const Story({
    required this.id,
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.media,
    required this.createdAt,
    required this.expiresAt,
    this.viewsCount = 0,
    this.viewedBy = const [],
    this.isViewed = false,
  });

  /// Проверка, истекла ли история
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Оставшееся время до удаления
  Duration get timeRemaining => expiresAt.difference(DateTime.now());

  factory Story.fromJson(Map<String, dynamic> json) {
    return Story(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      username: json['username'] as String,
      avatarUrl: json['avatar_url'] as String?,
      media: (json['media'] as List<dynamic>)
          .map((e) => StoryMedia.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      viewsCount: json['views_count'] as int? ?? 0,
      viewedBy: (json['viewed_by'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      isViewed: json['is_viewed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'username': username,
      'avatar_url': avatarUrl,
      'media': media.map((e) => e.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'views_count': viewsCount,
      'viewed_by': viewedBy,
      'is_viewed': isViewed,
    };
  }

  Story copyWith({
    String? id,
    String? userId,
    String? username,
    String? avatarUrl,
    List<StoryMedia>? media,
    DateTime? createdAt,
    DateTime? expiresAt,
    int? viewsCount,
    List<String>? viewedBy,
    bool? isViewed,
  }) {
    return Story(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      media: media ?? this.media,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      viewsCount: viewsCount ?? this.viewsCount,
      viewedBy: viewedBy ?? this.viewedBy,
      isViewed: isViewed ?? this.isViewed,
    );
  }
}

/// Медиа контент истории
@immutable
class StoryMedia {
  final String id;
  final StoryMediaType type;
  final String url;
  final String? thumbnailUrl;
  final String? text; // Текст поверх изображения
  final int? duration; // Для видео (секунды)

  const StoryMedia({
    required this.id,
    required this.type,
    required this.url,
    this.thumbnailUrl,
    this.text,
    this.duration,
  });

  factory StoryMedia.fromJson(Map<String, dynamic> json) {
    return StoryMedia(
      id: json['id'] as String,
      type: StoryMediaType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => StoryMediaType.image,
      ),
      url: json['url'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      text: json['text'] as String?,
      duration: json['duration'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'url': url,
      'thumbnail_url': thumbnailUrl,
      'text': text,
      'duration': duration,
    };
  }
}

enum StoryMediaType {
  image,
  video,
}

/// Ответ на историю
@immutable
class StoryReply {
  final String id;
  final String storyId;
  final String userId;
  final String username;
  final String? avatarUrl;
  final String message;
  final DateTime createdAt;

  const StoryReply({
    required this.id,
    required this.storyId,
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.message,
    required this.createdAt,
  });

  factory StoryReply.fromJson(Map<String, dynamic> json) {
    return StoryReply(
      id: json['id'] as String,
      storyId: json['story_id'] as String,
      userId: json['user_id'] as String,
      username: json['username'] as String,
      avatarUrl: json['avatar_url'] as String?,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'story_id': storyId,
      'user_id': userId,
      'username': username,
      'avatar_url': avatarUrl,
      'message': message,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
