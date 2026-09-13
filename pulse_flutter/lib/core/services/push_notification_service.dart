import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/router/app_router.dart';

@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  // Data-only messages need manual local notification display
  if (message.notification != null) return;
  await PushNotificationService.showLocalNotification(message.data);
}

class PushNotificationService {
  static const String kVapidKey =
      'BKSYxeF_VSU0itkdSfWOKu6t6fn7bw4Kleb-hwnRn57lg0qj-VFAAGeLHVlO1Xg5KG0F2o43vQgBZBrHNv3Eu2w';

  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static StreamSubscription<RemoteMessage>? _openedAppSubscription;
  static int _notificationIdCounter = 0;
  static int? _currentChatId;

  static int? get currentChatId => _currentChatId;

  static void setCurrentChat(int? chatId) {
    _currentChatId = chatId;
  }

  static Future<bool> requestPermission() async {
    try {
      final NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      debugPrint('[PushNotificationService] requestPermission failed: $e');
      return false;
    }
  }

  static Future<bool> isPermissionGranted() async {
    try {
      final NotificationSettings settings = await _fcm.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (_) {
      return false;
    }
  }

  static bool _shouldIgnorePush(String title, String body) {
    final String cleanTitle = title.trim().toLowerCase();
    final String cleanBody = body.trim().toLowerCase();
    if (cleanTitle == 'new activity' ||
        cleanBody == 'new activity' ||
        (cleanTitle.isEmpty && cleanBody.isEmpty)) {
      return true;
    }
    return false;
  }

  static NotificationDetails _buildNotificationDetails({
    required String title,
    required String body,
    required bool isCall,
    int? chatId,
  }) {
    final String channelId = isCall ? 'niosmess_calls' : 'niosmess_messages';
    final String channelName = isCall ? 'NiosMess Calls' : 'NiosMess Messages';

    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: isCall
            ? 'Уведомления о входящих звонках NiosMess'
            : 'Уведомления о новых сообщениях NiosMess',
        importance: isCall ? Importance.max : Importance.high,
        priority: isCall ? Priority.max : Priority.high,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFF6750A4),
        category: isCall
            ? AndroidNotificationCategory.call
            : AndroidNotificationCategory.message,
        styleInformation: BigTextStyleInformation(
          body,
          htmlFormatBigText: false,
          contentTitle: title,
          htmlFormatContentTitle: false,
          summaryText: isCall ? 'Звонок NiosMess' : 'NiosMess',
          htmlFormatSummaryText: false,
        ),
        groupKey: chatId != null ? 'niosmess_chat_$chatId' : 'niosmess_general',
        subText: isCall ? 'Входящий звонок' : 'Новое сообщение',
        enableLights: true,
        ledColor: const Color(0xFF6750A4),
        ledOnMs: 1000,
        ledOffMs: 500,
        enableVibration: true,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('notification'),
        ticker: title,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: isCall
            ? InterruptionLevel.timeSensitive
            : InterruptionLevel.active,
        threadIdentifier: chatId != null ? 'chat_$chatId' : 'general',
      ),
    );
  }

  static Future<void> showLocalNotification(Map<String, dynamic> data) async {
    final String title = data['title']?.toString() ?? data['route']?.toString() ?? 'NiosMess';
    final String body = data['body']?.toString() ?? '';
    if (_shouldIgnorePush(title, body)) return;

    final Object? chatIdRaw = data['chat_id'];
    final int? chatId = chatIdRaw is int
        ? chatIdRaw
        : int.tryParse(chatIdRaw?.toString() ?? '');

    final bool isCall = data['type'] == 'incoming_call';

    await _local.show(
      id: ++_notificationIdCounter,
      title: title,
      body: body,
      notificationDetails: _buildNotificationDetails(
        title: title,
        body: body,
        isCall: isCall,
        chatId: chatId,
      ),
      payload: jsonEncode(data),
    );
  }

  static Future<void> init() async {
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
    }

    // On mobile, request permission during init; on web, permission can be requested via user gesture.
    if (!kIsWeb) {
      try {
        await _fcm.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      } catch (e) {
        debugPrint('[PushNotificationService] requestPermission error: $e');
      }
    }

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

    const AndroidNotificationChannel messagesChannel = AndroidNotificationChannel(
      'niosmess_messages',
      'NiosMess Messages',
      description: 'Уведомления о новых сообщениях',
      importance: Importance.high,
      playSound: true,
    );
    const AndroidNotificationChannel callsChannel = AndroidNotificationChannel(
      'niosmess_calls',
      'NiosMess Calls',
      description: 'Уведомления о входящих звонках',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(messagesChannel);
      await androidPlugin.createNotificationChannel(callsChannel);
    }

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
    try {
      if (kIsWeb) {
        return await _fcm.getToken(vapidKey: kVapidKey);
      }
      return await _fcm.getToken();
    } catch (e) {
      debugPrint('[PushNotificationService] getToken failed: $e');
      return null;
    }
  }

  static Stream<String> get onTokenRefresh => _fcm.onTokenRefresh;

  static Future<void> _onForegroundMessage(RemoteMessage message) async {
    final Map<String, dynamic> data = message.data;
    final String title = message.notification?.title
        ?? data['title']?.toString()
        ?? 'NiosMess';
    final String body = message.notification?.body
        ?? data['body']?.toString()
        ?? '';

    if (_shouldIgnorePush(title, body)) return;

    final Object? chatIdRaw = data['chat_id'];
    final int? chatId = chatIdRaw is int
        ? chatIdRaw
        : int.tryParse(chatIdRaw?.toString() ?? '');
    if (chatId != null && chatId == _currentChatId) return;

    final bool isCall = data['type'] == 'incoming_call';

    await _local.show(
      id: ++_notificationIdCounter,
      title: title,
      body: body,
      notificationDetails: _buildNotificationDetails(
        title: title,
        body: body,
        isCall: isCall,
        chatId: chatId,
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
