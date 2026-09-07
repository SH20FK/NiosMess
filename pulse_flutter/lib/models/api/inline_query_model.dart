import 'package:flutter/foundation.dart';

@immutable
class InlineQueryResult {
  const InlineQueryResult({
    required this.id,
    required this.type,
    required this.title,
    this.description,
    required this.messageText,
    this.thumbUrl,
    this.url,
  });

  final String id;
  final String type;
  final String title;
  final String? description;
  final String messageText;
  final String? thumbUrl;
  final String? url;

  factory InlineQueryResult.fromJson(Map<String, dynamic> json) {
    final String rawTitle = json['title'] as String? ?? '';
    final String rawMsgText = json['message_text'] as String? ?? '';
    return InlineQueryResult(
      id: json['id']?.toString() ?? '',
      type: json['type'] as String? ?? 'article',
      title: rawTitle,
      description: json['description'] as String?,
      messageText: rawMsgText.isNotEmpty ? rawMsgText : rawTitle,
      thumbUrl: json['thumb_url'] as String?,
      url: json['url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'type': type,
      'title': title,
      if (description != null) 'description': description,
      'message_text': messageText,
      if (thumbUrl != null) 'thumb_url': thumbUrl,
      if (url != null) 'url': url,
    };
  }

  InlineQueryResult copyWith({
    String? id,
    String? type,
    String? title,
    String? description,
    String? messageText,
    String? thumbUrl,
    String? url,
  }) {
    return InlineQueryResult(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      messageText: messageText ?? this.messageText,
      thumbUrl: thumbUrl ?? this.thumbUrl,
      url: url ?? this.url,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InlineQueryResult &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          type == other.type &&
          title == other.title &&
          description == other.description &&
          messageText == other.messageText &&
          thumbUrl == other.thumbUrl &&
          url == other.url;

  @override
  int get hashCode => Object.hash(id, type, title, description, messageText, thumbUrl, url);

  @override
  String toString() =>
      'InlineQueryResult(id: $id, type: $type, title: $title, messageText: $messageText)';
}

@immutable
class InlineQueryResponse {
  const InlineQueryResponse({
    required this.inlineQueryId,
    this.expiresIn,
    this.results = const <InlineQueryResult>[],
  });

  final String inlineQueryId;
  final int? expiresIn;
  final List<InlineQueryResult> results;

  factory InlineQueryResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic>? rawList = json['results'] as List<dynamic>?;
    final List<InlineQueryResult> results = rawList != null
        ? rawList
            .whereType<Map>()
            .map((dynamic m) => InlineQueryResult.fromJson(
                  (m as Map).map(
                      (dynamic k, dynamic v) => MapEntry(k.toString(), v)),
                ))
            .toList(growable: false)
        : const <InlineQueryResult>[];

    return InlineQueryResponse(
      inlineQueryId: json['inline_query_id']?.toString() ?? '',
      expiresIn: json['expires_in'] is int
          ? json['expires_in'] as int
          : int.tryParse(json['expires_in']?.toString() ?? ''),
      results: results,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'inline_query_id': inlineQueryId,
        if (expiresIn != null) 'expires_in': expiresIn,
        'results': results.map((InlineQueryResult r) => r.toJson()).toList(growable: false),
      };

  InlineQueryResponse copyWith({
    String? inlineQueryId,
    int? expiresIn,
    List<InlineQueryResult>? results,
  }) {
    return InlineQueryResponse(
      inlineQueryId: inlineQueryId ?? this.inlineQueryId,
      expiresIn: expiresIn ?? this.expiresIn,
      results: results ?? this.results,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InlineQueryResponse &&
          runtimeType == other.runtimeType &&
          inlineQueryId == other.inlineQueryId &&
          expiresIn == other.expiresIn &&
          listEquals(results, other.results);

  @override
  int get hashCode => Object.hash(inlineQueryId, expiresIn, Object.hashAll(results));

  @override
  String toString() =>
      'InlineQueryResponse(inlineQueryId: $inlineQueryId, expiresIn: $expiresIn, results: ${results.length})';
}
