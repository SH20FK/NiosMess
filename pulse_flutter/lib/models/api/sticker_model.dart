import 'package:flutter/foundation.dart';

import 'package:pulse_flutter/core/network/api_constants.dart';

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

  /// Absolute resolved URL for network image and video loaders.
  String get resolvedUrl {
    final String clean = url.trim();
    if (clean.isEmpty) return '';
    return ApiConstants.resolve(clean);
  }

  bool get isAnimated =>
      (durationSeconds != null && durationSeconds! > 0) ||
      mediaType.contains('video') ||
      mediaType.contains('gif') ||
      mediaType.contains('webm') ||
      mediaType.contains('mp4');

  factory ApiSticker.fromJson(Map<String, dynamic> json) {
    final String rawUrl = json['url'] as String? ?? '';
    final int? setId = (json['set_id'] as num?)?.toInt() ??
        (json['setId'] as num?)?.toInt() ??
        (json['sticker_set_id'] as num?)?.toInt();
    final int id = (json['id'] as num?)?.toInt() ?? 0;

    String effectiveUrl = rawUrl;
    if (effectiveUrl.trim().isEmpty) {
      final String? filePath =
          json['file_path'] as String? ?? json['media_path'] as String?;
      if (filePath != null && filePath.isNotEmpty) {
        effectiveUrl = filePath.startsWith('/') ? filePath : '/static/$filePath';
      }
    }

    return ApiSticker(
      id: id,
      setId: setId,
      url: effectiveUrl,
      emoji: json['emoji'] as String? ?? '',
      mediaType: json['media_type'] as String? ??
          json['mediaType'] as String? ??
          'image/webp',
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ??
          (json['durationSeconds'] as num?)?.toInt(),
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      fileSize: (json['file_size'] as num?)?.toInt() ??
          (json['fileSize'] as num?)?.toInt(),
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
    this.isSaved,
    this.isOwner,
    this.shareUrl,
    this.stickers = const <ApiSticker>[],
  });

  final int id;
  final String name;
  final String title;
  final bool isPublic;
  final int? authorId;
  final bool? isSaved;
  final bool? isOwner;
  final String? shareUrl;
  final List<ApiSticker> stickers;

  ApiSticker? get coverSticker => stickers.isNotEmpty ? stickers.first : null;

  factory ApiStickerSet.fromJson(Map<String, dynamic> json) {
    final dynamic rawStickers = json['stickers'];
    final int setId = (json['id'] as num?)?.toInt() ?? 0;
    final List<ApiSticker> parsedStickers;
    if (rawStickers is List) {
      parsedStickers = rawStickers
          .whereType<Map>()
          .map(
            (Map item) {
              final ApiSticker st = ApiSticker.fromJson(
                item.map(
                  (dynamic k, dynamic v) => MapEntry(k.toString(), v),
                ),
              );
              return (st.setId == null || st.setId == 0) && setId > 0
                  ? st.copyWith(setId: setId)
                  : st;
            },
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
      isSaved: json['is_saved'] != null ? _parseBool(json['is_saved']) : null,
      isOwner: json['is_owner'] != null ? _parseBool(json['is_owner']) : null,
      shareUrl: json['share_url'] as String?,
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
      if (isSaved != null) 'is_saved': isSaved,
      if (isOwner != null) 'is_owner': isOwner,
      if (shareUrl != null) 'share_url': shareUrl,
      'stickers': stickers.map((ApiSticker s) => s.toJson()).toList(growable: false),
    };
  }

  ApiStickerSet copyWith({
    int? id,
    String? name,
    String? title,
    bool? isPublic,
    int? authorId,
    bool? isSaved,
    bool? isOwner,
    String? shareUrl,
    List<ApiSticker>? stickers,
  }) {
    return ApiStickerSet(
      id: id ?? this.id,
      name: name ?? this.name,
      title: title ?? this.title,
      isPublic: isPublic ?? this.isPublic,
      authorId: authorId ?? this.authorId,
      isSaved: isSaved ?? this.isSaved,
      isOwner: isOwner ?? this.isOwner,
      shareUrl: shareUrl ?? this.shareUrl,
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
          isSaved == other.isSaved &&
          isOwner == other.isOwner &&
          shareUrl == other.shareUrl &&
          listEquals(stickers, other.stickers);

  @override
  int get hashCode => Object.hash(
        id,
        name,
        title,
        isPublic,
        authorId,
        isSaved,
        isOwner,
        shareUrl,
        Object.hashAll(stickers),
      );
}
