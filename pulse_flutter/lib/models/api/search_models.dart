import 'package:pulse_flutter/models/api/badge_model.dart';

class ApiSearchResult {
  const ApiSearchResult({
    required this.users,
    required this.chats,
    required this.messages,
  });

  const ApiSearchResult.empty()
    : users = const <ApiSearchUser>[],
      chats = const <ApiSearchChat>[],
      messages = const <ApiSearchMessage>[];

  final List<ApiSearchUser> users;
  final List<ApiSearchChat> chats;
  final List<ApiSearchMessage> messages;

  bool get isEmpty => users.isEmpty && chats.isEmpty && messages.isEmpty;

  factory ApiSearchResult.fromJson(Map<String, dynamic> json) {
    return ApiSearchResult(
      users: _parseUsers(json['users']),
      chats: _parseChats(json['chats']),
      messages: _parseMessages(json['messages']),
    );
  }

  static List<ApiSearchUser> _parseUsers(dynamic raw) {
    if (raw is! List) {
      return const <ApiSearchUser>[];
    }
    return raw
        .whereType<Map>()
        .map(
          (Map item) => ApiSearchUser.fromJson(
            item.map(
              (dynamic key, dynamic value) => MapEntry(key.toString(), value),
            ),
          ),
        )
        .toList(growable: false);
  }

  static List<ApiSearchChat> _parseChats(dynamic raw) {
    if (raw is! List) {
      return const <ApiSearchChat>[];
    }
    return raw
        .whereType<Map>()
        .map(
          (Map item) => ApiSearchChat.fromJson(
            item.map(
              (dynamic key, dynamic value) => MapEntry(key.toString(), value),
            ),
          ),
        )
        .toList(growable: false);
  }

  static List<ApiSearchMessage> _parseMessages(dynamic raw) {
    if (raw is! List) {
      return const <ApiSearchMessage>[];
    }
    return raw
        .whereType<Map>()
        .map(
          (Map item) => ApiSearchMessage.fromJson(
            item.map(
              (dynamic key, dynamic value) => MapEntry(key.toString(), value),
            ),
          ),
        )
        .toList(growable: false);
  }
}

class ApiSearchUser {
  const ApiSearchUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.bio,
    required this.badges,
    this.avatarUrl,
  });

  final int id;
  final String username;
  final String displayName;
  final String bio;
  final String? avatarUrl;
  final List<ApiBadge> badges;

  factory ApiSearchUser.fromJson(Map<String, dynamic> json) {
    final dynamic badgesRaw = json['badges'];
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

    return ApiSearchUser(
      id: json['id'] as int? ?? 0,
      username: json['username'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      badges: badges,
    );
  }
}

class ApiSearchChat {
  const ApiSearchChat({
    required this.id,
    required this.chatType,
    required this.name,
    required this.membersCount,
    this.username,
    this.avatarUrl,
    this.inviteLink,
    this.shareLink,
  });

  final int id;
  final String chatType;
  final String name;
  final int membersCount;
  final String? username;
  final String? avatarUrl;
  final String? inviteLink;
  final String? shareLink;

  factory ApiSearchChat.fromJson(Map<String, dynamic> json) {
    return ApiSearchChat(
      id: json['id'] as int? ?? 0,
      chatType: json['chat_type'] as String? ?? '',
      name: json['name'] as String? ?? '',
      username: json['username'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      membersCount: json['members_count'] as int? ?? 0,
      inviteLink: json['invite_link'] as String?,
      shareLink: json['share_link'] as String?,
    );
  }
}

class ApiSearchMessage {
  const ApiSearchMessage({
    required this.id,
    required this.chatId,
    required this.content,
    required this.senderDisplayName,
    this.senderUsername,
  });

  final int id;
  final int chatId;
  final String content;
  final String senderDisplayName;
  final String? senderUsername;

  factory ApiSearchMessage.fromJson(Map<String, dynamic> json) {
    return ApiSearchMessage(
      id: json['id'] as int? ?? 0,
      chatId: json['chat_id'] as int? ?? 0,
      content: json['content'] as String? ?? '',
      senderDisplayName: json['sender_display_name'] as String? ?? '',
      senderUsername: json['sender_username'] as String?,
    );
  }
}
