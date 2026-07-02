import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/utils/shared_utilities.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';

enum AppNotificationType { message, postLike, postComment, other }

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.payload,
    this.isRead = false,
  });

  final String id;
  final AppNotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final Map<String, dynamic>? payload;
  final bool isRead;

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        createdAt: createdAt,
        payload: payload,
        isRead: isRead ?? this.isRead,
      );

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final String typeStr = json['type'] as String? ?? '';
    final AppNotificationType type = switch (typeStr) {
      'message' => AppNotificationType.message,
      'post_like' => AppNotificationType.postLike,
      'post_comment' => AppNotificationType.postComment,
      _ => AppNotificationType.other,
    };
    return AppNotification(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      title: json['title'] as String? ?? 'NiosMess',
      body: json['body'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      payload: json['payload'] is Map
          ? asStringMap(json['payload'] as Map)
          : null,
    );
  }
}

class NotificationsState {
  const NotificationsState({
    this.notifications = const <AppNotification>[],
    this.unreadCount = 0,
  });

  final List<AppNotification> notifications;
  final int unreadCount;

  NotificationsState copyWith({
    List<AppNotification>? notifications,
    int? unreadCount,
  }) => NotificationsState(
        notifications: notifications ?? this.notifications,
        unreadCount: unreadCount ?? this.unreadCount,
      );
}

class NotificationsNotifier extends Notifier<NotificationsState> {
  static const int _maxNotifications = 50;
  StreamSubscription<dynamic>? _sub;

  @override
  NotificationsState build() {
    _sub = ref.read(webSocketClientProvider).pushStream.listen(_handlePush);
    ref.onDispose(() => _sub?.cancel());
    return const NotificationsState();
  }

  void _handlePush(dynamic event) {
    if (event is! Map) return;
    final Map<String, dynamic> msg = asStringMap(event);
    if (msg['action'] != 'notification') return;

    final dynamic data = msg['data'];
    if (data is! Map) return;
    final Map<String, dynamic> dataMap = asStringMap(data);

    final AppNotification notification = AppNotification.fromJson(dataMap);

    final bool alreadyExists = state.notifications.any(
      (AppNotification n) => n.id == notification.id,
    );
    if (alreadyExists) return;

    final List<AppNotification> updated = <AppNotification>[
      notification,
      ...state.notifications,
    ].take(_maxNotifications).toList(growable: false);

    state = state.copyWith(
      notifications: updated,
      unreadCount: state.unreadCount + 1,
    );
  }

  void markAllRead() {
    final List<AppNotification> updated = state.notifications
        .map((AppNotification n) => n.copyWith(isRead: true))
        .toList(growable: false);
    state = state.copyWith(notifications: updated, unreadCount: 0);
  }

  void clear() {
    state = const NotificationsState();
  }
}

final NotifierProvider<NotificationsNotifier, NotificationsState>
    notificationsProvider =
    NotifierProvider<NotificationsNotifier, NotificationsState>(
  NotificationsNotifier.new,
);
