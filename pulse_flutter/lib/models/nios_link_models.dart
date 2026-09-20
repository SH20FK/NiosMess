import 'package:flutter/foundation.dart';

/// Semantic types of NiosLink resources.
enum NiosLinkType {
  chat,
  message,
  file,
  pair,
  transfer,
  invite,
  unknown;

  static NiosLinkType fromString(String? raw) {
    if (raw == null) return NiosLinkType.unknown;
    switch (raw.toLowerCase().trim()) {
      case 'c':
      case 'chat':
        return NiosLinkType.chat;
      case 'm':
      case 'message':
      case 'msg':
        return NiosLinkType.message;
      case 'f':
      case 'file':
        return NiosLinkType.file;
      case 'pair':
      case 'device':
        return NiosLinkType.pair;
      case 'tx':
      case 'transfer':
        return NiosLinkType.transfer;
      case 'invite':
        return NiosLinkType.invite;
      default:
        return NiosLinkType.unknown;
    }
  }

  String get shortCode {
    switch (this) {
      case NiosLinkType.chat:
        return 'c';
      case NiosLinkType.message:
        return 'm';
      case NiosLinkType.file:
        return 'f';
      case NiosLinkType.pair:
        return 'pair';
      case NiosLinkType.transfer:
        return 'tx';
      case NiosLinkType.invite:
        return 'c';
      case NiosLinkType.unknown:
        return 'u';
    }
  }
}

/// Parsed representation of any incoming NiosLink URI.
@immutable
class NiosLinkParsed {
  const NiosLinkParsed({
    required this.rawUri,
    required this.type,
    required this.token,
    this.queryParams = const <String, String>{},
  });

  final Uri rawUri;
  final NiosLinkType type;
  final String token;
  final Map<String, String> queryParams;

  bool get isValid => token.isNotEmpty && type != NiosLinkType.unknown;

  /// Returns canonical web fallback on ni-os.ru
  String get canonicalWebUrl => 'https://ni-os.ru/l/${type.shortCode}/$token';

  /// Returns canonical native URI
  String get canonicalNativeUri {
    final String typeStr = type == NiosLinkType.pair ? 'device/pair' : type.name;
    return 'nios://$typeStr/$token';
  }

  @override
  String toString() => 'NiosLinkParsed($type: $token)';
}

/// Result returned from server upon resolving an opaque NiosLink token.
@immutable
class NiosLinkResolution {
  const NiosLinkResolution({
    required this.status,
    required this.tokenType,
    required this.targetType,
    required this.targetId,
    this.chatId,
    this.messageId,
    this.blobId,
    this.filename,
    this.fileSize,
    this.downloadUrl,
    this.pairSessionId,
    this.extra = const <String, dynamic>{},
  });

  final String status;
  final String tokenType;
  final String targetType;
  final String targetId;
  final int? chatId;
  final int? messageId;
  final String? blobId;
  final String? filename;
  final int? fileSize;
  final String? downloadUrl;
  final String? pairSessionId;
  final Map<String, dynamic> extra;

  factory NiosLinkResolution.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> extra =
        (json['extra'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    int? chatId;
    int? messageId;
    String? blobId;
    String? filename;
    int? fileSize;
    String? downloadUrl;
    String? pairSessionId;

    if (json['chat_id'] != null) {
      chatId = (json['chat_id'] as num).toInt();
    }
    if (json['chat'] is Map) {
      chatId = (json['chat']['id'] as num?)?.toInt() ?? chatId;
    }
    if (json['message'] is Map) {
      final Map msg = json['message'] as Map;
      messageId = (msg['id'] as num?)?.toInt();
      chatId = (msg['chat_id'] as num?)?.toInt() ?? chatId;
    }
    if (json['file'] is Map) {
      final Map f = json['file'] as Map;
      blobId = f['blob_id'] as String?;
      filename = f['filename'] as String?;
      fileSize = (f['size'] as num?)?.toInt();
      downloadUrl = f['download_url'] as String?;
    }
    if (json['pair'] is Map) {
      pairSessionId = json['pair']['session_id'] as String?;
    }

    return NiosLinkResolution(
      status: (json['status'] as String?) ?? 'valid',
      tokenType: (json['token_type'] as String?) ?? '',
      targetType: (json['target_type'] as String?) ?? '',
      targetId: (json['target_id'] as String?) ?? '',
      chatId: chatId,
      messageId: messageId,
      blobId: blobId,
      filename: filename,
      fileSize: fileSize,
      downloadUrl: downloadUrl,
      pairSessionId: pairSessionId,
      extra: extra,
    );
  }
}

/// Device pairing session payload
@immutable
class NiosPairSession {
  const NiosPairSession({
    required this.token,
    required this.sessionId,
    required this.nativeUrl,
    required this.webUrl,
    required this.expiresIn,
  });

  final String token;
  final String sessionId;
  final String nativeUrl;
  final String webUrl;
  final int expiresIn;

  factory NiosPairSession.fromJson(Map<String, dynamic> json) {
    return NiosPairSession(
      token: (json['token'] as String?) ?? '',
      sessionId: (json['session_id'] as String?) ?? '',
      nativeUrl: (json['native_url'] as String?) ?? '',
      webUrl: (json['web_url'] as String?) ?? '',
      expiresIn: (json['expires_in'] as int?) ?? 180,
    );
  }
}
