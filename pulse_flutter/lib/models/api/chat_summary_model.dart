import 'package:pulse_flutter/models/api/badge_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/models/api/status_emoji_model.dart';

bool _parseBool(dynamic value) {
  return value == true || value == 1 || value == '1' || value == 'true';
}

String? _parsePartnerPublicKey(Map<String, dynamic> json) {
  final withUser = json['with_user'];
  if (withUser is Map) {
    final String? key = withUser['public_key'] as String?;
    if (key != null && key.isNotEmpty) return key;
  }
  return json['partner_public_key'] as String?;
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
    this.partnerStatusEmoji,
    this.description = '',
    this.commentsEnabled,
    this.commentsChatId,
    this.inviteLink,
    this.shareLink,
    this.isSecret = false,
    this.partnerPublicKey,
    this.isPrivate = false,
    this.inviteToken,
    this.autoDeleteSeconds,
    this.partnerUserId,
    this.isBlockedByMe = false,
    this.isBlockedByUser = false,
    this.isBlocked = false,
    this.isOnline = false,
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
  final ApiStatusEmoji? partnerStatusEmoji;
  final String description;
  final bool? commentsEnabled;
  final int? commentsChatId;
  final String? inviteLink;
  final String? shareLink;
  final bool isSecret;
  final String? partnerPublicKey;
  final bool isPrivate;
  final String? inviteToken;
  final int? autoDeleteSeconds;
  final int? partnerUserId;
  final bool isBlockedByMe;
  final bool isBlockedByUser;
  final bool isBlocked;
  final bool isOnline;

  String? get formattedAutoDeleteDuration {
    if (autoDeleteSeconds == null || autoDeleteSeconds! <= 0) return null;
    final int sec = autoDeleteSeconds!;
    if (sec < 3600) {
      final int m = (sec / 60).round();
      return '$m мин.';
    } else if (sec < 86400) {
      final int h = (sec / 3600).round();
      return '$h ч.';
    } else if (sec < 2592000) {
      final int d = (sec / 86400).round();
      return '$d дн.';
    } else {
      final int mo = (sec / 2592000).round();
      return '$mo мес.';
    }
  }

  String? get privateInviteUrl {
    if (inviteToken != null && inviteToken!.isNotEmpty) {
      return '/u/+$inviteToken';
    }
    return inviteLink;
  }

  DateTime get lastActivity =>
      lastMessage?.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  bool get isBotChat =>
      partnerBadges.any(
        (ApiBadge b) =>
            b.name.toLowerCase().contains('bot') ||
            b.name.toLowerCase().contains('ai') ||
            b.icon.toLowerCase().contains('bot'),
      ) ||
      username?.endsWith('_bot') == true;

  bool get isVerified =>
      partnerBadges.any(
        (ApiBadge b) =>
            b.name.toLowerCase().contains('verify') ||
            b.name.toLowerCase().contains('верифи') ||
            b.icon.toLowerCase().contains('check') ||
            b.icon.toLowerCase().contains('verified'),
      ) ||
      username?.toLowerCase() == 'support';

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

    final int? autoDelete = json['auto_delete_seconds'] as int?;

    final dynamic partnerRaw = json['partner'] ?? json['with_user'];
    final Map<String, dynamic>? partnerMap = partnerRaw is Map
        ? partnerRaw.map((dynamic k, dynamic v) => MapEntry(k.toString(), v))
        : null;

    final int? partnerUserId = partnerMap != null
        ? ((partnerMap['id'] as num?)?.toInt() ?? (partnerMap['user_id'] as num?)?.toInt())
        : ((json['with_user_id'] as num?)?.toInt() ?? (json['partner_id'] as num?)?.toInt() ?? (json['other_user_id'] as num?)?.toInt());

    final bool isBlockedByMe = _parseBool(partnerMap?['is_blocked_by_me'] ?? json['is_blocked_by_me']);
    final bool isBlockedByUser = _parseBool(partnerMap?['is_blocked_by_user'] ?? json['is_blocked_by_user']);
    final bool isBlocked = _parseBool(partnerMap?['is_blocked'] ?? json['is_blocked']) || isBlockedByMe || isBlockedByUser;
    final bool isOnline = _parseBool(json['is_online']) || _parseBool(partnerMap?['is_online']);

    final String? partnerUsername = partnerMap?['username'] as String?;
    final String? partnerDisplayName = partnerMap?['display_name'] as String?;
    final String? rawUsername = json['username'] as String?;
    final String? resolvedUsername = (rawUsername != null && rawUsername.isNotEmpty)
        ? rawUsername
        : partnerUsername;

    final String rawName = json['name'] as String? ?? '';
    final String resolvedName = rawName.isNotEmpty
        ? rawName
        : (partnerDisplayName?.isNotEmpty == true
            ? partnerDisplayName!
            : (resolvedUsername ?? ''));

    final String? resolvedAvatar = json['avatar_url'] as String? ?? partnerMap?['avatar_url'] as String?;

    final dynamic emojiRaw = json['partner_status_emoji'] ?? partnerMap?['status_emoji'];
    final ApiStatusEmoji? partnerStatusEmoji = emojiRaw is Map
        ? ApiStatusEmoji.fromJson(
            emojiRaw.map(
              (dynamic k, dynamic v) => MapEntry(k.toString(), v),
            ),
          )
        : null;

    return ApiChatSummary(
      id: json['id'] as int? ?? 0,
      chatType: json['chat_type'] as String? ?? 'direct',
      name: resolvedName,
      username: resolvedUsername,
      avatarUrl: resolvedAvatar,
      unreadCount: json['unread_count'] as int? ?? 0,
      membersCount: json['members_count'] as int? ?? 0,
      partnerBadges: partnerBadges,
      partnerStatusEmoji: partnerStatusEmoji,
      description: json['description'] as String? ?? '',
      commentsEnabled: json['comments_enabled'] != null ? _parseBool(json['comments_enabled']) : null,
      commentsChatId: json['comments_chat_id'] as int?,
      inviteLink: json['invite_link'] as String?,
      shareLink: json['share_link'] as String?,
      isSecret: _parseBool(json['is_secret']),
      partnerPublicKey: _parsePartnerPublicKey(json),
      isPrivate: _parseBool(json['is_private']),
      inviteToken: json['invite_token'] as String?,
      autoDeleteSeconds: autoDelete,
      partnerUserId: partnerUserId,
      isBlockedByMe: isBlockedByMe,
      isBlockedByUser: isBlockedByUser,
      isBlocked: isBlocked,
      isOnline: isOnline,
      lastMessage: last is Map
          ? ApiMessage.fromJson(
              last.map(
                (dynamic k, dynamic v) => MapEntry(k.toString(), v),
              ),
            )
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
    ApiStatusEmoji? partnerStatusEmoji,
    String? description,
    bool? commentsEnabled,
    int? commentsChatId,
    String? inviteLink,
    String? shareLink,
    bool? isSecret,
    String? partnerPublicKey,
    bool? isPrivate,
    String? inviteToken,
    int? autoDeleteSeconds,
    int? partnerUserId,
    bool? isBlockedByMe,
    bool? isBlockedByUser,
    bool? isBlocked,
    bool? isOnline,
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
      partnerStatusEmoji: partnerStatusEmoji ?? this.partnerStatusEmoji,
      description: description ?? this.description,
      commentsEnabled: commentsEnabled ?? this.commentsEnabled,
      commentsChatId: commentsChatId ?? this.commentsChatId,
      inviteLink: inviteLink ?? this.inviteLink,
      shareLink: shareLink ?? this.shareLink,
      isSecret: isSecret ?? this.isSecret,
      partnerPublicKey: partnerPublicKey ?? this.partnerPublicKey,
      isPrivate: isPrivate ?? this.isPrivate,
      inviteToken: inviteToken ?? this.inviteToken,
      autoDeleteSeconds: autoDeleteSeconds ?? this.autoDeleteSeconds,
      partnerUserId: partnerUserId ?? this.partnerUserId,
      isBlockedByMe: isBlockedByMe ?? this.isBlockedByMe,
      isBlockedByUser: isBlockedByUser ?? this.isBlockedByUser,
      isBlocked: isBlocked ?? this.isBlocked,
      isOnline: isOnline ?? this.isOnline,
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
      if (partnerPublicKey != null) 'partner_public_key': partnerPublicKey,
      'is_private': isPrivate,
      if (inviteToken != null) 'invite_token': inviteToken,
      if (autoDeleteSeconds != null) 'auto_delete_seconds': autoDeleteSeconds,
      'is_online': isOnline,
      if (partnerUserId != null) 'partner_user_id': partnerUserId,
      'last_message': lastMessage?.toJson(),
    };
  }
}
