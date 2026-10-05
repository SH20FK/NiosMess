import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/services/app_url_launcher.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/features/security/application/app_lock_controller.dart';
import 'package:pulse_flutter/features/security/domain/app_lock_policy.dart';
import 'package:pulse_flutter/features/settings/domain/setting_id.dart';
import 'package:pulse_flutter/features/settings/domain/settings_control.dart';
import 'package:pulse_flutter/features/settings/presentation/settings_responsive_shell.dart';
import 'package:pulse_flutter/features/settings/presentation/settings_row.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/settings_navigation_provider.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

class SettingsAccountScreen extends ConsumerWidget {
  const SettingsAccountScreen({
    this.isEmbedded = false,
    super.key,
  });

  final bool isEmbedded;

  Future<void> _openNiosIdSecurity(BuildContext context) async {
    await AppUrlLauncher.openUrl(context, 'https://ni-os.ru/id/account');
  }

  void _showTimeoutPicker(BuildContext context, WidgetRef ref, AppLockTimeout currentTimeout) {
    AppBottomSheets.show<void>(
      context: context,
      builder: (BuildContext sheetContext) {
        final ThemeData theme = Theme.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  child: Text(
                    'Автоблокировка',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ...AppLockTimeout.values.map((AppLockTimeout timeout) {
                  final bool isSelected = timeout == currentTimeout;
                  return ListTile(
                    leading: Icon(
                      isSelected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    title: Text(timeout.labelRu),
                    onTap: () {
                      ref.read(appLockProvider.notifier).setTimeout(timeout);
                      Navigator.of(sheetContext).pop();
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthState auth = ref.watch(authProvider);
    final AppLockState appLock = ref.watch(appLockProvider);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final String displayName = auth.profile?.displayName ??
        auth.session?.displayName ??
        context.l10n.profileGuestName;
    final String username =
        auth.session?.username ?? auth.profile?.username ?? '';
    final String? niosId = auth.session?.niosId;

    return SettingsResponsiveShell(
      title: context.l10n.settingsAccountTitle,
      isEmbedded: isEmbedded,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: <Widget>[
          SettingsSection(
            title: context.l10n.profileSectionAccount,
            children: <Widget>[
              SettingsRow(
                anchor: SettingId.accountDisplayName.value,
                leading: Icon(Icons.person_outline_rounded, color: scheme.primary),
                title: context.l10n.profileDisplayName,
                control: ValueControl(displayName),
              ),
              if (username.isNotEmpty)
                SettingsRow(
                  anchor: SettingId.accountUsername.value,
                  leading: Icon(Icons.alternate_email_rounded, color: scheme.primary),
                  title: context.l10n.profileUsername,
                  control: ValueControl('@$username'),
                ),
              if (niosId != null && niosId.isNotEmpty)
                SettingsRow(
                  anchor: SettingId.accountNiosId.value,
                  leading: Icon(Icons.badge_outlined, color: scheme.primary),
                  title: 'Nios ID',
                  control: ValueControl(niosId),
                ),
            ],
          ),
          SettingsSection(
            title: context.l10n.settingsAccountAccessTitle,
            subtitle: context.l10n.settingsAccountAccessDesc,
            children: <Widget>[
              SettingsRow(
                anchor: SettingId.securitySessionsActive.value,
                leading: Icon(Icons.devices_rounded, color: scheme.primary),
                title: context.l10n.settingsActiveSessions,
                subtitle: context.l10n.settingsActiveSessionsSubtitle,
                control: const NavigationControl(),
                onTap: () {
                  if (isEmbedded) {
                    ref
                        .read(desktopSelectedSettingsSectionProvider.notifier)
                        .setSelectedSection(SettingsSectionId.sessions);
                  } else {
                    context.push('/settings/sessions');
                  }
                },
              ),
            ],
          ),
          SettingsSection(
            title: context.l10n.settingsProtectionTitle,
            subtitle: context.l10n.settingsProtectionSubtitle,
            children: <Widget>[
              if (appLock.isSupported) ...<Widget>[
                SettingsRow(
                  anchor: SettingId.securityAppLock.value,
                  leading: Icon(
                    appLock.isEnabled
                        ? Icons.fingerprint_rounded
                        : Icons.fingerprint_outlined,
                    color: appLock.isEnabled ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                  title: context.l10n.biometricTitle,
                  subtitle: appLock.isEnabled
                      ? context.l10n.biometricEnabled
                      : context.l10n.biometricDisabled,
                  control: ToggleControl(
                    value: appLock.isEnabled,
                    onChanged: (bool next) async {
                      try {
                        final bool success = await ref
                            .read(appLockProvider.notifier)
                            .setEnabled(
                              next,
                              authReason: context.l10n.biometricAuthReason,
                            );
                        if (!success && context.mounted) {
                          AppToast.showError(
                            context,
                            'Не удалось подтвердить биометрию',
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          AppToast.showError(context, e);
                        }
                      }
                    },
                  ),
                ),
                if (appLock.isEnabled)
                  SettingsRow(
                    anchor: SettingId.securityAppLockTimeout.value,
                    leading: Icon(Icons.timer_outlined, color: scheme.primary),
                    title: 'Автоблокировка',
                    subtitle: 'Таймаут блокировки после выхода из приложения',
                    control: NavigationControl(value: appLock.timeout.labelRu),
                    onTap: () => _showTimeoutPicker(
                      context,
                      ref,
                      appLock.timeout,
                    ),
                  ),
              ],
              SettingsRow(
                anchor: SettingId.securityTwoFactor.value,
                leading: Icon(Icons.shield_outlined, color: scheme.primary),
                title: context.l10n.settingsAccountNiosIdSecurity,
                subtitle: context.l10n.settingsAccountNiosIdSecurityDesc,
                control: const NavigationControl(),
                onTap: () => _openNiosIdSecurity(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
