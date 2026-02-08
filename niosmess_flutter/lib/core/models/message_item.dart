class MessageItem {
  MessageItem({
    required this.id,
    required this.sender,
    required this.text,
    required this.time,
    this.type,
    this.replyToId,
    this.meta,
    this.isPinned = false,
    this.isRead = false,
    this.isOutgoing = false,
  });

  final String id;
  final String sender;
  final String text;
  final String time;
  final String? type;
  final String? replyToId;
  final Map<String, dynamic>? meta;
  final bool isPinned;
  final bool isRead;
  final bool isOutgoing;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender': sender,
      'text': text,
      'time': time,
      'type': type,
      'reply_to': replyToId,
      'meta': meta,
      'is_pinned': isPinned,
      'is_read': isRead,
      'is_outgoing': isOutgoing,
    };
  }

  factory MessageItem.fromJson(Map<String, dynamic> json) {
    return MessageItem(
      id: json['id'].toString(),
      sender: json['sender'] as String? ?? '',
      text: json['text'] as String? ?? '',
      time: json['time']?.toString() ?? '',
      type: json['type'] as String?,
      replyToId: json['reply_to']?.toString(),
      meta: json['meta'] is Map<String, dynamic> ? Map<String, dynamic>.from(json['meta']) : null,
      isPinned: json['is_pinned'] == true || json['is_pinned']?.toString() == '1',
      isRead: json['is_read'] == true || json['is_read']?.toString() == '1',
      isOutgoing: json['is_outgoing'] == true || json['is_outgoing']?.toString() == '1',
    );
  }
}
