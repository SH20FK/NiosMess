import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AppNotification {
  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.route,
    this.read = false,
  });

  final int id;
  final String title;
  final String body;
  final DateTime timestamp;
  final String? route;
  bool read;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'body': body,
        'timestamp': timestamp.toIso8601String(),
        'route': route,
        'read': read,
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as int,
        title: json['title'] as String,
        body: json['body'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        route: json['route'] as String?,
        read: json['read'] as bool? ?? false,
      );
}

class NotificationStorage {
  static const String _boxName = 'app_notifications_v1';

  static Future<Box<String>> _openBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<String>(_boxName);
    }
    return Hive.openBox<String>(_boxName);
  }

  static Future<List<AppNotification>> loadAll() async {
    try {
      final Box<String> box = await _openBox();
      final List<AppNotification> notifications = [];
      for (final String value in box.values) {
        final Map<String, dynamic> json =
            jsonDecode(value) as Map<String, dynamic>;
        notifications.add(AppNotification.fromJson(json));
      }
      notifications.sort(
          (AppNotification a, AppNotification b) => b.timestamp.compareTo(a.timestamp));
      return notifications;
    } catch (e) {
      debugPrint('[NotificationStorage] Load error: $e');
      return [];
    }
  }

  static Future<void> save(AppNotification notification) async {
    try {
      final Box<String> box = await _openBox();
      await box.put(notification.id.toString(), jsonEncode(notification.toJson()));
    } catch (e) {
      debugPrint('[NotificationStorage] Save error: $e');
    }
  }

  static Future<void> markRead(int id) async {
    try {
      final Box<String> box = await _openBox();
      final String? raw = box.get(id.toString());
      if (raw == null) return;
      final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
      json['read'] = true;
      await box.put(id.toString(), jsonEncode(json));
    } catch (e) {
      debugPrint('[NotificationStorage] MarkRead error: $e');
    }
  }

  static Future<void> clearAll() async {
    try {
      final Box<String> box = await _openBox();
      await box.clear();
    } catch (e) {
      debugPrint('[NotificationStorage] ClearAll error: $e');
    }
  }

  static int _nextId() => DateTime.now().millisecondsSinceEpoch.remainder(100000);

  static Future<AppNotification> createAndSave({
    required String title,
    required String body,
    String? route,
  }) async {
    final AppNotification notification = AppNotification(
      id: _nextId(),
      title: title,
      body: body,
      timestamp: DateTime.now(),
      route: route,
    );
    await save(notification);
    return notification;
  }
}
