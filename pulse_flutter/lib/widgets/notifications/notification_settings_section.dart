import 'package:pulse_flutter/features/settings/presentation/settings_row.dart';
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
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import 'package:pulse_flutter/providers/push_permission_provider.dart';
import 'package:pulse_flutter/widgets/motion/m3_reveal.dart';

class NotificationSettingsSection extends ConsumerStatefulWidget {
  const NotificationSettingsSection({super.key});
  @override
  ConsumerState<NotificationSettingsSection> createState() =>
      _NotificationSettingsSectionState();
}

class _NotificationSettingsSectionState
    extends ConsumerState<NotificationSettingsSection> {
  // One flag per row: saving "Calls" must not freeze "Messages".
  final Set<String> _busy = <String>{};

  Future<void> _setEnabled(bool value) async {
    final bool applied = await updateNotificationPreference(ref, value);
    if (!mounted) return;
    await ref.read(pushPermissionProvider.notifier).refresh();
    if (!mounted || !value || applied) return;
    if (ref.read(pushPermissionProvider).value == false) {
      AppToast.showError(context, context.l10n.noticePermissionDenied);
    }
  }

  Future<void> _change(String row, Future<void> Function() operation) async {
    if (_busy.contains(row)) return;
    setState(() => _busy.add(row));
    try {
      await operation();
    } catch (_) {
      if (mounted) AppToast.showError(context, context.l10n.noticeSyncFailed);
    } finally {
      if (mounted) setState(() => _busy.remove(row));
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(notificationPreferencesProvider);
    final enabled = ref.watch(
      uiSettingsProvider.select((s) => s.notifications),
    );
    final l10n = context.l10n;
    final bool? permission = ref.watch(pushPermissionProvider).value;
    final bool denied =
        PushNotificationService.supportsPush && permission == false;
    Widget toggle(String key, IconData icon, String title, {String? hint}) =>
        SettingsAnchor(
          id: 'notifications.$key',
          child: SettingsSwitchTile(
            icon: icon,
            title: title,
            subtitle: hint,
            value: options.value?.toJson()[key] == true,
            enabled: enabled && !_busy.contains(key) && options.hasValue,
            onChanged: (value) => _change(
              key,
              () => ref
                  .read(notificationPreferencesProvider.notifier)
                  .setPreference(key, value),
            ),
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
                permission == true
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
                          : permission == true
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
            permission == true)
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
        SettingsAnchor(
          id: 'push_notifications',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingsSwitchTile(
                icon: Icons.notifications_rounded,
                title: l10n.settingsPushNotifications,
                subtitle: denied
                    ? l10n.noticePermissionHint
                    : l10n.settingsPushNotificationsSubtitle,
                value: enabled,
                enabled: !_busy.contains('enabled'),
                onChanged: (value) =>
                    _change('enabled', () => _setEnabled(value)),
              ),
              // The browser has no page the app could open for this.
              if (!kIsWeb && PushNotificationService.supportsPush)
                M3Reveal(
                  revealed: denied,
                  child: IgnorePointer(
                    ignoring: !denied,
                    child: SettingsListItem(
                      key: const ValueKey('settings-open-system-notifications'),
                      type: SettingsListItemType.action,
                      icon: Icons.open_in_new_rounded,
                      title: l10n.noticeOpenSystemSettings,
                      subtitle: l10n.noticeOpenSystemSettingsHint,
                      onTap: () => unawaited(openAppSettings()),
                    ),
                  ),
                ),
            ],
          ),
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
