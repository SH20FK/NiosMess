import 'package:pulse_flutter/models/api/badge_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';

bool _parseBool(dynamic value) {
  return value == true || value == 1 || value == '1' || value == 'true';
}

class ApiChatSummary {
  const ApiChatSummary({
    required this.id,
    required this.chatType,
    required this.name,
    required this.unreadCount,
    required this.membersCount,
    this.username,
    this.avatarUrl,
    this.lastMessage,
    this.partnerBadges = const <ApiBadge>[],
    this.description = '',
    this.commentsEnabled,
    this.commentsChatId,
    this.inviteLink,
    this.shareLink,
    this.isSecret = false,
  });

  final int id;
  final String chatType;
  final String name;
  final int unreadCount;
  final int membersCount;
  final String? username;
  final String? avatarUrl;
  final ApiMessage? lastMessage;
  final List<ApiBadge> partnerBadges;
  final String description;
  final bool? commentsEnabled;
  final int? commentsChatId;
  final String? inviteLink;
  final String? shareLink;
  final bool isSecret;

  DateTime get lastActivity =>
      lastMessage?.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  factory ApiChatSummary.fromJson(Map<String, dynamic> json) {
    final dynamic last = json['last_message'];
    final dynamic badgesRaw = json['partner_badges'];
    final List<ApiBadge> partnerBadges;
    if (badgesRaw is List) {
      partnerBadges = badgesRaw
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
      partnerBadges = const <ApiBadge>[];
    }

    return ApiChatSummary(
      id: json['id'] as int? ?? 0,
      chatType: json['chat_type'] as String? ?? 'direct',
      name: json['name'] as String? ?? json['username'] as String? ?? '',
      username: json['username'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      unreadCount: json['unread_count'] as int? ?? 0,
      membersCount: json['members_count'] as int? ?? 0,
      partnerBadges: partnerBadges,
      description: json['description'] as String? ?? '',
      commentsEnabled: json['comments_enabled'] != null ? _parseBool(json['comments_enabled']) : null,
      commentsChatId: json['comments_chat_id'] as int?,
      inviteLink: json['invite_link'] as String?,
      shareLink: json['share_link'] as String?,
      isSecret: _parseBool(json['is_secret']),
      lastMessage: last is Map<String, dynamic>
          ? ApiMessage.fromJson(last)
          : null,
    );
  }

  ApiChatSummary copyWith({
    int? id,
    String? chatType,
    String? name,
    int? unreadCount,
    int? membersCount,
    String? username,
    String? avatarUrl,
    ApiMessage? lastMessage,
    List<ApiBadge>? partnerBadges,
    String? description,
    bool? commentsEnabled,
    int? commentsChatId,
    String? inviteLink,
    String? shareLink,
    bool? isSecret,
  }) {
    return ApiChatSummary(
      id: id ?? this.id,
      chatType: chatType ?? this.chatType,
      name: name ?? this.name,
      unreadCount: unreadCount ?? this.unreadCount,
      membersCount: membersCount ?? this.membersCount,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastMessage: lastMessage ?? this.lastMessage,
      partnerBadges: partnerBadges ?? this.partnerBadges,
      description: description ?? this.description,
      commentsEnabled: commentsEnabled ?? this.commentsEnabled,
      commentsChatId: commentsChatId ?? this.commentsChatId,
      inviteLink: inviteLink ?? this.inviteLink,
      shareLink: shareLink ?? this.shareLink,
      isSecret: isSecret ?? this.isSecret,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chat_type': chatType,
      'name': name,
      'username': username,
      'avatar_url': avatarUrl,
      'unread_count': unreadCount,
      'members_count': membersCount,
      'partner_badges': partnerBadges.map((e) => e.toJson()).toList(),
      'description': description,
      'comments_enabled': commentsEnabled,
      'comments_chat_id': commentsChatId,
      'invite_link': inviteLink,
      'share_link': shareLink,
      'is_secret': isSecret,
      'last_message': lastMessage?.toJson(),
    };
  }
}
