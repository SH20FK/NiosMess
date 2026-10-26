import 'package:pulse_flutter/models/api/chat_summary_model.dart';

class ChatFolder {
  const ChatFolder({
    required this.id,
    required this.title,
    this.chatIds = const [],
    this.types = const [],
    this.unreadOnly = false,
    this.position = 0,
    this.version = 0,
  });
  final String id, title;
  final List<int> chatIds;
  final List<String> types;
  final bool unreadOnly;
  final int position, version;
  factory ChatFolder.fromJson(Map<String, dynamic> j) {
    final rules = Map<String, dynamic>.from(j['rules'] as Map? ?? {});
    return ChatFolder(
      id: j['id'] as String,
      title: j['title'] as String,
      chatIds: (rules['chat_ids'] as List? ?? []).whereType<int>().toList(),
      types: (rules['types'] as List? ?? []).whereType<String>().toList(),
      unreadOnly: rules['unread_only'] == true,
      position: (j['position'] as num?)?.toInt() ?? 0,
      version: (j['version'] as num?)?.toInt() ?? 0,
    );
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'rules': {'chat_ids': chatIds, 'types': types, 'unread_only': unreadOnly},
    'position': position,
    'version': version,
  };
  bool includes(ApiChatSummary chat) =>
      chat.topicParentId == null &&
      (!unreadOnly || chat.unreadCount > 0) &&
      (chatIds.contains(chat.id) ||
          types.contains(chat.isBotChat ? 'bot' : chat.chatType));
}

class ChatTopic {
  const ChatTopic({
    required this.id,
    required this.title,
    this.closed = false,
    this.unreadCount = 0,
  });
  final int id, unreadCount;
  final String title;
  final bool closed;
  factory ChatTopic.fromJson(Map<String, dynamic> j) => ChatTopic(
    id: (j['id'] as num).toInt(),
    title: j['title'] as String,
    closed: j['closed'] == true,
    unreadCount: (j['unread_count'] as num?)?.toInt() ?? 0,
  );
}

class GroupTopics {
  const GroupTopics(this.chatId, this.canManage, this.topics);
  final int chatId;
  final bool canManage;
  final List<ChatTopic> topics;
  factory GroupTopics.fromJson(Map<String, dynamic> j) => GroupTopics(
    (j['chat_id'] as num).toInt(),
    j['can_manage'] == true,
    (j['topics'] as List? ?? [])
        .whereType<Map>()
        .map((m) => ChatTopic.fromJson(Map<String, dynamic>.from(m)))
        .toList(),
  );
}

class ScheduledChatMessage {
  const ScheduledChatMessage({
    required this.id,
    required this.chatId,
    required this.dueAt,
    required this.kind,
    required this.payload,
    this.state = 'pending',
    this.error,
    this.preview = '',
  });
  final String id, kind, state, preview;
  final String? error;
  final int chatId;
  final DateTime dueAt;
  final Map<String, dynamic> payload;
  factory ScheduledChatMessage.fromJson(
    Map<String, dynamic> j, {
    String preview = '',
  }) => ScheduledChatMessage(
    id: j['id'] as String,
    chatId: (j['chat_id'] as num).toInt(),
    dueAt: DateTime.parse(j['due_at'] as String).toLocal(),
    kind: j['kind'] as String,
    state: j['state'] as String,
    error: j['error'] as String?,
    payload: Map<String, dynamic>.from(j['payload'] as Map),
    preview: preview,
  );
}
