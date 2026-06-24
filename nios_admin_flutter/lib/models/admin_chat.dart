class AdminChat {
  const AdminChat({
    required this.id,
    required this.name,
    required this.chatType,
    required this.username,
    required this.isBanned,
    required this.membersCount,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String chatType;
  final String? username;
  final bool isBanned;
  final int membersCount;
  final DateTime createdAt;

  factory AdminChat.fromJson(Map<String, dynamic> json) {
    return AdminChat(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      chatType: json['chat_type']?.toString() ?? 'group',
      username: json['username']?.toString(),
      isBanned: json['is_banned'] == true,
      membersCount: (json['members_count'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
