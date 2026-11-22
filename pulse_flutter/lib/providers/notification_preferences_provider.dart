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

  Future<void> _writes = Future<void>.value();

  /// Writes run one after another. Each starts from the result of the
  /// previous one, so two switches flipped back to back keep both values.
  Future<void> _apply(
    NotificationPreferences? Function(NotificationPreferences current) change,
  ) async {
    final Future<bool> write = _writes.then((_) => _write(change));
    _writes = write.then<void>((_) {}, onError: (Object _) {});
    if (!await write || !ref.mounted) return;
    await ref.read(authProvider.notifier).refreshFcmTokenRegistration();
  }

  /// A null result of [change] removes the stored value.
  Future<bool> _write(
    NotificationPreferences? Function(NotificationPreferences current) change,
  ) async {
    final account = ref.read(authProvider).session?.userId;
    final current = await future;
    if (!ref.mounted || ref.read(authProvider).session?.userId != account) {
      return false;
    }
    final next = change(current);
    final prefs = await SharedPreferences.getInstance();
    final storageKey = 'notification_preferences_$account';
    final stored = next == null
        ? await prefs.remove(storageKey)
        : await prefs.setString(storageKey, jsonEncode(next.toJson()));
    if (!stored) throw StateError('NOTIFICATION_PREFERENCE_WRITE');
    if (!ref.mounted || ref.read(authProvider).session?.userId != account) {
      return false;
    }
    state = AsyncData(next ?? const NotificationPreferences());
    return true;
  }

  Future<void> setPreference(String key, bool enabled) => _apply(
    (current) =>
        NotificationPreferences.fromJson({...current.toJson(), key: enabled}),
  );

  /// Back to defaults: every category on.
  Future<void> reset() => _apply((_) => null);
}

final notificationPreferencesProvider =
    AsyncNotifierProvider<
      NotificationPreferencesNotifier,
      NotificationPreferences
    >(NotificationPreferencesNotifier.new);
