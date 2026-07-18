import 'package:pulse_flutter/models/api/badge_model.dart';

class ApiProfile {
  const ApiProfile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.bio,
    this.avatarUrl,
    this.twoFaEnabled,
    this.spamBlock,
    this.badges = const <ApiBadge>[],
    this.createdAt,
  });

  final int id;
  final String username;
  final String displayName;
  final String bio;
  final String? avatarUrl;
  final bool? twoFaEnabled;
  final bool? spamBlock;
  final List<ApiBadge> badges;
  final DateTime? createdAt;

  factory ApiProfile.fromJson(Map<String, dynamic> json) {
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
    return ApiProfile(
      id: json['id'] as int? ?? 0,
      username: json['username'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      twoFaEnabled: json['two_fa_enabled'] as bool?,
      spamBlock: json['spam_block'] as bool?,
      badges: badges,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

class ApiProfileEncrypted {
  const ApiProfileEncrypted({
    required this.encryptedData,
    required this.iv,
    required this.tag,
  });

  final String encryptedData;
  final String iv;
  final String tag;

  factory ApiProfileEncrypted.fromJson(Map<String, dynamic> json) {
    return ApiProfileEncrypted(
      encryptedData: json['encrypted_data'] as String? ?? '',
      iv: json['iv'] as String? ?? '',
      tag: json['tag'] as String? ?? '',
    );
  }
}
