import 'dart:async';
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

  @override
  InAppNotificationItem? build() {
    ref.onDispose(() {
      _dismissTimer?.cancel();
    });
    return null;
  }

  void show(InAppNotificationItem item) {
    final UiSettingsState uiSettings = ref.read(uiSettingsProvider);
    if (!uiSettings.notifications) return;

    _dismissTimer?.cancel();
    state = item;

    try {
      if (uiSettings.haptics) {
        HapticService.tap();
      }
      if (uiSettings.soundEffects) {
        ref.read(appSoundProvider).playEvent(SoundEvent.messageReceive);
      }
    } catch (_) {}

    _dismissTimer = Timer(const Duration(milliseconds: 4200), () {
      if (state?.id == item.id) {
        dismiss();
      }
    });
  }

  void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    state = null;
  }
}

final inAppNotificationProvider =
    NotifierProvider<InAppNotificationNotifier, InAppNotificationItem?>(
  InAppNotificationNotifier.new,
);
