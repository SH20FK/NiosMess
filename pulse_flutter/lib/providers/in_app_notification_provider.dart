import 'dart:async';
import 'dart:collection';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/notification_preferences_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

class InAppNotificationItem {
  final String id;
  final String title;
  final String body;
  final String? avatarUrl;
  final String? route;
  final int? chatId;
  final IconData? icon;
  final DateTime timestamp;

  const InAppNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    this.avatarUrl,
    this.route,
    this.chatId,
    this.icon,
    required this.timestamp,
  });
}

class InAppNotificationNotifier extends Notifier<InAppNotificationItem?> {
  Timer? _dismissTimer;
  final _queue = Queue<InAppNotificationItem>();
  bool _paused = false;

  @override
  InAppNotificationItem? build() {
    ref.watch(authProvider.select((s) => s.session?.userId));
    _dismissTimer?.cancel();
    _queue.clear();
    _paused = false;
    ref.onDispose(() {
      _dismissTimer?.cancel();
    });
    return null;
  }

  void show(InAppNotificationItem item) {
    final UiSettingsState uiSettings = ref.read(uiSettingsProvider);
    if (!uiSettings.notifications) return;

    if (state?.id == item.id ||
        (item.chatId != null && state?.chatId == item.chatId)) {
      state = item;
      _scheduleDismiss();
      return;
    }
    if (state != null) {
      _queue.removeWhere(
        (n) =>
            n.id == item.id || (item.chatId != null && n.chatId == item.chatId),
      );
      if (_queue.length == 8) _queue.removeFirst();
      _queue.addLast(item);
      return;
    }
    _present(item);
  }

  void _present(InAppNotificationItem item) {
    state = item;
    final ui = ref.read(uiSettingsProvider);
    try {
      if (ui.haptics) HapticService.tap();
      if (ref.read(notificationPreferencesProvider).value?.sound ??
          ui.soundEffects) {
        ref.read(appSoundProvider).playNotification(SoundEvent.messageReceive);
      }
    } catch (_) {}
    _scheduleDismiss();
  }

  void pause(bool paused) {
    _paused = paused;
    _scheduleDismiss();
  }

  void _scheduleDismiss() {
    _dismissTimer?.cancel();
    if (_paused ||
        state == null ||
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .accessibleNavigation) {
      return;
    }
    _dismissTimer = Timer(const Duration(seconds: 8), dismiss);
  }

  void clearAccount() {
    _dismissTimer?.cancel();
    _queue.clear();
    state = null;
  }

  void dismiss() {
    _paused = false;
    _dismissTimer?.cancel();
    state = null;
    if (_queue.isNotEmpty) {
      // Give the previous card time to leave before presenting the next one.
      _dismissTimer = Timer(const Duration(milliseconds: 260), () {
        if (_queue.isNotEmpty && ref.mounted) _present(_queue.removeFirst());
      });
    }
  }
}

final inAppNotificationProvider =
    NotifierProvider<InAppNotificationNotifier, InAppNotificationItem?>(
      InAppNotificationNotifier.new,
    );
