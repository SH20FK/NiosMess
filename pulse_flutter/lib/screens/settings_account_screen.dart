import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/core/services/biometric_service.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/repositories/auth_repository.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';

class SettingsAccountScreen extends ConsumerStatefulWidget {
  const SettingsAccountScreen({super.key});

  @override
  ConsumerState<SettingsAccountScreen> createState() =>
      _SettingsAccountScreenState();
}

class _SettingsAccountScreenState extends ConsumerState<SettingsAccountScreen> {
  bool _toggling2fa = false;
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
    if (_biometricEnabled) {
      await biometric.setBiometricEnabled(false);
      setState(() => _biometricEnabled = false);
    } else {
      final bool authenticated = await biometric.authenticate(
        reason: context.l10n.biometricAuthReason,
      );
      if (authenticated) {
        await biometric.setBiometricEnabled(true);
        if (mounted) setState(() => _biometricEnabled = true);
      }
    }
  }

  Future<void> _toggle2fa() async {
    if (_toggling2fa) return;
    final ApiProfile? profile = ref.read(authProvider).profile;
    final bool currentlyEnabled = profile?.twoFaEnabled ?? false;

    if (currentlyEnabled) {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext ctx) => SettingsConfirmDialog(
          title: context.l10n.settingsDisable2faTitle,
          body: context.l10n.settingsDisable2faBody,
          confirmLabel: context.l10n.settingsDisable,
          cancelLabel: context.l10n.commonCancel,
          destructive: true,
        ),
      );
      if (confirmed != true) return;
    }

    if (!mounted) return;

    final TextEditingController passwordController = TextEditingController();
    final String? password = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AppDialog(
        title: currentlyEnabled
            ? context.l10n.settingsDisable2fa
            : context.l10n.settingsEnable2fa,
        subtitle: context.l10n.settingsConfirmPassword,
        icon: Icons.password_rounded,
        actions: <AppDialogAction>[
          AppDialogAction(
            label: context.l10n.commonCancel,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          AppDialogAction(
            label: context.l10n.settingsConfirm,
            icon: Icons.check_rounded,
            isPrimary: true,
            onPressed: () => Navigator.of(ctx).pop(passwordController.text),
          ),
        ],
        child: AppTextFieldDialogContent(
          controller: passwordController,
          obscureText: true,
          label: context.l10n.settingsConfirmPassword,
          prefixIcon: Icons.lock_rounded,
        ),
      ),
    );
    passwordController.dispose();
    if (password == null || password.isEmpty) return;

    setState(() => _toggling2fa = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .toggle2fa(enabled: !currentlyEnabled, password: password);
      await ref.read(authProvider.notifier).refreshProfile();
      if (!mounted) return;
      AppToast.showSuccess(
        context,
        currentlyEnabled ? context.l10n.settings2faDisabled : context.l10n.settings2faEnabled,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e is ApiException ? e.message : '$e');
    } finally {
      if (mounted) setState(() => _toggling2fa = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthState auth = ref.watch(authProvider);
    final bool twoFaEnabled = auth.profile?.twoFaEnabled ?? false;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return SettingsScaffold(
      title: context.l10n.settingsAccountTitle,
      children: <Widget>[
        SettingsNavBanner(
          icon: Icons.admin_panel_settings_rounded,
          title: context.l10n.settingsAccountTitle,
          subtitle: context.l10n.settingsAccountBannerSubtitle,
          iconColor: scheme.primary,
        ),
        SettingsSection(
          title: context.l10n.settingsAccountAccessTitle,
          subtitle: context.l10n.settingsAccountAccessDesc,
          children: <Widget>[
            SettingsTile(
              icon: Icons.verified_user_rounded,
              title: context.l10n.settingsVerifyEmail,
              subtitle: context.l10n.settingsVerifyEmailSubtitle,
              iconColor: scheme.primary,
              onTap: () => context.push('/verify-email'),
            ),
            SettingsTile(
              icon: Icons.key_rounded,
              title: context.l10n.settingsResetPassword,
              subtitle: context.l10n.settingsResetPasswordSubtitle,
              iconColor: scheme.tertiary,
              onTap: () => context.push('/reset-password/request'),
            ),
            SettingsTile(
              icon: Icons.devices_rounded,
              title: context.l10n.settingsActiveSessions,
              subtitle: context.l10n.settingsActiveSessionsSubtitle,
              iconColor: scheme.secondary,
              onTap: () => context.push('/settings/sessions'),
            ),
          ],
        ),
        SettingsSection(
          title: context.l10n.settingsProtectionTitle,
          subtitle: context.l10n.settingsProtectionSubtitle,
          children: <Widget>[
            if (_biometricSupported)
            SettingsSwitchTile(
              icon: _biometricEnabled ? Icons.fingerprint : Icons.fingerprint_outlined,
              title: context.l10n.biometricTitle,
              subtitle: _biometricEnabled
                  ? context.l10n.biometricEnabled
                  : context.l10n.biometricDisabled,
              iconColor: _biometricEnabled ? scheme.primary : scheme.onSurfaceVariant,
              value: _biometricEnabled,
              onChanged: (_) => _toggleBiometric(),
            ),
            SettingsSwitchTile(
              icon: twoFaEnabled ? Icons.shield_rounded : Icons.shield_outlined,
              title: context.l10n.settingsTwoFactor,
              subtitle: twoFaEnabled
                  ? context.l10n.settingsTwoFactorEnabledShort
                  : context.l10n.settingsTwoFactorDisabledShort,
              iconColor: twoFaEnabled ? scheme.primary : scheme.onSurfaceVariant,
              value: twoFaEnabled,
              onChanged: _toggling2fa ? null : (_) => _toggle2fa(),
            ),
          ],
        ),
      ],
    );
  }
}
