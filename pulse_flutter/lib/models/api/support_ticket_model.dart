import 'package:pulse_flutter/core/utils/server_time.dart';

class SupportTicketMessage {
  const SupportTicketMessage({
    required this.id,
    required this.ticketId,
    required this.senderRole,
    required this.body,
    this.senderId,
    this.senderUsername,
    this.createdAt,
  });

  final int id;
  final int ticketId;
  final int? senderId;
  final String senderRole; // 'user' or 'support'
  final String? senderUsername;
  final String body;
  final DateTime? createdAt;

  bool get isSupport => senderRole == 'support';

  factory SupportTicketMessage.fromJson(Map<String, dynamic> json) {
    return SupportTicketMessage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      ticketId: (json['ticket_id'] as num?)?.toInt() ?? 0,
      senderId: (json['sender_id'] as num?)?.toInt(),
      senderRole: json['sender_role'] as String? ?? 'user',
      senderUsername: json['sender_username'] as String?,
      body: json['body'] as String? ?? '',
      createdAt: parseServerUtc(json['created_at']),
    );
  }
}

class SpamBlockStatus {
  const SpamBlockStatus({
    required this.isBlocked,
    this.reason,
    this.blockedUntil,
    this.source,
    this.activeEventId,
    this.appealTicketId,
    this.canAppeal = false,
  });

  final bool isBlocked;
  final String? reason;
  final DateTime? blockedUntil;
  final String? source;
  final int? activeEventId;
  final int? appealTicketId;
  final bool canAppeal;

  factory SpamBlockStatus.fromJson(Map<String, dynamic> json) {
    return SpamBlockStatus(
      isBlocked: json['is_blocked'] as bool? ?? false,
      reason: json['reason'] as String?,
      blockedUntil: parseServerUtc(json['blocked_until']),
      source: json['source'] as String?,
      activeEventId: (json['active_event_id'] as num?)?.toInt(),
      appealTicketId: (json['appeal_ticket_id'] as num?)?.toInt(),
      canAppeal: json['can_appeal'] as bool? ?? false,
    );
  }
}

class SupportStatusOverview {
  const SupportStatusOverview({
    required this.spamBlock,
    this.openTicketsCount = 0,
    this.unreadSupportCount = 0,
  });

  final SpamBlockStatus spamBlock;
  final int openTicketsCount;
  final int unreadSupportCount;

  factory SupportStatusOverview.fromJson(Map<String, dynamic> json) {
    final rawSb = json['spam_block'];
    final Map<String, dynamic> sbMap = rawSb is Map
        ? rawSb.map((dynamic k, dynamic v) => MapEntry(k.toString(), v))
        : const <String, dynamic>{};
    return SupportStatusOverview(
      spamBlock: SpamBlockStatus.fromJson(sbMap),
      openTicketsCount: (json['open_tickets_count'] as num?)?.toInt() ?? 0,
      unreadSupportCount: (json['unread_support_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.ticketType,
    required this.subject,
    required this.body,
    this.category = 'general',
    this.priority = 'normal',
    this.status = 'open',
    this.resolution,
    this.lastPreview,
    this.unreadByUser = 0,
    this.messageCount = 1,
    this.lastMessageAt,
    this.closedAt,
    this.createdAt,
    this.updatedAt,
    this.messages = const <SupportTicketMessage>[],
  });

  final int id;
  final String ticketType;
  final String category;
  final String priority;
  final String subject;
  final String body;
  final String status;
  final String? resolution;
  final String? lastPreview;
  final int unreadByUser;
  final int messageCount;
  final DateTime? lastMessageAt;
  final DateTime? closedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<SupportTicketMessage> messages;

  bool get isCopyright => ticketType == 'copyright';
  bool get isSpamAppeal =>
      ticketType == 'spam_appeal' || category == 'spam_appeal';
  bool get isClosed => status == 'closed' || status == 'resolved';

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'];
    final List<SupportTicketMessage> parsedMessages = rawMessages is List
        ? rawMessages
            .whereType<Map>()
            .map(
              (m) => SupportTicketMessage.fromJson(
                m.map((dynamic k, dynamic v) => MapEntry(k.toString(), v)),
              ),
            )
            .toList(growable: false)
        : const <SupportTicketMessage>[];
    final String fallbackType = json['ticket_type'] as String? ?? 'support';
    return SupportTicket(
      id: (json['id'] as num?)?.toInt() ??
          (json['ticket_id'] as num?)?.toInt() ??
          0,
      ticketType: fallbackType,
      category: json['category'] as String? ??
          (fallbackType == 'spam_appeal' ? 'spam_appeal' : 'general'),
      priority: json['priority'] as String? ?? 'normal',
      subject: json['subject'] as String? ?? '',
      body: json['body'] as String? ?? '',
      status: json['status'] as String? ?? 'open',
      resolution: json['resolution'] as String?,
      lastPreview: json['last_preview'] as String?,
      unreadByUser: (json['unread_by_user'] as num?)?.toInt() ?? 0,
      messageCount: (json['message_count'] as num?)?.toInt() ??
          (parsedMessages.isNotEmpty ? parsedMessages.length : 1),
      lastMessageAt: parseServerUtc(json['last_message_at']),
      closedAt: parseServerUtc(json['closed_at']),
      createdAt: parseServerUtc(json['created_at']),
      updatedAt: parseServerUtc(json['updated_at']),
      messages: parsedMessages,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'ticket_type': ticketType,
      'category': category,
      'priority': priority,
      'subject': subject,
      'body': body,
      'status': status,
      if (resolution != null) 'resolution': resolution,
      if (lastPreview != null) 'last_preview': lastPreview,
      'unread_by_user': unreadByUser,
      'message_count': messageCount,
      if (lastMessageAt != null)
        'last_message_at': lastMessageAt!.toIso8601String(),
      if (closedAt != null) 'closed_at': closedAt!.toIso8601String(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }
}
