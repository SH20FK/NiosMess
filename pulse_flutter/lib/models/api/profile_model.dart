import 'package:flutter/foundation.dart';
import 'package:pulse_flutter/models/api/badge_model.dart';
import 'package:pulse_flutter/models/api/working_hours_model.dart';

@immutable
class ApiAiUsage {
  const ApiAiUsage({
    required this.limitTokens,
    required this.usedTokens,
    required this.remainingTokens,
    required this.usedPercent,
    required this.windowHours,
    this.resetsAt,
  });

  final int limitTokens;
  final int usedTokens;
  final int remainingTokens;
  final double usedPercent;
  final int windowHours;
  final DateTime? resetsAt;

  factory ApiAiUsage.fromJson(Map<String, dynamic> json) {
    final int limit = (json['limit_tokens'] as num?)?.toInt() ?? 200000;
    final int used = (json['used_tokens'] as num?)?.toInt() ?? 0;
    final int remaining =
        (json['remaining_tokens'] as num?)?.toInt() ?? (limit - used);
    final double rawPercent = (json['used_percent'] as num?)?.toDouble() ??
        (limit > 0 ? (used / limit) * 100.0 : 0.0);
    final int windowHours = (json['window_hours'] as num?)?.toInt() ?? 72;
    return ApiAiUsage(
      limitTokens: limit,
      usedTokens: used,
      remainingTokens: remaining,
      usedPercent: rawPercent.clamp(0.0, 100.0),
      windowHours: windowHours,
      resetsAt: json['resets_at'] != null
          ? DateTime.tryParse(json['resets_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'limit_tokens': limitTokens,
        'used_tokens': usedTokens,
        'remaining_tokens': remainingTokens,
        'used_percent': usedPercent,
        'window_hours': windowHours,
        if (resetsAt != null) 'resets_at': resetsAt!.toIso8601String(),
      };

  ApiAiUsage copyWith({
    int? limitTokens,
    int? usedTokens,
    int? remainingTokens,
    double? usedPercent,
    int? windowHours,
    DateTime? resetsAt,
  }) {
    return ApiAiUsage(
      limitTokens: limitTokens ?? this.limitTokens,
      usedTokens: usedTokens ?? this.usedTokens,
      remainingTokens: remainingTokens ?? this.remainingTokens,
      usedPercent: usedPercent ?? this.usedPercent,
      windowHours: windowHours ?? this.windowHours,
      resetsAt: resetsAt ?? this.resetsAt,
    );
  }
}

class ApiProfile {
  const ApiProfile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.bio,
    this.avatarUrl,
    this.twoFaEnabled,
    this.spamBlock,
    this.spamBlockUntil,
    this.spamBlockReason,
    this.badges = const <ApiBadge>[],
    this.createdAt,
    this.phoneNumber,
    this.birthday,
    this.workingHours,
    this.visibleBadgeIds = const <int>[],
    this.aiUsage,
    this.isBlockedByMe = false,
    this.isBlockedByUser = false,
    this.isBlocked = false,
    this.isOnline = false,
    this.lastSeen,
  });

  final int id;
  final String username;
  final String displayName;
  final String bio;
  final String? avatarUrl;
  final bool? twoFaEnabled;
  final bool? spamBlock;
  final DateTime? spamBlockUntil;
  final String? spamBlockReason;
  final List<ApiBadge> badges;
  final DateTime? createdAt;
  final String? phoneNumber;
  final String? birthday;
  final WorkingHours? workingHours;
  final List<int> visibleBadgeIds;
  final ApiAiUsage? aiUsage;
  final bool isBlockedByMe;
  final bool isBlockedByUser;
  final bool isBlocked;
  final bool isOnline;
  final DateTime? lastSeen;

  bool get isRestrictedBySpamBlock {
    if (spamBlock == true) return true;
    if (spamBlockUntil != null && spamBlockUntil!.isAfter(DateTime.now())) {
      return true;
    }
    return false;
  }

  bool get isCallsTester =>
      badges.any((ApiBadge b) =>
          b.name.toLowerCase().contains('calls tester') ||
          b.name.toLowerCase() == 'calls_tester' ||
          (b.description != null &&
              b.description!.toLowerCase().contains('calls tester')));

  List<ApiBadge> get visibleBadges {
    if (visibleBadgeIds.isEmpty) {
      return badges.take(2).toList(growable: false);
    }
    final List<ApiBadge> list = <ApiBadge>[];
    for (final int id in visibleBadgeIds) {
      final int idx = badges.indexWhere((ApiBadge b) => b.id == id);
      if (idx != -1) {
        list.add(badges[idx]);
        if (list.length >= 2) break;
      }
    }
    if (list.isNotEmpty) return list;
    return badges.take(2).toList(growable: false);
  }

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

    final dynamic visibleBadgesRaw = json['visible_badge_ids'];
    final List<int> visibleBadgeIds;
    if (visibleBadgesRaw is List) {
      visibleBadgeIds = visibleBadgesRaw
          .map((dynamic item) => int.tryParse(item.toString()))
          .whereType<int>()
          .take(2)
          .toList(growable: false);
    } else {
      visibleBadgeIds = const <int>[];
    }


    final dynamic workingHoursRaw = json['working_hours'];
    final WorkingHours? workingHours;
    if (workingHoursRaw is Map) {
      workingHours = WorkingHours.fromJson(
        workingHoursRaw.map(
          (dynamic key, dynamic value) => MapEntry(key.toString(), value),
        ),
      );
    } else {
      workingHours = null;
    }

    return ApiProfile(
      id: json['id'] as int? ?? 0,
      username: json['username'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      twoFaEnabled: json['two_fa_enabled'] as bool?,
      spamBlock: json['spam_block'] as bool?,
      spamBlockUntil: json['spam_block_until'] != null
          ? DateTime.tryParse(json['spam_block_until'] as String)
          : null,
      spamBlockReason: json['spam_block_reason'] as String?,
      badges: badges,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      phoneNumber: json['phone_number'] as String?,
      birthday: json['birthday'] as String?,
      workingHours: workingHours,
      visibleBadgeIds: visibleBadgeIds,
      aiUsage: json['ai_usage'] is Map
          ? ApiAiUsage.fromJson(
              (json['ai_usage'] as Map).map(
                (dynamic k, dynamic v) => MapEntry(k.toString(), v),
              ),
            )
          : const ApiAiUsage(
              limitTokens: 200000,
              usedTokens: 0,
              remainingTokens: 200000,
              usedPercent: 0.0,
              windowHours: 72,
            ),
      isBlockedByMe: json['is_blocked_by_me'] as bool? ?? false,
      isBlockedByUser: json['is_blocked_by_user'] as bool? ?? false,
      isBlocked: json['is_blocked'] as bool? ??
          (json['is_blocked_by_me'] == true || json['is_blocked_by_user'] == true),
      isOnline: json['is_online'] == true ||
          json['is_online'] == 1 ||
          json['is_online']?.toString().toLowerCase() == 'true',
      lastSeen: json['last_seen'] != null
          ? DateTime.tryParse(json['last_seen'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'username': username,
      'display_name': displayName,
      'bio': bio,
      'avatar_url': avatarUrl,
      'two_fa_enabled': twoFaEnabled,
      'spam_block': spamBlock,
      if (spamBlockUntil != null)
        'spam_block_until': spamBlockUntil!.toIso8601String(),
      if (spamBlockReason != null) 'spam_block_reason': spamBlockReason,
      'badges': badges.map((b) => b.toJson()).toList(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (phoneNumber != null) 'phone_number': phoneNumber,
      if (birthday != null) 'birthday': birthday,
      if (workingHours != null) 'working_hours': workingHours!.toJson(),
      'visible_badge_ids': visibleBadgeIds,
      if (aiUsage != null) 'ai_usage': aiUsage!.toJson(),
      'is_blocked_by_me': isBlockedByMe,
      'is_blocked_by_user': isBlockedByUser,
      'is_blocked': isBlocked,
      'is_online': isOnline,
      if (lastSeen != null) 'last_seen': lastSeen!.toIso8601String(),
    };
  }

  ApiProfile copyWith({
    int? id,
    String? username,
    String? displayName,
    String? bio,
    String? avatarUrl,
    bool? twoFaEnabled,
    bool? spamBlock,
    DateTime? spamBlockUntil,
    String? spamBlockReason,
    List<ApiBadge>? badges,
    DateTime? createdAt,
    String? phoneNumber,
    String? birthday,
    WorkingHours? workingHours,
    List<int>? visibleBadgeIds,
    ApiAiUsage? aiUsage,
    bool? isBlockedByMe,
    bool? isBlockedByUser,
    bool? isBlocked,
    bool? isOnline,
    DateTime? lastSeen,
  }) {
    return ApiProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      twoFaEnabled: twoFaEnabled ?? this.twoFaEnabled,
      spamBlock: spamBlock ?? this.spamBlock,
      spamBlockUntil: spamBlockUntil ?? this.spamBlockUntil,
      spamBlockReason: spamBlockReason ?? this.spamBlockReason,
      badges: badges ?? this.badges,
      createdAt: createdAt ?? this.createdAt,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      birthday: birthday ?? this.birthday,
      workingHours: workingHours ?? this.workingHours,
      visibleBadgeIds: visibleBadgeIds ?? this.visibleBadgeIds,
      aiUsage: aiUsage ?? this.aiUsage,
      isBlockedByMe: isBlockedByMe ?? this.isBlockedByMe,
      isBlockedByUser: isBlockedByUser ?? this.isBlockedByUser,
      isBlocked: isBlocked ?? this.isBlocked,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
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
