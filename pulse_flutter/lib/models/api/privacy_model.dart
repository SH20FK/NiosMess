import 'package:flutter/foundation.dart';

enum PrivacyPolicy {
  everyone,
  contacts,
  nobody;

  static PrivacyPolicy fromString(String? value) {
    switch (value) {
      case 'everyone':
        return PrivacyPolicy.everyone;
      case 'contacts':
        return PrivacyPolicy.contacts;
      case 'nobody':
        return PrivacyPolicy.nobody;
      default:
        return PrivacyPolicy.everyone;
    }
  }

  String get apiValue {
    switch (this) {
      case PrivacyPolicy.everyone:
        return 'everyone';
      case PrivacyPolicy.contacts:
        return 'contacts';
      case PrivacyPolicy.nobody:
        return 'nobody';
    }
  }

  String get localizedTitle {
    switch (this) {
      case PrivacyPolicy.everyone:
        return 'Все';
      case PrivacyPolicy.contacts:
        return 'Мои контакты';
      case PrivacyPolicy.nobody:
        return 'Никто';
    }
  }
}

@immutable
class PrivacyRule {
  const PrivacyRule({
    required this.key,
    required this.policy,
    this.alwaysAllow = const <int>[],
    this.neverAllow = const <int>[],
  });

  final String key;
  final PrivacyPolicy policy;
  final List<int> alwaysAllow;
  final List<int> neverAllow;

  static const List<String> allKeys = <String>[
    'phone',
    'last_seen',
    'profile_photos',
    'forwards',
    'calls',
    'voice_messages',
    'messages',
    'birthday',
    'gifts',
    'bio',
    'saved_music',
    'invites',
  ];

  static String localizedKeyName(String key) {
    switch (key) {
      case 'phone':
        return 'Номер телефона';
      case 'last_seen':
        return 'Время захода и статус в сети';
      case 'profile_photos':
        return 'Фотографии профиля';
      case 'forwards':
        return 'Пересылка сообщений';
      case 'calls':
        return 'Звонки';
      case 'voice_messages':
        return 'Голосовые сообщения';
      case 'messages':
        return 'Личные сообщения';
      case 'birthday':
        return 'Дата рождения';
      case 'gifts':
        return 'Подарки';
      case 'bio':
        return 'О себе';
      case 'saved_music':
        return 'Сохранённая музыка';
      case 'invites':
        return 'Приглашения в группы и каналы';
      default:
        return key;
    }
  }

  factory PrivacyRule.fromJson(Map<String, dynamic> json) {
    final dynamic allowRaw = json['always_allow'];
    final dynamic neverRaw = json['never_allow'];

    final List<int> alwaysAllow = allowRaw is List
        ? allowRaw.whereType<int>().toList(growable: false)
        : const <int>[];
    final List<int> neverAllow = neverRaw is List
        ? neverRaw.whereType<int>().toList(growable: false)
        : const <int>[];

    return PrivacyRule(
      key: json['key'] as String? ?? '',
      policy: PrivacyPolicy.fromString(
        json['default_policy'] as String? ?? json['policy'] as String?,
      ),
      alwaysAllow: alwaysAllow,
      neverAllow: neverAllow,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'key': key,
      'default_policy': policy.apiValue,
      'always_allow': alwaysAllow,
      'never_allow': neverAllow,
    };
  }

  PrivacyRule copyWith({
    String? key,
    PrivacyPolicy? policy,
    List<int>? alwaysAllow,
    List<int>? neverAllow,
  }) {
    return PrivacyRule(
      key: key ?? this.key,
      policy: policy ?? this.policy,
      alwaysAllow: alwaysAllow ?? this.alwaysAllow,
      neverAllow: neverAllow ?? this.neverAllow,
    );
  }
}

@immutable
class BlockedUser {
  const BlockedUser({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.blockedAt,
  });

  final int id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final DateTime? blockedAt;

  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    return BlockedUser(
      id: json['id'] as int? ?? json['user_id'] as int? ?? 0,
      username: json['username'] as String? ?? '',
      displayName: json['display_name'] as String? ??
          json['username'] as String? ??
          'Пользователь',
      avatarUrl: json['avatar_url'] as String?,
      blockedAt: json['blocked_at'] != null
          ? DateTime.tryParse(json['blocked_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'username': username,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      if (blockedAt != null) 'blocked_at': blockedAt!.toIso8601String(),
    };
  }
}
