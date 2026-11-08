import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/platform/client_capabilities.dart';
import 'package:pulse_flutter/core/services/app_url_launcher.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/features/security/application/app_lock_controller.dart';
import 'package:pulse_flutter/features/security/domain/app_lock_policy.dart';
import 'package:pulse_flutter/features/settings/domain/setting_id.dart';
import 'package:pulse_flutter/features/settings/domain/settings_control.dart';
import 'package:pulse_flutter/features/settings/presentation/settings_row.dart';
import 'package:pulse_flutter/providers/settings_navigation_provider.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

class AccountSecuritySection extends ConsumerStatefulWidget {
  const AccountSecuritySection({this.isEmbedded = false, super.key});
  final bool isEmbedded;

  @override
  ConsumerState<AccountSecuritySection> createState() =>
      _AccountSecuritySectionState();
}

class _AccountSecuritySectionState
    extends ConsumerState<AccountSecuritySection> {
  bool _changingLock = false;

  Future<void> _openNiosIdSecurity(BuildContext context) async {
    await AppUrlLauncher.openUrl(context, 'https://ni-os.ru/id/account');
  }

  Future<void> _showTimeoutPicker(AppLockTimeout currentTimeout) async {
    final selected = await AppBottomSheets.show<AppLockTimeout>(
      context: context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: SettingsSection(
          title: sheetContext.l10n.settingsV2LockTimeout,
          children: [
            for (final timeout in AppLockTimeout.values)
              Semantics(
                checked: timeout == currentTimeout,
                inMutuallyExclusiveGroup: true,
                child: SettingsListItem(
                  icon: timeout == currentTimeout
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  title: sheetContext.l10n.localeName.startsWith('ru')
                      ? timeout.labelRu
                      : timeout.labelEn,
                  type: SettingsListItemType.action,
                  isSelected: timeout == currentTimeout,
                  onTap: () => Navigator.of(sheetContext).pop(timeout),
                ),
              ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    try {
      await ref.read(appLockProvider.notifier).setTimeout(selected);
    } catch (_) {
      if (mounted) AppToast.showError(context, context.l10n.commonError);
    }
  }

  Future<void> _changeLock(bool next) async {
    if (_changingLock) return;
    setState(() => _changingLock = true);
    try {
      final success = await ref
          .read(appLockProvider.notifier)
          .setEnabled(next, authReason: context.l10n.biometricAuthReason);
      if (!mounted) return;
      if (!success) {
        AppToast.showError(context, context.l10n.settingsV2BiometricFailure);
      }
    } catch (_) {
      if (mounted) {
        AppToast.showError(context, context.l10n.settingsV2BiometricFailure);
      }
    } finally {
      if (mounted) setState(() => _changingLock = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBrowser = ref.watch(clientCapabilitiesProvider).isWeb;
    final appLock = isBrowser
        ? const AppLockState()
        : ref.watch(appLockProvider);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSection(
          title: context.l10n.settingsAccountAccessTitle,
          children: <Widget>[
            SettingsRow(
              anchor: SettingId.securitySessionsActive.value,
              leading: Icon(Icons.devices_rounded, color: scheme.primary),
              title: context.l10n.settingsActiveSessions,
              subtitle: context.l10n.settingsActiveSessionsSubtitle,
              control: const NavigationControl(),
              onTap: () {
                if (kIsWeb) {
                  context.go('/main/settings?section=sessions');
                } else if (widget.isEmbedded) {
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
          children: <Widget>[
            if (!isBrowser && appLock.isSupported) ...<Widget>[
              SettingsRow(
                anchor: SettingId.securityAppLock.value,
                leading: Icon(
                  appLock.isEnabled
                      ? Icons.fingerprint_rounded
                      : Icons.fingerprint_outlined,
                  color: appLock.isEnabled
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
                title: context.l10n.biometricTitle,
                subtitle: appLock.isEnabled
                    ? context.l10n.biometricEnabled
                    : context.l10n.biometricDisabled,
                control: ToggleControl(
                  value: appLock.isEnabled,
                  pending: _changingLock,
                  onChanged:
                      _changingLock ||
                          appLock.isInitializing ||
                          appLock.hasInitializationError
                      ? null
                      : _changeLock,
                ),
              ),
              if (appLock.isEnabled)
                SettingsRow(
                  anchor: SettingId.securityAppLockTimeout.value,
                  leading: Icon(Icons.timer_outlined, color: scheme.primary),
                  title: context.l10n.settingsV2LockTimeout,
                  subtitle: context.l10n.settingsV2LockTimeoutHint,
                  control: NavigationControl(
                    value: context.l10n.localeName.startsWith('ru')
                        ? appLock.timeout.labelRu
                        : appLock.timeout.labelEn,
                  ),
                  onTap: () => _showTimeoutPicker(appLock.timeout),
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
    );
  }
}
