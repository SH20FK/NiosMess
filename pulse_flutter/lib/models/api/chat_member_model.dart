import 'package:pulse_flutter/models/api/badge_model.dart';

bool _parseBool(dynamic value) {
  return value == true ||
      value == 1 ||
      value == '1' ||
      value == 'true';
}

class ApiChatMember {
  const ApiChatMember({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.role,
    required this.isMuted,
    required this.isBanned,
    this.avatarUrl,
    this.badges = const <ApiBadge>[],
  });

  final int userId;
  final String username;
  final String displayName;
  final String role;
  final bool isMuted;
  final bool isBanned;
  final String? avatarUrl;
  final List<ApiBadge> badges;

  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'admin';

  factory ApiChatMember.fromJson(Map<String, dynamic> json) {
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
    return ApiChatMember(
      userId: json['user_id'] as int? ?? 0,
      username: json['username'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      role: json['role'] as String? ?? 'member',
      isMuted: _parseBool(json['is_muted']),
      isBanned: _parseBool(json['is_banned']),
      avatarUrl: json['avatar_url'] as String?,
      badges: badges,
    );
  }
}
