import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

class SettingsPrivacyScreen extends ConsumerWidget {
  const SettingsPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UiSettingsState settings = ref.watch(uiSettingsProvider);
    final AuthState auth = ref.watch(authProvider);
    final bool spamBlock = auth.profile?.spamBlock ?? false;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return SettingsScaffold(
      title: context.l10n.settingsPrivacyTitle,
      children: <Widget>[
        SettingsNavBanner(
          icon: Icons.privacy_tip_rounded,
          title: context.l10n.settingsPrivacyTitle,
          subtitle: context.l10n.settingsPrivacyBannerSubtitle,
          iconColor: scheme.primary,
        ),
        SettingsSection(
          title: context.l10n.settingsPrivacyNotificationsTitle,
          subtitle: context.l10n.settingsPrivacyNotificationsManage,
          children: <Widget>[
            SettingsSwitchTile(
              icon: Icons.notifications_active_rounded,
              title: context.l10n.settingsPushNotifications,
              subtitle: context.l10n.settingsPushNotificationsSubtitle,
              iconColor: scheme.tertiary,
              value: settings.notifications,
              onChanged: (bool value) {
                ref.read(uiSettingsProvider.notifier).setNotifications(value);
              },
            ),
          ],
        ),
        SettingsSection(
          title: context.l10n.settingsPrivacyVisibilityTitle,
          subtitle: context.l10n.settingsPrivacyVisibilityDesc,
          children: <Widget>[
            SettingsSwitchTile(
              icon: Icons.visibility_off_rounded,
              title: context.l10n.settingsPrivacyHideOnline,
              subtitle: context.l10n.settingsPrivacyHideOnlineDesc,
              iconColor: scheme.secondary,
              value: settings.hideOnline,
              onChanged: (bool value) {
                ref.read(uiSettingsProvider.notifier).setHideOnline(value);
              },
            ),
          ],
        ),
        if (spamBlock)
          SettingsSection(
            title: context.l10n.settingsSpamBlockTitle,
            subtitle: context.l10n.settingsSpamBlockSubtitle,
            children: <Widget>[
              SettingsInfoTile(
                icon: Icons.block_rounded,
                title: context.l10n.settingsServerLimitsTitle,
                subtitle: context.l10n.settingsServerLimitsSubtitle,
                value: context.l10n.settingsProduction,
                iconColor: scheme.error,
              ),
            ],
          ),
      ],
    );
  }
}
