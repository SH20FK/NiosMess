import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/services/background_service.dart';
import 'package:pulse_flutter/core/utils/system_utils.dart';
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
    final bool isAndroid = !kIsWeb && Platform.isAndroid;

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
        if (isAndroid)
          SettingsSection(
            title: context.l10n.settingsPredictiveBackTitle,
            subtitle: context.l10n.settingsPredictiveBackSubtitle,
            children: <Widget>[
              SettingsSwitchTile(
                icon: Icons.swipe_left_rounded,
                title: context.l10n.settingsPredictiveBackToggle,
                subtitle: context.l10n.settingsPredictiveBackDesc,
                iconColor: scheme.primary,
                value: settings.predictiveBackEnabled,
                onChanged: (bool value) {
                  ref.read(uiSettingsProvider.notifier).setPredictiveBackEnabled(value);
                },
              ),
            ],
          ),
        SettingsSection(
          title: context.l10n.settingsBackgroundTitle,
          subtitle: context.l10n.settingsBackgroundSubtitle,
          children: <Widget>[
            if (isAndroid)
              SettingsSwitchTile(
                icon: Icons.battery_saver_rounded,
                title: context.l10n.settingsBackgroundEconomy,
                subtitle: context.l10n.settingsBackgroundEconomyDesc,
                iconColor: scheme.tertiary,
                value: settings.backgroundMode == BackgroundMode.economy,
                onChanged: (bool value) async {
                  final BackgroundMode newMode = value
                      ? BackgroundMode.economy
                      : BackgroundMode.off;
                  ref.read(uiSettingsProvider.notifier).setBackgroundMode(newMode);
                  if (value) {
                    await SystemUtils.requestIgnoreBatteryOptimizations();
                  }
                },
              ),
            if (isAndroid)
              SettingsSwitchTile(
                icon: Icons.shield_rounded,
                title: context.l10n.settingsBackgroundReliable,
                subtitle: context.l10n.settingsBackgroundReliableDesc,
                iconColor: scheme.primary,
                value: settings.backgroundMode == BackgroundMode.reliable,
                onChanged: (bool value) async {
                  final BackgroundMode newMode = value
                      ? BackgroundMode.reliable
                      : BackgroundMode.off;
                  ref.read(uiSettingsProvider.notifier).setBackgroundMode(newMode);
                  if (value) {
                    await BackgroundService.startReliable();
                  } else {
                    await BackgroundService.stop();
                  }
                },
              ),
            if (!isAndroid)
              SettingsInfoTile(
                icon: Icons.info_outline_rounded,
                title: context.l10n.settingsBackgroundNotAvailable,
                subtitle: context.l10n.settingsBackgroundNotAvailableDesc,
                value: '',
                iconColor: scheme.onSurfaceVariant,
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
