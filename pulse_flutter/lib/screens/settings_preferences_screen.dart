import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

class SettingsPreferencesScreen extends ConsumerWidget {
  const SettingsPreferencesScreen({
    this.isEmbedded = false,
    super.key,
  });

  final bool isEmbedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UiSettingsState settings = ref.watch(uiSettingsProvider);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return SettingsShell(
      title: context.l10n.settingsPreferencesTitle,
      isEmbedded: isEmbedded,
      children: <Widget>[
        SettingsNavBanner(
          illustrationCategory: SettingsIllustrationCategory.preferences,
          subtitle: context.l10n.settingsPreferencesBannerSubtitle,
          iconColor: scheme.primary,
        ),
        SettingsSection(
          title: context.l10n.settingsPrivacyNotificationsTitle,
          children: <Widget>[
            SettingsSwitchTile(
              icon: Icons.notifications_rounded,
              title: context.l10n.settingsPushNotifications,
              subtitle: context.l10n.settingsPushNotificationsSubtitle,
              iconColor: scheme.primary,
              value: settings.notifications,
              onChanged: (bool value) {
                ref.read(uiSettingsProvider.notifier).setNotifications(value);
              },
            ),
          ],
        ),
        SettingsSection(
          title: context.l10n.settingsPreferencesSoundHaptics,
          children: <Widget>[
            SettingsSwitchTile(
              icon: Icons.volume_up_rounded,
              title: context.l10n.appearanceSoundEffects,
              subtitle: context.l10n.settingsSoundEffectsSubtitle,
              iconColor: scheme.secondary,
              value: settings.soundEffects,
              onChanged: (bool value) {
                ref.read(uiSettingsProvider.notifier).setSoundEffects(value);
                if (value) {
                  ref.read(appSoundProvider).playEvent(SoundEvent.toggleOn);
                }
              },
            ),
            if (settings.soundEffects) ...<Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(68, 0, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.l10n.settingsVolume,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    Slider(
                      value: settings.soundVolume,
                      min: 0,
                      max: 1,
                      divisions: 10,
                      label: '${(settings.soundVolume * 100).round()}%',
                      onChanged: (double value) {
                        ref.read(uiSettingsProvider.notifier).setSoundVolume(value);
                      },
                      onChangeEnd: (double value) {
                        ref.read(appSoundProvider).playEvent(SoundEvent.messageReceive, volume: value);
                      },
                    ),
                  ],
                ),
              ),
              SettingsTile(
                icon: Icons.play_circle_outline_rounded,
                title: 'Проверить звук',
                subtitle: 'Тестовая цепочка: тап, сообщение, успех, ошибка',
                iconColor: scheme.primary,
                onTap: () async {
                  final SoundService sound = ref.read(appSoundProvider);
                  await sound.playEvent(SoundEvent.uiTap);
                  await Future<void>.delayed(const Duration(milliseconds: 350));
                  await sound.playEvent(SoundEvent.messageReceive);
                  await Future<void>.delayed(const Duration(milliseconds: 400));
                  await sound.playEvent(SoundEvent.success);
                  await Future<void>.delayed(const Duration(milliseconds: 400));
                  await sound.playEvent(SoundEvent.error);
                },
              ),
            ],
            SettingsSwitchTile(
              icon: Icons.vibration_rounded,
              title: context.l10n.settingsHapticFeedback,
              subtitle: context.l10n.settingsHapticFeedbackSubtitle,
              iconColor: scheme.tertiary,
              value: settings.haptics,
              onChanged: (bool value) {
                ref.read(uiSettingsProvider.notifier).setHaptics(value);
              },
            ),
          ],
        ),
        SettingsSection(
          title: context.l10n.settingsPreferencesPerformance,
          children: <Widget>[
            SettingsSwitchTile(
              icon: Icons.density_small_rounded,
              title: context.l10n.appearanceCompactMode,
              subtitle: context.l10n.settingsCompactModeSubtitle,
              iconColor: scheme.primary,
              value: settings.compactMode,
              onChanged: (bool value) {
                ref.read(uiSettingsProvider.notifier).setCompactMode(value);
              },
            ),
            SettingsSwitchTile(
              icon: Icons.energy_savings_leaf_rounded,
              title: context.l10n.appearanceOptimizeWeakDevices,
              subtitle: context.l10n.appearanceOptimizeWeakDevicesSubtitle,
              iconColor: scheme.secondary,
              value: settings.optimizeForWeakDevices,
              onChanged: (bool value) {
                ref.read(uiSettingsProvider.notifier).setOptimizeForWeakDevices(value);
              },
            ),
          ],
        ),
        SettingsSection(
          children: <Widget>[
            SettingsTile(
              icon: Icons.restart_alt_rounded,
              title: context.l10n.preferencesResetAll,
              subtitle: context.l10n.preferencesResetAllSubtitle,
              iconColor: scheme.error,
              onTap: () async {
                final bool? confirmed = await showAppConfirmDialog(
                  context: context,
                  title: context.l10n.preferencesResetConfirmTitle,
                  subtitle: context.l10n.preferencesResetConfirmBody,
                  confirmLabel: context.l10n.preferencesResetConfirm,
                  cancelLabel: context.l10n.commonCancel,
                  icon: Icons.restart_alt_rounded,
                  destructive: true,
                );
                if (confirmed != true) return;
                await ref.read(uiSettingsProvider.notifier).resetAll();
                if (context.mounted) {
                  AppToast.showSuccess(context, context.l10n.preferencesResetConfirm);
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}
