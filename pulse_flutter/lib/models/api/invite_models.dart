class ApiInvitePreview {
  const ApiInvitePreview({
    required this.chatId,
    required this.name,
    required this.chatType,
    required this.description,
    required this.membersCount,
    this.username,
    this.avatarUrl,
    this.inviteLink,
    this.shareLink,
  });

  final int chatId;
  final String name;
  final String chatType;
  final String description;
  final int membersCount;
  final String? username;
  final String? avatarUrl;
  final String? inviteLink;
  final String? shareLink;

  factory ApiInvitePreview.fromJson(Map<String, dynamic> json) {
    return ApiInvitePreview(
      chatId: json['id'] as int? ?? (json['chat_id'] as int? ?? 0),
      name: json['name'] as String? ?? '',
      chatType: json['chat_type'] as String? ?? '',
      description: json['description'] as String? ?? '',
      username: json['username'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      membersCount: json['members_count'] as int? ?? 0,
      inviteLink: json['invite_link'] as String?,
      shareLink: json['share_link'] as String?,
    );
  }
}

class ApiJoinBySlugResult {
  const ApiJoinBySlugResult({
    required this.chatId,
    required this.name,
    required this.message,
    this.inviteLink,
    this.shareLink,
  });

  final int chatId;
  final String name;
  final String message;
  final String? inviteLink;
  final String? shareLink;

  factory ApiJoinBySlugResult.fromJson(Map<String, dynamic> json) {
    return ApiJoinBySlugResult(
      chatId: json['chat_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      message: json['message'] as String? ?? 'Joined successfully',
      inviteLink: json['invite_link'] as String?,
      shareLink: json['share_link'] as String?,
    );
  }
}
