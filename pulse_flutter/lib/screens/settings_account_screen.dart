import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/repositories/auth_repository.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

class SettingsAccountScreen extends ConsumerStatefulWidget {
  const SettingsAccountScreen({super.key});

  @override
  ConsumerState<SettingsAccountScreen> createState() =>
      _SettingsAccountScreenState();
}

class _SettingsAccountScreenState extends ConsumerState<SettingsAccountScreen> {
  bool _toggling2fa = false;

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
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(
          currentlyEnabled
              ? context.l10n.settingsDisable2fa
              : context.l10n.settingsEnable2fa,
        ),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: context.l10n.settingsConfirmPassword,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(passwordController.text),
            child: Text(context.l10n.settingsConfirm),
          ),
        ],
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            currentlyEnabled
                ? context.l10n.settings2faDisabled
                : context.l10n.settings2faEnabled,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : '$e')),
      );
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
          subtitle: context.l10n.settingsAccountAccessSubtitle,
          iconColor: Colors.blue,
        ),
        SettingsSection(
          title: context.l10n.settingsAccountAccessTitle,
          children: <Widget>[
            SettingsTile(
              icon: Icons.verified_user_rounded,
              title: context.l10n.settingsVerifyEmail,
              subtitle: context.l10n.settingsVerifyEmailSubtitle,
              iconColor: Colors.blue,
              onTap: () => context.push('/verify-email'),
            ),
            SettingsTile(
              icon: Icons.key_rounded,
              title: context.l10n.settingsResetPassword,
              subtitle: context.l10n.settingsResetPasswordSubtitle,
              iconColor: Colors.blue,
              onTap: () => context.push('/reset-password/request'),
            ),
            SettingsTile(
              icon: Icons.devices_rounded,
              title: context.l10n.settingsActiveSessions,
              subtitle: context.l10n.settingsActiveSessionsSubtitle,
              iconColor: Colors.blueGrey,
              onTap: () => context.push('/settings/sessions'),
            ),
          ],
        ),
        SettingsSection(
          title: context.l10n.settingsProtectionTitle,
          subtitle: context.l10n.settingsProtectionSubtitle,
          children: <Widget>[
            SettingsSwitchTile(
              icon: twoFaEnabled ? Icons.shield_rounded : Icons.shield_outlined,
              title: context.l10n.settingsTwoFactor,
              subtitle: twoFaEnabled
                  ? context.l10n.settingsTwoFactorEnabledShort
                  : context.l10n.settingsTwoFactorDisabledShort,
              iconColor: twoFaEnabled ? Colors.green : scheme.onSurfaceVariant,
              value: twoFaEnabled,
              onChanged: _toggling2fa ? null : (_) => _toggle2fa(),
            ),
          ],
        ),
      ],
    );
  }
}
