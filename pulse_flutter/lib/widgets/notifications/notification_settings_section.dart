import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/features/settings/presentation/settings_row.dart';
import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/services/push_notification_service.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/providers/notification_preferences_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/services/settings/notification_preference_action.dart';
import 'package:pulse_flutter/widgets/settings/settings_async_switcher.dart';
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
    final AsyncValue<NotificationPreferences> options = ref.watch(
      notificationPreferencesProvider,
    );
    final bool enabled = ref.watch(
      uiSettingsProvider.select((s) => s.notifications),
    );
    final AppLocalizations l10n = context.l10n;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool? permission = ref.watch(pushPermissionProvider).value;
    final bool denied =
        PushNotificationService.supportsPush && permission == false;

    // The provider either has the value or the section shows the skeleton:
    // a toggle never borrows "off" for "not loaded yet".
    Widget toggle(
      NotificationPreferences prefs,
      String key,
      IconData icon,
      String title, {
      String? hint,
    }) => SettingsAnchor(
      id: 'notifications.$key',
      child: SettingsListItem(
        icon: icon,
        title: title,
        subtitle: hint,
        type: SettingsListItemType.toggle,
        boolValue: prefs.toJson()[key] == true,
        enabled: enabled,
        pending: _busy.contains(key),
        disabledReason: enabled
            ? null
            : l10n.settingsNotificationsOffReason,
        onChanged: (value) => _change(
          key,
          () => ref
              .read(notificationPreferencesProvider.notifier)
              .setPreference(key, value),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SettingsSection(
          title: l10n.noticeTitle,
          accentIcon: Icons.notifications_rounded,
          children: <Widget>[
            Semantics(
              header: true,
              child: SettingsListItem.value(
                icon: permission == true
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                iconColor: scheme.primary,
                title: !PushNotificationService.supportsPush
                    ? l10n.noticeInAppOnly
                    : permission == true
                    ? l10n.noticePermissionGranted
                    : l10n.noticePermissionMissing,
                subtitle: l10n.noticeDeviceHint,
              ),
            ),
            if (enabled &&
                PushNotificationService.supportsPush &&
                permission == true)
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: SettingsListItem.dividerIndent,
                  end: AppSpacing.lg,
                  bottom: AppSpacing.sm,
                ),
                child: ValueListenableBuilder<bool>(
                  valueListenable: PushNotificationService.deviceRegistered,
                  builder: (context, registered, _) => Text(
                    registered
                        ? l10n.noticeDeviceRegistered
                        : l10n.noticeDevicePending,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            SettingsAnchor(
              id: 'push_notifications',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SettingsListItem(
                    icon: Icons.notifications_rounded,
                    title: l10n.settingsPushNotifications,
                    subtitle: denied
                        ? l10n.noticePermissionHint
                        : l10n.settingsPushNotificationsSubtitle,
                    type: SettingsListItemType.toggle,
                    boolValue: enabled,
                    pending: _busy.contains('enabled'),
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
                          key: const ValueKey(
                            'settings-open-system-notifications',
                          ),
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
          ],
        ),
        // The per-category switches load from disk. Until they arrive the
        // skeleton holds their rows, so nothing slides under the finger when
        // the answer lands.
        SettingsAsyncSwitcher<NotificationPreferences>(
          value: options,
          loading: () => const SettingsSection(
            children: <Widget>[SettingsSkeleton(rows: 7)],
          ),
          error: (_, _) => SettingsErrorSection(
            title: l10n.commonError,
            message: l10n.settingsNotificationsLoadFailed,
            onRetry: () => ref.invalidate(notificationPreferencesProvider),
          ),
          data: (NotificationPreferences prefs) => SettingsSection(
            children: <Widget>[
              toggle(
                prefs,
                'private',
                Icons.chat_bubble_outline_rounded,
                l10n.noticeMessagesPrivate,
              ),
              toggle(
                prefs,
                'groups',
                Icons.groups_outlined,
                l10n.noticeMessagesGroups,
              ),
              toggle(
                prefs,
                'channels',
                Icons.campaign_outlined,
                l10n.noticeMessagesChannels,
              ),
              toggle(prefs, 'calls', Icons.call_outlined, l10n.noticeCalls),
              toggle(
                prefs,
                'activity',
                Icons.alternate_email_rounded,
                l10n.noticeActivity,
              ),
              toggle(
                prefs,
                'preview',
                Icons.visibility_outlined,
                l10n.noticePreview,
                hint: l10n.noticePreviewHint,
              ),
              toggle(
                prefs,
                'sound',
                Icons.volume_up_outlined,
                l10n.noticeSound,
                hint: l10n.noticeSoundHint,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
