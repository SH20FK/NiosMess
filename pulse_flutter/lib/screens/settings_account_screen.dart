import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/services/biometric_service.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/providers/settings_navigation_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsAccountScreen extends ConsumerStatefulWidget {
  const SettingsAccountScreen({
    this.isEmbedded = false,
    super.key,
  });

  final bool isEmbedded;

  @override
  ConsumerState<SettingsAccountScreen> createState() =>
      _SettingsAccountScreenState();
}

class _SettingsAccountScreenState extends ConsumerState<SettingsAccountScreen> {
  bool _biometricEnabled = false;
  bool _biometricSupported = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    final BiometricService biometric = ref.read(biometricServiceProvider);
    final bool enabled = await biometric.isBiometricEnabled;
    final bool supported = await biometric.canCheckBiometrics;
    if (mounted) {
      setState(() {
        _biometricEnabled = enabled;
        _biometricSupported = supported;
      });
    }
  }

  Future<void> _toggleBiometric() async {
    final BiometricService biometric = ref.read(biometricServiceProvider);
    try {
      if (_biometricEnabled) {
        await biometric.setBiometricEnabled(false);
        if (mounted) setState(() => _biometricEnabled = false);
      } else {
        final bool authenticated = await biometric.authenticate(
          reason: context.l10n.biometricAuthReason,
        );
        if (authenticated) {
          await biometric.setBiometricEnabled(true);
          if (mounted) setState(() => _biometricEnabled = true);
        }
      }
    } catch (e) {
      if (mounted) AppToast.showError(context, e);
    }
  }

  Future<void> _openNiosIdSecurity() async {
    final Uri uri = Uri.parse('https://ni-os.ru/id/account');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) AppToast.showError(context, 'Не удалось открыть страницу Nios ID');
      }
    } catch (e) {
      if (mounted) AppToast.showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthState auth = ref.watch(authProvider);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String displayName = auth.profile?.displayName ??
        auth.session?.displayName ??
        context.l10n.profileGuestName;
    final String username =
        auth.session?.username ?? auth.profile?.username ?? '';
    final String? niosId = auth.session?.niosId;

    return SettingsScaffold(
      title: context.l10n.settingsAccountTitle,
      isEmbedded: widget.isEmbedded,
      children: <Widget>[
        SettingsNavBanner(
          illustrationCategory: SettingsIllustrationCategory.account,
          title: context.l10n.settingsAccountTitle,
          subtitle: context.l10n.settingsAccountBannerSubtitle,
          iconColor: scheme.primary,
        ),
        SettingsSection(
          title: context.l10n.profileSectionAccount,
          children: <Widget>[
            SettingsInfoTile(
              icon: Icons.person_outline_rounded,
              title: context.l10n.profileDisplayName,
              value: displayName,
            ),
            if (username.isNotEmpty)
              SettingsInfoTile(
                icon: Icons.alternate_email_rounded,
                title: context.l10n.profileUsername,
                value: '@$username',
              ),
            if (niosId != null && niosId.isNotEmpty)
              SettingsInfoTile(
                icon: Icons.badge_outlined,
                title: 'Nios ID',
                value: niosId,
              ),
          ],
        ),
        SettingsSection(
          title: context.l10n.settingsAccountAccessTitle,
          subtitle: context.l10n.settingsAccountAccessDesc,
          children: <Widget>[
            SettingsTile(
              icon: Icons.devices_rounded,
              title: context.l10n.settingsActiveSessions,
              subtitle: context.l10n.settingsActiveSessionsSubtitle,
              iconColor: scheme.primary,
              onTap: () {
                if (widget.isEmbedded) {
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
            if (_biometricSupported)
              SettingsSwitchTile(
                icon: _biometricEnabled
                    ? Icons.fingerprint
                    : Icons.fingerprint_outlined,
                title: context.l10n.biometricTitle,
                subtitle: _biometricEnabled
                    ? context.l10n.biometricEnabled
                    : context.l10n.biometricDisabled,
                iconColor:
                    _biometricEnabled ? scheme.primary : scheme.onSurfaceVariant,
                value: _biometricEnabled,
                onChanged: (_) => _toggleBiometric(),
              ),
            SettingsTile(
              icon: Icons.shield_outlined,
              title: 'Безопасность и 2FA в Nios ID',
              subtitle:
                  'Двухфакторная аутентификация и управление паролем на портале ni-os.ru',
              iconColor: scheme.primary,
              trailing: Icon(
                Icons.open_in_new_rounded,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
              onTap: _openNiosIdSecurity,
            ),
          ],
        ),
      ],
    );
  }
}
