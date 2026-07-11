import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/router/app_router.dart';

@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  // Background messages are handled by the system tray notification
  // delivered via the `notification` payload in the FCM message.
  // No custom Dart logic needed here — Firebase handles display.
}

class PushNotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static StreamSubscription<RemoteMessage>? _openedAppSubscription;
  static int _notificationIdCounter = 0;
  static int? _currentChatId;

  static void setCurrentChat(int? chatId) {
    _currentChatId = chatId;
  }

  static Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

    final NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();
    await _local.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'niosmess_messages',
      'NiosMess Messages',
      description: 'Уведомления о новых сообщениях',
      importance: Importance.high,
      playSound: true,
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _foregroundSubscription?.cancel();
    await _openedAppSubscription?.cancel();
    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      _onForegroundMessage,
    );
    _openedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _onNotificationTap2,
    );

    final RemoteMessage? initial = await _fcm.getInitialMessage();
    if (initial != null) _handleNavigation(initial.data);
  }

  static Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _openedAppSubscription?.cancel();
    _foregroundSubscription = null;
    _openedAppSubscription = null;
  }

  static Future<String?> getToken() async {
    return await _fcm.getToken();
  }

  static Stream<String> get onTokenRefresh => _fcm.onTokenRefresh;

  static Future<void> _onForegroundMessage(RemoteMessage message) async {
    final Map<String, dynamic> data = message.data;
    final String title = message.notification?.title ?? 'NiosMess';
    final String body = message.notification?.body ?? '';

    final Object? chatIdRaw = data['chat_id'];
    final int? chatId = chatIdRaw is int
        ? chatIdRaw
        : int.tryParse(chatIdRaw?.toString() ?? '');
    if (chatId != null && chatId == _currentChatId) return;

    await _local.show(
      id: ++_notificationIdCounter,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'niosmess_messages',
          'NiosMess Messages',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(data),
    );
  }

  static void _onNotificationTap(NotificationResponse response) {
    if (response.payload == null) return;
    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      _handleNavigation(data);
    } catch (_) {}
  }

  static void _onNotificationTap2(RemoteMessage message) {
    _handleNavigation(message.data);
  }

  static void _handleNavigation(Map<String, dynamic> data) {
    final String? route = data['route']?.toString();
    if (route != null && route.isNotEmpty) {
      AppRouter.navigatorKey.currentContext?.go(route);
      return;
    }

    final Object? chatIdRaw = data['chat_id'];
    final int? chatId = chatIdRaw is int
        ? chatIdRaw
        : int.tryParse(chatIdRaw?.toString() ?? '');
    if (chatId != null) {
      AppRouter.navigatorKey.currentContext?.go('/chat/$chatId');
      return;
    }

    final String? username = data['username']?.toString();
    if (username != null && username.isNotEmpty) {
      AppRouter.navigatorKey.currentContext?.go('/profile/$username');
    }
  }
}
