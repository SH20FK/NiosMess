import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/storage/notification_storage.dart';
import 'package:pulse_flutter/router/app_router.dart';
import 'package:go_router/go_router.dart';

class LocalNotificationsState {
  const LocalNotificationsState({
    this.notifications = const <AppNotification>[],
    this.unreadCount = 0,
  });

  final List<AppNotification> notifications;
  final int unreadCount;

  LocalNotificationsState copyWith({
    List<AppNotification>? notifications,
    int? unreadCount,
  }) {
    return LocalNotificationsState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class LocalNotificationsNotifier extends Notifier<LocalNotificationsState> {
  FlutterLocalNotificationsPlugin? _plugin;
  bool _initialized = false;

  @override
  LocalNotificationsState build() {
    _init();
    return const LocalNotificationsState();
  }

  Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;

    _plugin = FlutterLocalNotificationsPlugin();

    try {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings();
      await _plugin!.initialize(
        settings: const InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        ),
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
    } catch (e) {
      debugPrint('[LocalNotifications] Init error: $e');
    }

    await _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    final List<AppNotification> stored = await NotificationStorage.loadAll();
    final int unread = stored.where((AppNotification n) => !n.read).length;
    state = LocalNotificationsState(
      notifications: stored,
      unreadCount: unread,
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    final String? route = response.payload;
    if (route == null || route.isEmpty) return;
    final BuildContext? ctx = AppRouter.navigatorKey.currentContext;
    if (ctx != null) {
      ctx.go(route);
    }
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? route,
  }) async {
    final AppNotification notification = await NotificationStorage.createAndSave(
      title: title,
      body: body,
      route: route,
    );

    state = state.copyWith(
      notifications: <AppNotification>[notification, ...state.notifications],
      unreadCount: state.unreadCount + 1,
    );

    try {
      await _plugin?.show(
        id: notification.id,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'niosmess_main',
            'NiosMess',
            channelDescription: 'NiosMess notifications',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: route,
      );
    } catch (e) {
      debugPrint('[LocalNotifications] Show error: $e');
    }
  }

  Future<void> markAsRead(int id) async {
    await NotificationStorage.markRead(id);
    final List<AppNotification> updated = state.notifications.map((AppNotification n) {
      if (n.id == id) {
        n.read = true;
      }
      return n;
    }).toList();
    final int unread = updated.where((AppNotification n) => !n.read).length;
    state = state.copyWith(notifications: updated, unreadCount: unread);
  }

  Future<void> clearAll() async {
    await NotificationStorage.clearAll();
    state = const LocalNotificationsState();
  }
}

final localNotificationsProvider =
    NotifierProvider<LocalNotificationsNotifier, LocalNotificationsState>(
  LocalNotificationsNotifier.new,
);
