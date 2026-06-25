import 'package:pulse_flutter/core/utils/datetime_helpers.dart';
import 'package:pulse_flutter/models/api/badge_model.dart';
import 'package:pulse_flutter/core/utils/app_time.dart';

class ApiMessage {
  const ApiMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderUsername,
    required this.senderDisplayName,
    required this.senderBadges,
    required this.content,
    required this.msgType,
    required this.replyToId,
    required this.mediaUrl,
    required this.mediaType,
    required this.mediaName,
    required this.mediaSize,
    required this.mediaDuration,
    required this.commentsCount,
    required this.reactions,
    required this.sentAt,
    required this.editedAt,
    required this.isDeleted,
    this.senderAvatarUrl,
    this.replyMarkup,
    this.isSending = false,
    this.isFailed = false,
    this.isE2ee = false,
    this.e2eeContent,
    this.isRead = false,
  });

  final int id;
  final int chatId;
  final int senderId;
  final String senderUsername;
  final String senderDisplayName;
  final String? senderAvatarUrl;
  final List<ApiBadge> senderBadges;
  final String content;
  final String msgType;
  final int? replyToId;
  final String? mediaUrl;
  final String? mediaType;
  final String? mediaName;
  final int? mediaSize;
  final int? mediaDuration;
  final int commentsCount;
  final Map<String, int> reactions;
  final DateTime sentAt;
  final DateTime? editedAt;
  final bool isDeleted;
  final InlineKeyboardMarkup? replyMarkup;
  final bool isSending;
  final bool isFailed;
  final bool isE2ee;
  final String? e2eeContent;
  final bool isRead;

  bool get isEdited => editedAt != null;

  bool get hasMedia => (mediaUrl ?? '').isNotEmpty;

  DateTime get resolvedSentAt => AppTimeSettings.resolve(sentAt);

  factory ApiMessage.fromJson(Map<String, dynamic> json) {
    final dynamic badgesRaw = json['sender_badges'];
    final List<ApiBadge> badges;
    if (badgesRaw is List) {
      badges = badgesRaw
          .whereType<Map>()
          .map(
            (Map item) => ApiBadge.fromJson(
              item.map(
                (dynamic key, dynamic value) => MapEntry(key.toString(), value),
              ),
            ),
          )
          .toList(growable: false);
    } else {
      badges = const <ApiBadge>[];
    }

    final dynamic reactionsRaw = json['reactions'];
    final Map<String, int> reactions = <String, int>{};
    if (reactionsRaw is Map) {
      reactionsRaw.forEach((dynamic key, dynamic value) {
        final String emoji = key.toString();
        final int count = value is int
            ? value
            : (value is num ? value.toInt() : 0);
        if (emoji.isNotEmpty && count > 0) {
          reactions[emoji] = count;
        }
      });
    }

    final bool isE2ee = json['is_e2ee'] == true;
    final String? e2eeContentRaw = json['e2ee_content'] as String?;

    return ApiMessage(
      id: json['id'] as int? ?? 0,
      chatId: json['chat_id'] as int? ?? 0,
      senderId: json['sender_id'] as int? ?? 0,
      senderUsername: json['sender_username'] as String? ?? '',
      senderDisplayName: json['sender_display_name'] as String? ?? 'Unknown',
      senderAvatarUrl: json['sender_avatar_url'] as String?,
      senderBadges: badges,
      content: isE2ee ? '' : (json['content'] as String? ?? ''),
      msgType: json['msg_type'] as String? ?? 'text',
      replyToId: json['reply_to_id'] as int?,
      mediaUrl: json['media_url'] as String?,
      mediaType: json['media_type'] as String?,
      mediaName: json['media_name'] as String?,
      mediaSize: json['media_size'] as int?,
      mediaDuration: json['media_duration'] as int?,
      commentsCount: json['comments_count'] as int? ?? 0,
      reactions: reactions,
      sentAt: parseApiDateTime(json['sent_at'] as String?),
      editedAt: parseApiDateTimeNullable(json['edited_at'] as String?),
      isDeleted: json['is_deleted'] as bool? ?? false,
      replyMarkup: json['reply_markup'] != null
          ? InlineKeyboardMarkup.fromJson(json['reply_markup'] as Map<String, dynamic>)
          : null,
      isE2ee: isE2ee,
      e2eeContent: e2eeContentRaw,
      isRead: json['is_read'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chat_id': chatId,
      'sender_id': senderId,
      'sender_username': senderUsername,
      'sender_display_name': senderDisplayName,
      'sender_avatar_url': senderAvatarUrl,
      'sender_badges': senderBadges.map((e) => e.toJson()).toList(),
      'content': content,
      'msg_type': msgType,
      'reply_to_id': replyToId,
      'media_url': mediaUrl,
      'media_type': mediaType,
      'media_name': mediaName,
      'media_size': mediaSize,
      'media_duration': mediaDuration,
      'comments_count': commentsCount,
      'reactions': reactions,
      'sent_at': sentAt.toIso8601String(),
      'edited_at': editedAt?.toIso8601String(),
      'is_deleted': isDeleted,
      'is_e2ee': isE2ee,
      'is_read': isRead,
      if (e2eeContent != null) 'e2ee_content': e2eeContent,
      if (replyMarkup != null) 'reply_markup': replyMarkup!.toJson(),
    };
  }
}

class InlineKeyboardMarkup {
  const InlineKeyboardMarkup({required this.inlineKeyboard});

  final List<List<InlineKeyboardButton>> inlineKeyboard;

  factory InlineKeyboardMarkup.fromJson(Map<String, dynamic> json) {
    final List<dynamic>? rows = json['inline_keyboard'] as List<dynamic>?;
    if (rows == null) {
      return const InlineKeyboardMarkup(inlineKeyboard: []);
    }
    return InlineKeyboardMarkup(
      inlineKeyboard: rows.map((dynamic row) {
        if (row is List) {
          return row
              .map((dynamic btn) => InlineKeyboardButton.fromJson(btn as Map<String, dynamic>))
              .toList(growable: false);
        }
        return <InlineKeyboardButton>[];
      }).toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'inline_keyboard': inlineKeyboard
          .map((row) => row.map((btn) => btn.toJson()).toList(growable: false))
          .toList(growable: false),
    };
  }
}

class InlineKeyboardButton {
  const InlineKeyboardButton({
    required this.text,
    this.callbackData,
    this.url,
  });

  final String text;
  final String? callbackData;
  final String? url;

  factory InlineKeyboardButton.fromJson(Map<String, dynamic> json) {
    return InlineKeyboardButton(
      text: json['text'] as String? ?? '',
      callbackData: json['callback_data'] as String?,
      url: json['url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      if (callbackData != null) 'callback_data': callbackData,
      if (url != null) 'url': url,
    };
  }
}
