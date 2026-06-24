import 'package:nios_admin_flutter/models/admin_badge.dart';

class AdminUser {
  const AdminUser({
    required this.id,
    required this.username,
    required this.email,
    required this.displayName,
    required this.avatarUrl,
    required this.isActive,
    required this.isBanned,
    required this.isFrozen,
    required this.spamBlock,
    required this.twoFaEnabled,
    required this.createdAt,
    required this.badges,
  });

  final int id;
  final String username;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final bool isActive;
  final bool isBanned;
  final bool isFrozen;
  final bool spamBlock;
  final bool twoFaEnabled;
  final DateTime createdAt;
  final List<AdminBadge> badges;

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    final List<dynamic> badgesRaw =
        (json['badges'] as List?) ?? const <dynamic>[];
    return AdminUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString(),
      isActive: json['is_active'] == true,
      isBanned: json['is_banned'] == true,
      isFrozen: json['is_frozen'] == true,
      spamBlock: json['spam_block'] == true,
      twoFaEnabled: json['two_fa_enabled'] == true,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      badges: badgesRaw
          .whereType<Map>()
          .map(
            (Map raw) => AdminBadge.fromJson(
              raw.map((dynamic key, dynamic value) => MapEntry('$key', value)),
            ),
          )
          .toList(growable: false),
    );
  }
}
