class LinkPreview {
  final String url;
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? faviconUrl;
  final String? siteName;

  const LinkPreview({
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
    this.faviconUrl,
    this.siteName,
  });

  factory LinkPreview.fromJson(Map<String, dynamic> json) {
    return LinkPreview(
      url: json['url'] as String,
      title: json['title'] as String?,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      faviconUrl: json['favicon_url'] as String?,
      siteName: json['site_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'favicon_url': faviconUrl,
      'site_name': siteName,
    };
  }

  bool get hasData => title != null || description != null || imageUrl != null;
}
