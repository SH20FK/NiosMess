class MessageItem {
  MessageItem({
    required this.id,
    required this.sender,
    required this.text,
    required this.time,
    this.type,
    this.lat,
    this.lon,
    this.contactData,
    this.replyToId,
    this.meta,
    this.localStatus = MessageLocalStatus.sent,
    this.isPinned = false,
    this.isRead = false,
    this.isOutgoing = false,
  });

  final String id;
  final String sender;
  final String text;
  final String time;
  final String? type;
  final double? lat;
  final double? lon;
  final String? contactData;
  final String? replyToId;
  final Map<String, dynamic>? meta;
  final MessageLocalStatus localStatus;
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
      'lat': lat,
      'lon': lon,
      'contact_data': contactData,
      'reply_to': replyToId,
      'meta': meta,
      'local_status': localStatus.name,
      'is_pinned': isPinned,
      'is_read': isRead,
      'is_outgoing': isOutgoing,
    };
  }

  factory MessageItem.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['local_status']?.toString();
    final localStatus = MessageLocalStatus.values.firstWhere(
      (e) => e.name == rawStatus,
      orElse: () => MessageLocalStatus.sent,
    );
    return MessageItem(
      id: json['id'].toString(),
      sender: json['sender'] as String? ?? '',
      text: json['text'] as String? ?? '',
      time: json['time']?.toString() ?? '',
      type: json['type'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
      contactData: json['contact_data']?.toString(),
      replyToId: json['reply_to']?.toString(),
      meta: json['meta'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['meta'])
          : null,
      localStatus: localStatus,
      isPinned:
          json['is_pinned'] == true || json['is_pinned']?.toString() == '1',
      isRead: json['is_read'] == true || json['is_read']?.toString() == '1',
      isOutgoing:
          json['is_outgoing'] == true || json['is_outgoing']?.toString() == '1',
    );
  }
}

enum MessageLocalStatus { sent, queued, failed }
