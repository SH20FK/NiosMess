import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';

class NotificationPreferences {
  const NotificationPreferences({
    this.privateMessages = true,
    this.groups = true,
    this.channels = true,
    this.calls = true,
    this.activity = true,
    this.preview = true,
    this.sound = true,
  });
  final bool privateMessages, groups, channels, calls, activity, preview, sound;

  /// Whether message notifications for [chatKind] are on. `chatKind` is the
  /// wire discriminator (`private`, `group`, `channel`) or a local chat type
  /// (`direct`). Unknown kinds — legacy pushes without `chat_kind`, reminders —
  /// stay visible unless every kind is switched off.
  bool messagesEnabledFor(String? chatKind) => switch (chatKind) {
    'private' || 'direct' => privateMessages,
    'group' => groups,
    'channel' => channels,
    _ => privateMessages || groups || channels,
  };

  Map<String, dynamic> toJson() => {
    'private': privateMessages,
    'groups': groups,
    'channels': channels,
    // Belt for a server that predates the three kinds: anything switched on
    // keeps its old behaviour, everything off stays silent.
    'messages': privateMessages || groups || channels,
    'calls': calls,
    'activity': activity,
    'preview': preview,
    'sound': sound,
  };
  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    // Legacy JSON stored one `messages` switch. Without any new key it decides
    // all three kinds; once a new key appears the new keys win and `messages`
    // is ignored.
    final bool legacyMessages = json['messages'] != false;
    final bool hasNewKeys =
        json.containsKey('private') ||
        json.containsKey('groups') ||
        json.containsKey('channels');
    bool kind(String key) => hasNewKeys ? json[key] != false : legacyMessages;
    return NotificationPreferences(
      privateMessages: kind('private'),
      groups: kind('groups'),
      channels: kind('channels'),
      calls: json['calls'] != false,
      activity: json['activity'] != false,
      preview: json['preview'] != false,
      sound: json['sound'] != false,
    );
  }
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
