import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

class SettingsPreferencesScreen extends ConsumerWidget {
  const SettingsPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UiSettingsState settings = ref.watch(uiSettingsProvider);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return SettingsScaffold(
      title: context.l10n.settingsPreferencesTitle,
      children: <Widget>[
        SettingsNavBanner(
          icon: Icons.tune_rounded,
          title: context.l10n.settingsPreferencesTitle,
          subtitle: context.l10n.settingsPreferencesBannerSubtitle,
          iconColor: scheme.tertiary,
        ),
        SettingsSection(
          title: context.l10n.settingsPreferencesSoundHaptics,
          children: <Widget>[
            SettingsSwitchTile(
              icon: Icons.volume_up_rounded,
              title: context.l10n.appearanceSoundEffects,
              subtitle: context.l10n.settingsSoundEffectsSubtitle,
              value: settings.soundEffects,
              onChanged: (bool value) {
                ref.read(uiSettingsProvider.notifier).setSoundEffects(value);
              },
            ),
            if (settings.soundEffects)
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
                    ),
                  ],
                ),
              ),
            SettingsSwitchTile(
              icon: Icons.vibration_rounded,
              title: context.l10n.settingsHapticFeedback,
              subtitle: context.l10n.settingsHapticFeedbackSubtitle,
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
              value: settings.compactMode,
              onChanged: (bool value) {
                ref.read(uiSettingsProvider.notifier).setCompactMode(value);
              },
            ),
            SettingsSwitchTile(
              icon: Icons.energy_savings_leaf_rounded,
              title: context.l10n.appearanceOptimizeWeakDevices,
              subtitle: context.l10n.appearanceOptimizeWeakDevicesSubtitle,
              value: settings.optimizeForWeakDevices,
              onChanged: (bool value) {
                ref.read(uiSettingsProvider.notifier).setOptimizeForWeakDevices(value);
              },
            ),
            SettingsSwitchTile(
              icon: Icons.swipe_rounded,
              title: context.l10n.settingsPredictiveBackToggle,
              subtitle: context.l10n.settingsPredictiveBackDescription,
              value: settings.predictiveBackEnabled,
              onChanged: (bool value) {
                ref.read(uiSettingsProvider.notifier).setPredictiveBackEnabled(value);
              },
            ),
          ],
        ),
      ],
    );
  }
}
