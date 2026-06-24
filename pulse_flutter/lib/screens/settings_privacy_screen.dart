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

    return SettingsScaffold(
      title: context.l10n.settingsPrivacyTitle,
      children: <Widget>[
        SettingsNavBanner(
          icon: Icons.privacy_tip_rounded,
          title: context.l10n.settingsPrivacyTitle,
          subtitle: context.l10n.settingsPrivacyNotificationsSubtitle,
          iconColor: Colors.orange,
        ),
        SettingsSection(
          title: context.l10n.settingsPrivacyNotificationsTitle,
          children: <Widget>[
            SettingsSwitchTile(
              icon: Icons.notifications_active_rounded,
              title: context.l10n.settingsPushNotifications,
              subtitle: context.l10n.settingsPushNotificationsSubtitle,
              iconColor: Colors.orange,
              value: settings.notifications,
              onChanged: (bool value) {
                ref.read(uiSettingsProvider.notifier).setNotifications(value);
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
                iconColor: Colors.red,
              ),
            ],
          ),
      ],
    );
  }
}
