import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'storage/offline_cache.dart';
import 'repositories/api_repository.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  String? _sessionUsername;
  String? _sessionToken;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _messageSub;

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  Future<void> init() async {
    if (!_isMobile) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _local.initialize(const InitializationSettings(android: androidSettings));

    await FirebaseMessaging.instance.requestPermission();

    // Cancel existing subscriptions to prevent duplicates on re-init
    await _tokenRefreshSub?.cancel();
    await _messageSub?.cancel();

    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      if (_sessionUsername != null && _sessionToken != null) {
        _registerToken(token);
      }
    });

    _messageSub = FirebaseMessaging.onMessage.listen((event) async {
      final title = event.notification?.title ?? 'Сообщение';
      final body = event.notification?.body ?? '';
      if (!await _shouldShowForData(event.data)) return;
      _showLocal(title, body);
    });
  }

  Future<void> dispose() async {
    if (!_isMobile) return;
    await _tokenRefreshSub?.cancel();
    await _messageSub?.cancel();
    _tokenRefreshSub = null;
    _messageSub = null;
  }

  Future<void> setSession(String username, String token) async {
    if (!_isMobile) return;
    _sessionUsername = username;
    _sessionToken = token;
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      await _registerToken(fcmToken);
    }
  }

  Future<void> clearSession() async {
    if (!_isMobile) return;
    final username = _sessionUsername;
    final token = _sessionToken;
    _sessionUsername = null;
    _sessionToken = null;
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (username != null && token != null && fcmToken != null) {
      await ApiRepository().unregisterPushToken(
        username: username,
        sessionToken: token,
        fcmToken: fcmToken,
      );
    }
  }

  Future<void> _showLocal(String title, String body) async {
    final settings = await OfflineCache.loadSettings();
    final showPreview = (settings['notify_preview'] as bool?) ?? true;
    final playSound = (settings['notify_sound'] as bool?) ?? true;
    final vibrate = (settings['notify_vibrate'] as bool?) ?? true;
    final android = AndroidNotificationDetails(
      'niosmess_messages',
      'Сообщения',
      importance: Importance.high,
      priority: Priority.high,
      playSound: playSound,
      enableVibration: vibrate,
      vibrationPattern: vibrate ? Int64List.fromList([0, 200, 120, 200]) : null,
    );
    final details = NotificationDetails(android: android);
    await _local.show(DateTime.now().millisecondsSinceEpoch ~/ 1000, title, showPreview ? body : '', details);
  }

  Future<bool> _shouldShowForData(Map<String, dynamic> data) async {
    final settings = await OfflineCache.loadSettings();
    final allowGroups = (settings['notify_group'] as bool?) ?? true;
    final allowMentions = (settings['notify_mentions'] as bool?) ?? true;
    final allowCalls = (settings['notify_calls'] as bool?) ?? true;
    final allowReactions = (settings['notify_reactions'] as bool?) ?? true;
    final quietStart = settings['quiet_hours_start'] as String?;
    final quietEnd = settings['quiet_hours_end'] as String?;
    if (_isInQuietHours(quietStart, quietEnd)) {
      return false;
    }
    final chatType = data['chat_type']?.toString();
    final eventType = (data['event'] ?? data['type'] ?? chatType)?.toString();
    if ((chatType == 'group' || chatType == 'channel') && !allowGroups) {
      return false;
    }
    if (data['mention']?.toString() == '1' && !allowMentions) {
      return false;
    }
    if (eventType == 'call' && !allowCalls) {
      return false;
    }
    if (eventType == 'reaction' && !allowReactions) {
      return false;
    }
    return true;
  }

  bool _isInQuietHours(String? start, String? end) {
    if (start == null || end == null) return false;
    final startParts = start.split(':');
    final endParts = end.split(':');
    if (startParts.length != 2 || endParts.length != 2) return false;
    final startHour = int.tryParse(startParts[0]) ?? 0;
    final startMin = int.tryParse(startParts[1]) ?? 0;
    final endHour = int.tryParse(endParts[0]) ?? 0;
    final endMin = int.tryParse(endParts[1]) ?? 0;
    final now = TimeOfDay.now();
    final startTotal = startHour * 60 + startMin;
    final endTotal = endHour * 60 + endMin;
    final nowTotal = now.hour * 60 + now.minute;
    if (startTotal == endTotal) return false;
    if (startTotal < endTotal) {
      return nowTotal >= startTotal && nowTotal < endTotal;
    }
    return nowTotal >= startTotal || nowTotal < endTotal;
  }

  Future<void> _registerToken(String fcmToken) async {
    if (!_isMobile) return;
    final username = _sessionUsername;
    final token = _sessionToken;
    if (username == null || token == null) return;
    await ApiRepository().registerPushToken(
      username: username,
      sessionToken: token,
      fcmToken: fcmToken,
      platform: Platform.isIOS ? 'ios' : 'android',
    );
  }
}
