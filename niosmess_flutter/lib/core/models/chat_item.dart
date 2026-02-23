class ChatItem {
  ChatItem({
    required this.id,
    required this.name,
    required this.type,
    required this.unread,
    this.username,
    this.isOnline,
    this.lastSeenText,
    this.avatarUrl,
    this.badgeTitle,
    this.badgeText,
    this.badgeIcon,
    this.isPinned = false,
  });

  final String id;
  final String name;
  final String type;
  final int unread;
  final String? username;
  final bool? isOnline;
  final String? lastSeenText;
  final String? avatarUrl;
  final String? badgeTitle;
  final String? badgeText;
  final String? badgeIcon;
  final bool isPinned;

  static Map<String, dynamic> normalizeJson(Map<String, dynamic> item) {
    final chatId =
        item['id'] ?? item['username'] ?? item['chat_id'] ?? item['chatId'];
    final chatIdStr = chatId?.toString() ?? '';
    final rawType = item['type']?.toString();
    final resolvedType = (rawType != null && rawType.isNotEmpty)
        ? rawType
        : (chatIdStr != null && chatIdStr.startsWith('group_'))
            ? 'group'
            : (chatIdStr != null && chatIdStr.startsWith('channel_'))
                ? 'channel'
                : 'user';
    final isOnline = item['is_online'] ?? item['isonline'];
    final avatarRaw =
        item['avatar'] ?? item['avatar_url'] ?? item['photo'] ?? item['avatarUrl'];
    final avatar = avatarRaw?.toString() ?? '';
    final name = (item['name'] ?? chatIdStr).toString();
    final username = (item['username'] ?? chatIdStr).toString();
    final unreadRaw = item['unread_count'] ?? item['unread'] ?? 0;
    final unread = unreadRaw is num
        ? unreadRaw.toInt()
        : int.tryParse(unreadRaw.toString()) ?? 0;

    return {
      ...item,
      'id': chatIdStr,
      'name': name,
      'type': resolvedType,
      'username': username,
      'isonline': isOnline,
      'avatarUrl': avatar,
      'unread': unread,
    };
  }


  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'unread': unread,
        'username': username,
        'isonline': isOnline,
        'last_seen_text': lastSeenText,
        'avatarUrl': avatarUrl,
        'badge_title': badgeTitle,
        'badge_text': badgeText,
        'badge_icon': badgeIcon,
        'is_pinned': isPinned,
      };


  factory ChatItem.fromJson(Map<String, dynamic> json) {
    final normalized = normalizeJson(json);
    final id = normalized['id']?.toString() ?? '';
    if (id.isEmpty) {
      throw const FormatException('Missing chat id');
    }
    final unreadRaw = normalized['unread'];
    final unread = unreadRaw is num
        ? unreadRaw.toInt()
        : int.tryParse(unreadRaw?.toString() ?? '') ?? 0;
    final onlineRaw = normalized['isonline'];
    bool? isOnline;
    if (onlineRaw is bool) {
      isOnline = onlineRaw;
    } else if (onlineRaw != null) {
      final normalizedValue = onlineRaw.toString().toLowerCase();
      if (normalizedValue == '1' || normalizedValue == 'true') {
        isOnline = true;
      } else if (normalizedValue == '0' || normalizedValue == 'false') {
        isOnline = false;
      }
    }
    return ChatItem(
      id: id,
      name: (normalized['name'] ?? id).toString(),
      type: (normalized['type'] ?? 'user').toString(),
      unread: unread,
      username: normalized['username']?.toString(),
      isOnline: isOnline,
      lastSeenText: normalized['last_seen_text']?.toString(),
      avatarUrl: normalized['avatarUrl']?.toString() ??
          normalized['avatar']?.toString() ??
          normalized['avatar_url']?.toString(),
      badgeTitle: normalized['badge_title']?.toString(),
      badgeText: normalized['badge_text']?.toString(),
      badgeIcon: normalized['badge_icon']?.toString(),
      isPinned: normalized['is_pinned'] == true ||
          normalized['is_pinned']?.toString() == '1',
    );
  }

  ChatItem copyWith({
    String? id,
    String? name,
    String? type,
    int? unread,
    String? username,
    bool? isOnline,
    String? lastSeenText,
    String? avatarUrl,
    String? badgeTitle,
    String? badgeText,
    String? badgeIcon,
    bool? isPinned,
  }) {
    return ChatItem(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      unread: unread ?? this.unread,
      username: username ?? this.username,
      isOnline: isOnline ?? this.isOnline,
      lastSeenText: lastSeenText ?? this.lastSeenText,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      badgeTitle: badgeTitle ?? this.badgeTitle,
      badgeText: badgeText ?? this.badgeText,
      badgeIcon: badgeIcon ?? this.badgeIcon,
      isPinned: isPinned ?? this.isPinned,
    );
  }

}
