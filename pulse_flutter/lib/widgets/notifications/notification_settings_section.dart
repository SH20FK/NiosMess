import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/services/push_notification_service.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/providers/notification_preferences_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/services/settings/notification_preference_action.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

class NotificationSettingsSection extends ConsumerStatefulWidget {
  const NotificationSettingsSection({super.key});
  @override
  ConsumerState<NotificationSettingsSection> createState() =>
      _NotificationSettingsSectionState();
}

class _NotificationSettingsSectionState
    extends ConsumerState<NotificationSettingsSection> {
  late final AppLifecycleListener _lifecycle;
  bool? _permission;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    _refresh();
  }

  Future<void> _refresh() async {
    final granted = await PushNotificationService.isPermissionGranted();
    if (mounted) setState(() => _permission = granted);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _change(Future<void> Function() operation) async {
    setState(() => _busy = true);
    try {
      await operation();
    } catch (_) {
      if (mounted) AppToast.showError(context, context.l10n.noticeSyncFailed);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        unawaited(_refresh());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(notificationPreferencesProvider);
    final enabled = ref.watch(
      uiSettingsProvider.select((s) => s.notifications),
    );
    final l10n = context.l10n;
    Widget toggle(String key, IconData icon, String title, {String? hint}) =>
        SettingsSwitchTile(
          icon: icon,
          title: title,
          subtitle: hint,
          value: options.value?.toJson()[key] == true,
          enabled: enabled && !_busy && options.hasValue,
          onChanged: (value) => _change(
            () => ref
                .read(notificationPreferencesProvider.notifier)
                .setPreference(key, value),
          ),
        );
    return SettingsSection(
      title: l10n.noticeTitle,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _permission == true
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      !PushNotificationService.supportsPush
                          ? l10n.noticeInAppOnly
                          : _permission == true
                          ? l10n.noticePermissionGranted
                          : l10n.noticePermissionMissing,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.noticeDeviceHint,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (enabled &&
            PushNotificationService.supportsPush &&
            _permission == true)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: ValueListenableBuilder<bool>(
              valueListenable: PushNotificationService.deviceRegistered,
              builder: (context, registered, _) => Text(
                registered
                    ? l10n.noticeDeviceRegistered
                    : l10n.noticeDevicePending,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        SettingsSwitchTile(
          icon: Icons.notifications_rounded,
          title: l10n.settingsPushNotifications,
          subtitle: PushNotificationService.supportsPush && _permission == false
              ? l10n.noticePermissionHint
              : l10n.settingsPushNotificationsSubtitle,
          value: enabled,
          enabled: !_busy,
          onChanged: (value) => _change(() async {
            await updateNotificationPreference(ref, value);
          }),
        ),
        toggle(
          'messages',
          Icons.chat_bubble_outline_rounded,
          l10n.noticeMessages,
        ),
        toggle('calls', Icons.call_outlined, l10n.noticeCalls),
        toggle('activity', Icons.alternate_email_rounded, l10n.noticeActivity),
        toggle(
          'preview',
          Icons.visibility_outlined,
          l10n.noticePreview,
          hint: l10n.noticePreviewHint,
        ),
        toggle(
          'sound',
          Icons.volume_up_outlined,
          l10n.noticeSound,
          hint: l10n.noticeSoundHint,
        ),
      ],
    );
  }
}
