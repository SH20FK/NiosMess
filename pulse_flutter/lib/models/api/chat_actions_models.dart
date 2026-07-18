class DirectChatWithUser {
  const DirectChatWithUser({
    required this.id,
    required this.username,
    required this.displayName,
    this.publicKey,
  });

  final int id;
  final String username;
  final String displayName;
  final String? publicKey;

  factory DirectChatWithUser.fromJson(Map<String, dynamic> json) {
    return DirectChatWithUser(
      id: json['id'] as int? ?? 0,
      username: json['username'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      publicKey: json['public_key'] as String?,
    );
  }
}

class DirectChatOpenResult {
  const DirectChatOpenResult({
    required this.chatId,
    required this.chatType,
    this.isSecret = false,
    this.withUser,
  });

  final int chatId;
  final String chatType;
  final bool isSecret;
  final DirectChatWithUser? withUser;

  String? get username => withUser?.username;

  factory DirectChatOpenResult.fromJson(Map<String, dynamic> json) {
    final dynamic withUserRaw = json['with_user'];
    return DirectChatOpenResult(
      chatId: json['chat_id'] as int? ?? 0,
      chatType: json['chat_type'] as String? ?? 'direct',
      isSecret: json['is_secret'] == true || json['is_secret'] == 1 || json['is_secret'] == '1' || json['is_secret'] == 'true',
      withUser: withUserRaw is Map<String, dynamic>
          ? DirectChatWithUser.fromJson(withUserRaw)
          : (withUserRaw is Map
              ? DirectChatWithUser.fromJson(
                  withUserRaw.map((k, v) => MapEntry(k.toString(), v)))
              : null),
    );
  }
}

class ApiKeyDevice {
  const ApiKeyDevice({
    required this.sessionId,
    required this.deviceInfo,
    required this.publicKey,
  });

  final int sessionId;
  final String deviceInfo;
  final String publicKey;

  factory ApiKeyDevice.fromJson(Map<String, dynamic> json) {
    return ApiKeyDevice(
      sessionId: json['session_id'] as int? ?? 0,
      deviceInfo: json['device_info'] as String? ?? '',
      publicKey: json['public_key'] as String? ?? '',
    );
  }
}

class ApiPublicKeyResult {
  const ApiPublicKeyResult({
    required this.userId,
    required this.username,
    this.devices = const [],
  });

  final int userId;
  final String username;
  final List<ApiKeyDevice> devices;

  factory ApiPublicKeyResult.fromJson(Map<String, dynamic> json) {
    final devicesRaw = json['devices'];
    final List<ApiKeyDevice> devices;
    if (devicesRaw is List) {
      devices = devicesRaw
          .whereType<Map>()
          .map((Map item) => ApiKeyDevice.fromJson(
                item.map((k, v) => MapEntry(k.toString(), v)),
              ))
          .toList(growable: false);
    } else {
      devices = const [];
    }
    return ApiPublicKeyResult(
      userId: json['user_id'] as int? ?? 0,
      username: json['username'] as String? ?? '',
      devices: devices,
    );
  }
}

class ApiEraseSecretResult {
  const ApiEraseSecretResult({
    required this.status,
    required this.deletedChatsCount,
    required this.deletedFilesCount,
    required this.message,
  });

  final String status;
  final int deletedChatsCount;
  final int deletedFilesCount;
  final String message;

  bool get isSuccess => status == 'success';

  factory ApiEraseSecretResult.fromJson(Map<String, dynamic> json) {
    return ApiEraseSecretResult(
      status: json['status'] as String? ?? '',
      deletedChatsCount: json['deleted_chats_count'] as int? ?? 0,
      deletedFilesCount: json['deleted_files_count'] as int? ?? 0,
      message: json['message'] as String? ?? '',
    );
  }
}

class ChatCreateResult {
  const ChatCreateResult({
    required this.chatId,
    required this.name,
    this.username,
    this.inviteLink,
    this.shareLink,
    this.commentsChatId,
  });

  final int chatId;
  final String name;
  final String? username;
  final String? inviteLink;
  final String? shareLink;
  final int? commentsChatId;

  factory ChatCreateResult.fromJson(Map<String, dynamic> json) {
    return ChatCreateResult(
      chatId: json['chat_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      username: json['username'] as String?,
      inviteLink: json['invite_link'] as String?,
      shareLink: json['share_link'] as String?,
      commentsChatId: json['comments_chat_id'] as int?,
    );
  }
}
