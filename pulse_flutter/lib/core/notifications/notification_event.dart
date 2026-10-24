/// Shared wire format for WebSocket, FCM, worker clicks and persisted history.
/// No platform dependencies: routing and identity checks also run in Dart tests.
class NotificationEvent {
  const NotificationEvent({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.accountId,
    this.chatId,
    this.route,
    this.avatarUrl,
    this.type = 'message',
    this.isRead = false,
    this.data = const {},
  });

  final String id, title, body, type;
  final DateTime createdAt;
  final int? accountId, chatId;
  final String? route, avatarUrl;
  final bool isRead;
  final Map<String, dynamic> data;

  bool get isCall => type == 'incoming_call';
  bool get isCancellation => type == 'call_ended';
  bool get isReadReceipt => type == 'chat_read';
  bool belongsTo(int account) => accountId == null || accountId == account;
  bool expiredAt(DateTime now) {
    final expiry = DateTime.tryParse(data['expires_at']?.toString() ?? '');
    return expiry != null
        ? !expiry.isAfter(now)
        : isCall && now.difference(createdAt) > const Duration(seconds: 90);
  }

  String? get target {
    if (chatId != null && chatId! > 0) return '/chat/$chatId';
    final candidate = route;
    // Only in-app locations. Never navigate to external URLs or auth endpoints.
    if (candidate != null &&
        RegExp(
          r'^/(chat/[0-9]+|niosgram(?:/post/[0-9]+/comments)?|profile/[\w.-]+)$',
        ).hasMatch(candidate)) {
      return candidate;
    }
    final username = data['username']?.toString();
    return username != null && RegExp(r'^[\w.-]+$').hasMatch(username)
        ? '/profile/$username'
        : null;
  }

  NotificationEvent read() => NotificationEvent(
    id: id,
    title: title,
    body: body,
    createdAt: createdAt,
    accountId: accountId,
    chatId: chatId,
    route: route,
    avatarUrl: avatarUrl,
    type: type,
    isRead: true,
    data: data,
  );

  Map<String, dynamic> toJson() => {
    ...data,
    'event_id': id,
    'title': title,
    'body': body,
    'created_at': createdAt.toUtc().toIso8601String(),
    'account_id': accountId,
    'chat_id': chatId,
    'route': route,
    'avatar_url': avatarUrl,
    'type': type,
    'is_read': isRead,
  };

  factory NotificationEvent.fromJson(
    Map<String, dynamic> json, {
    DateTime? now,
  }) {
    int? integer(Object? v) => int.tryParse(v?.toString() ?? '');
    final payload = json['payload'];
    final data = <String, dynamic>{
      ...json,
      if (payload is Map) ...payload.map((k, v) => MapEntry(k.toString(), v)),
    };
    final chat = integer(data['chat_id']);
    final message = data['message_id']?.toString();
    final type = data['type']?.toString() ?? 'message';
    final created =
        DateTime.tryParse(
          (data['created_at'] ?? data['timestamp'])?.toString() ?? '',
        ) ??
        now ??
        DateTime.now();
    return NotificationEvent(
      id:
          data['event_id']?.toString() ??
          (message != null && chat != null
              ? 'message:$chat:$message'
              : data['id']?.toString() ??
                    '$type:${created.microsecondsSinceEpoch}'),
      title: data['title']?.toString() ?? 'NiosMess',
      body: data['body']?.toString() ?? '',
      createdAt: created,
      accountId: integer(data['account_id']),
      chatId: chat,
      route: data['route']?.toString(),
      avatarUrl: data['avatar_url']?.toString(),
      type: type,
      isRead: data['is_read'] == true || data['read'] == true,
      data: data,
    );
  }
}

/// Updating an existing event preserves its read state and retained unread count.
List<NotificationEvent> mergeNotification(
  List<NotificationEvent> current,
  NotificationEvent event, {
  int limit = 100,
}) {
  final previous = current.where((n) => n.id == event.id).firstOrNull;
  final updated = previous?.isRead == true ? event.read() : event;
  return ([updated, ...current.where((n) => n.id != event.id)]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
      .take(limit)
      .toList(growable: false);
}

/// Stable Android IDs, independent of process restarts and Dart hash seeds.
int notificationSystemId(String value) {
  var result = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    result = ((result ^ unit) * 0x01000193) & 0x7fffffff;
  }
  return result;
}
