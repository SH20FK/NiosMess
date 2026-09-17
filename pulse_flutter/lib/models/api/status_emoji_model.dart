class ApiStatusEmoji {
  const ApiStatusEmoji({
    required this.shortcode,
    required this.url,
    this.mediaType,
    this.isAnimated = false,
    this.width,
    this.height,
  });

  final String shortcode;
  final String url;
  final String? mediaType;
  final bool isAnimated;
  final int? width;
  final int? height;

  bool get isSvg =>
      (mediaType?.contains('svg') == true) || url.toLowerCase().endsWith('.svg');

  factory ApiStatusEmoji.fromJson(Map<String, dynamic> json) {
    return ApiStatusEmoji(
      shortcode: json['shortcode'] as String? ?? '',
      url: json['url'] as String? ?? '',
      mediaType: json['media_type'] as String?,
      isAnimated: json['is_animated'] == true || json['is_animated'] == 1,
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'shortcode': shortcode,
      'url': url,
      if (mediaType != null) 'media_type': mediaType,
      'is_animated': isAnimated,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
    };
  }
}
