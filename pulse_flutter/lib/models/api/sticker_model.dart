import 'package:flutter/foundation.dart';

bool _parseBool(dynamic value) {
  return value == true ||
      value == 1 ||
      value == '1' ||
      value == 'true';
}

@immutable
class ApiSticker {
  const ApiSticker({
    required this.id,
    required this.url,
    this.setId,
    this.emoji = '',
    this.mediaType = 'image/webp',
    this.durationSeconds,
    this.width,
    this.height,
    this.fileSize,
  });

  final int id;
  final int? setId;
  final String url;
  final String emoji;
  final String mediaType;
  final int? durationSeconds;
  final int? width;
  final int? height;
  final int? fileSize;

  bool get isAnimated =>
      (durationSeconds != null && durationSeconds! > 0) ||
      mediaType.contains('video') ||
      mediaType.contains('gif') ||
      mediaType.contains('webm') ||
      mediaType.contains('mp4');

  factory ApiSticker.fromJson(Map<String, dynamic> json) {
    return ApiSticker(
      id: (json['id'] as num?)?.toInt() ?? 0,
      setId: (json['set_id'] as num?)?.toInt(),
      url: json['url'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '',
      mediaType: json['media_type'] as String? ?? 'image/webp',
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      fileSize: (json['file_size'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      if (setId != null) 'set_id': setId,
      'url': url,
      'emoji': emoji,
      'media_type': mediaType,
      'duration_seconds': durationSeconds,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (fileSize != null) 'file_size': fileSize,
    };
  }

  ApiSticker copyWith({
    int? id,
    int? setId,
    String? url,
    String? emoji,
    String? mediaType,
    int? durationSeconds,
    int? width,
    int? height,
    int? fileSize,
  }) {
    return ApiSticker(
      id: id ?? this.id,
      setId: setId ?? this.setId,
      url: url ?? this.url,
      emoji: emoji ?? this.emoji,
      mediaType: mediaType ?? this.mediaType,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      width: width ?? this.width,
      height: height ?? this.height,
      fileSize: fileSize ?? this.fileSize,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApiSticker &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          setId == other.setId &&
          url == other.url &&
          emoji == other.emoji &&
          mediaType == other.mediaType &&
          durationSeconds == other.durationSeconds &&
          width == other.width &&
          height == other.height &&
          fileSize == other.fileSize;

  @override
  int get hashCode => Object.hash(
        id,
        setId,
        url,
        emoji,
        mediaType,
        durationSeconds,
        width,
        height,
        fileSize,
      );
}

@immutable
class ApiStickerSet {
  const ApiStickerSet({
    required this.id,
    required this.name,
    required this.title,
    this.isPublic = true,
    this.authorId,
    this.stickers = const <ApiSticker>[],
  });

  final int id;
  final String name;
  final String title;
  final bool isPublic;
  final int? authorId;
  final List<ApiSticker> stickers;

  ApiSticker? get coverSticker => stickers.isNotEmpty ? stickers.first : null;

  factory ApiStickerSet.fromJson(Map<String, dynamic> json) {
    final dynamic rawStickers = json['stickers'];
    final List<ApiSticker> parsedStickers;
    if (rawStickers is List) {
      parsedStickers = rawStickers
          .whereType<Map>()
          .map(
            (Map item) => ApiSticker.fromJson(
              item.map(
                (dynamic k, dynamic v) => MapEntry(k.toString(), v),
              ),
            ),
          )
          .toList(growable: false);
    } else {
      parsedStickers = const <ApiSticker>[];
    }

    return ApiStickerSet(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      title: json['title'] as String? ?? '',
      isPublic: _parseBool(json['is_public']),
      authorId: (json['author_id'] as num?)?.toInt(),
      stickers: parsedStickers,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'title': title,
      'is_public': isPublic,
      if (authorId != null) 'author_id': authorId,
      'stickers': stickers.map((ApiSticker s) => s.toJson()).toList(growable: false),
    };
  }

  ApiStickerSet copyWith({
    int? id,
    String? name,
    String? title,
    bool? isPublic,
    int? authorId,
    List<ApiSticker>? stickers,
  }) {
    return ApiStickerSet(
      id: id ?? this.id,
      name: name ?? this.name,
      title: title ?? this.title,
      isPublic: isPublic ?? this.isPublic,
      authorId: authorId ?? this.authorId,
      stickers: stickers ?? this.stickers,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApiStickerSet &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          title == other.title &&
          isPublic == other.isPublic &&
          authorId == other.authorId &&
          listEquals(stickers, other.stickers);

  @override
  int get hashCode => Object.hash(
        id,
        name,
        title,
        isPublic,
        authorId,
        Object.hashAll(stickers),
      );
}
