import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/services/push_notification_service.dart';

/// Whether the system lets the app post notifications: true, false, or null
/// when the status cannot be read. The answer changes in system settings,
/// outside the app, so it is read again on every resume.
class PushPermissionNotifier extends AsyncNotifier<bool?> {
  @override
  Future<bool?> build() {
    final AppLifecycleListener lifecycle = AppLifecycleListener(
      onResume: refresh,
    );
    ref.onDispose(lifecycle.dispose);
    return PushNotificationService.permissionState();
  }

  Future<void> refresh() async {
    final bool? granted = await PushNotificationService.permissionState();
    if (ref.mounted) state = AsyncData<bool?>(granted);
  }
}

final AsyncNotifierProvider<PushPermissionNotifier, bool?>
pushPermissionProvider = AsyncNotifierProvider<PushPermissionNotifier, bool?>(
  PushPermissionNotifier.new,
);
