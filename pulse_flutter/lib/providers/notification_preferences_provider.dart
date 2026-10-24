import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';

class NotificationPreferences {
  const NotificationPreferences({
    this.messages = true,
    this.calls = true,
    this.activity = true,
    this.preview = true,
    this.sound = true,
  });
  final bool messages, calls, activity, preview, sound;
  Map<String, dynamic> toJson() => {
    'messages': messages,
    'calls': calls,
    'activity': activity,
    'preview': preview,
    'sound': sound,
  };
  factory NotificationPreferences.fromJson(Map<String, dynamic> json) =>
      NotificationPreferences(
        messages: json['messages'] != false,
        calls: json['calls'] != false,
        activity: json['activity'] != false,
        preview: json['preview'] != false,
        sound: json['sound'] != false,
      );
}

class NotificationPreferencesNotifier
    extends AsyncNotifier<NotificationPreferences> {
  @override
  Future<NotificationPreferences> build() async {
    final account = ref.watch(authProvider.select((s) => s.session?.userId));
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('notification_preferences_$account');
    if (raw == null) return const NotificationPreferences();
    return NotificationPreferences.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  Future<void> setPreference(String key, bool enabled) async {
    final account = ref.read(authProvider).session?.userId;
    final current = await future;
    if (!ref.mounted || ref.read(authProvider).session?.userId != account) {
      return;
    }
    final next = NotificationPreferences.fromJson({
      ...current.toJson(),
      key: enabled,
    });
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      'notification_preferences_$account',
      jsonEncode(next.toJson()),
    )) {
      throw StateError('NOTIFICATION_PREFERENCE_WRITE');
    }
    if (!ref.mounted || ref.read(authProvider).session?.userId != account) {
      return;
    }
    state = AsyncData(next);
    await ref.read(authProvider.notifier).refreshFcmTokenRegistration();
  }
}

final notificationPreferencesProvider =
    AsyncNotifierProvider<
      NotificationPreferencesNotifier,
      NotificationPreferences
    >(NotificationPreferencesNotifier.new);
