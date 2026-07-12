import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

class SettingsPreferencesScreen extends ConsumerWidget {
  const SettingsPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UiSettingsState settings = ref.watch(uiSettingsProvider);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return SettingsScaffold(
      title: 'Preferences',
      children: <Widget>[
        SettingsNavBanner(
          icon: Icons.tune_rounded,
          title: 'Preferences',
          subtitle: 'Sound, haptics, and performance tuning',
          iconColor: scheme.tertiary,
        ),
        SettingsSection(
          title: 'Sound & Haptics',
          children: <Widget>[
            SettingsSwitchTile(
              icon: Icons.volume_up_rounded,
              title: 'Sound effects',
              subtitle: 'Play sounds on navigation and interactions',
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
                      'Volume',
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
              title: 'Haptic feedback',
              subtitle: 'Vibrate on taps and interactions',
              value: settings.haptics,
              onChanged: (bool value) {
                ref.read(uiSettingsProvider.notifier).setHaptics(value);
              },
            ),
          ],
        ),
        SettingsSection(
          title: 'Performance',
          children: <Widget>[
            SettingsSwitchTile(
              icon: Icons.density_small_rounded,
              title: 'Compact mode',
              subtitle: 'Reduce spacing for denser layouts',
              value: settings.compactMode,
              onChanged: (bool value) {
                ref.read(uiSettingsProvider.notifier).setCompactMode(value);
              },
            ),
            SettingsSwitchTile(
              icon: Icons.energy_savings_leaf_rounded,
              title: 'Optimize for weak devices',
              subtitle: 'Disable animations and reduce visual effects',
              value: settings.optimizeForWeakDevices,
              onChanged: (bool value) {
                ref.read(uiSettingsProvider.notifier).setOptimizeForWeakDevices(value);
              },
            ),
            SettingsSwitchTile(
              icon: Icons.swipe_rounded,
              title: 'Predictive back gesture',
              subtitle: 'Preview the previous page before going back',
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
