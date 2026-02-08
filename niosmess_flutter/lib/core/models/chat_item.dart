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
    return ChatItem(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      unread: (json['unread'] as num?)?.toInt() ?? 0,
      username: json['username'] as String?,
      isOnline: json['isonline'] as bool?,
      lastSeenText: json['last_seen_text'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      badgeTitle: json['badge_title'] as String?,
      badgeText: json['badge_text'] as String?,
      badgeIcon: json['badge_icon'] as String?,
      isPinned: json['is_pinned'] == true || json['is_pinned']?.toString() == '1',
    );
  }

}
