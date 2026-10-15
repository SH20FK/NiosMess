import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/services/push_notification_service.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:universal_io/io.dart';

int _latestNotificationAction = 0;

/// Called by explicit notification controls, never by bootstrap or hydration.
Future<bool> updateNotificationPreference(WidgetRef ref, bool enabled) async {
  final action = ++_latestNotificationAction;
  final session = ref.read(authProvider).session;
  var granted = enabled;
  if (enabled && (kIsWeb || Platform.isAndroid || Platform.isIOS)) {
    granted = await PushNotificationService.requestPermission();
  }
  if (!ref.context.mounted || action != _latestNotificationAction) return false;
  if (!identical(ref.read(authProvider).session, session)) return false;
  ref.read(uiSettingsProvider.notifier).setNotifications(granted);
  if (granted && ref.read(authProvider).isAuthenticated) {
    await ref.read(authProvider.notifier).refreshFcmTokenRegistration();
  }
  if (!ref.context.mounted || action != _latestNotificationAction) return false;
  if (!identical(ref.read(authProvider).session, session)) return false;
  if (ref.read(uiSettingsProvider).notifications != granted) return false;
  return granted;
}
