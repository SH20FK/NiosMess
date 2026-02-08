import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'storage/offline_cache.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _local.initialize(const InitializationSettings(android: androidSettings));

    await FirebaseMessaging.instance.requestPermission();

    FirebaseMessaging.onMessage.listen((event) {
      final title = event.notification?.title ?? 'Сообщение';
      final body = event.notification?.body ?? '';
      _showLocal(title, body);
    });
  }

  Future<void> _showLocal(String title, String body) async {
    final settings = await OfflineCache.loadSettings();
    final showPreview = (settings['notify_preview'] as bool?) ?? true;
    final playSound = (settings['notify_sound'] as bool?) ?? true;
    final android = AndroidNotificationDetails(
      'niosmess_messages',
      'Сообщения',
      importance: Importance.high,
      priority: Priority.high,
      playSound: playSound,
    );
    final details = NotificationDetails(android: android);
    await _local.show(DateTime.now().millisecondsSinceEpoch ~/ 1000, title, showPreview ? body : '', details);
  }
}

