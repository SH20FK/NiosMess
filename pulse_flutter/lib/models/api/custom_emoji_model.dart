class ApiCustomEmoji {
  const ApiCustomEmoji({
    required this.id,
    required this.shortcode,
    required this.url,
    this.setId = 0,
    this.mediaType = 'image/png',
    this.isAdaptive = false,
    this.isAnimated = false,
    this.width = 128,
    this.height = 128,
  });
  final int id, setId, width, height;
  final String shortcode, url, mediaType;
  final bool isAdaptive, isAnimated;
  String get token => ':$shortcode:';
  bool get isSvg =>
      mediaType.contains('svg') || url.toLowerCase().endsWith('.svg');
  bool get isVideo => mediaType.startsWith('video/');
  factory ApiCustomEmoji.fromJson(Map<String, dynamic> json) => ApiCustomEmoji(
    id: (json['id'] as num?)?.toInt() ?? 0,
    setId: (json['set_id'] as num?)?.toInt() ?? 0,
    shortcode: json['shortcode'] as String? ?? '',
    url: json['url'] as String? ?? '',
    mediaType: json['media_type'] as String? ?? 'image/png',
    isAdaptive: json['is_adaptive'] == true || json['is_adaptive'] == 1,
    isAnimated: json['is_animated'] == true || json['is_animated'] == 1,
    width: (json['width'] as num?)?.toInt() ?? 128,
    height: (json['height'] as num?)?.toInt() ?? 128,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'set_id': setId,
    'shortcode': shortcode,
    'url': url,
    'media_type': mediaType,
    'is_adaptive': isAdaptive,
    'is_animated': isAnimated,
    'width': width,
    'height': height,
  };
}

class ApiCustomEmojiSet {
  const ApiCustomEmojiSet({
    required this.id,
    required this.name,
    required this.title,
    this.ownerId = 0,
    this.isOfficial = false,
    this.emojis = const [],
  });
  final int id, ownerId;
  final String name, title;
  final bool isOfficial;
  final List<ApiCustomEmoji> emojis;
  factory ApiCustomEmojiSet.fromJson(Map<String, dynamic> json) =>
      ApiCustomEmojiSet(
        id: (json['id'] as num?)?.toInt() ?? 0,
        ownerId: (json['owner_id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        title: json['title'] as String? ?? '',
        isOfficial: json['is_official'] == true || json['is_official'] == 1,
        emojis: (json['emojis'] as List? ?? [])
            .whereType<Map>()
            .map((e) => ApiCustomEmoji.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
  Map<String, dynamic> toJson() => {
    'id': id,
    'owner_id': ownerId,
    'name': name,
    'title': title,
    'is_official': isOfficial,
    'emojis': emojis.map((e) => e.toJson()).toList(),
  };
}

final customEmojiPattern = RegExp(r':([a-z0-9_]{2,64}):');
