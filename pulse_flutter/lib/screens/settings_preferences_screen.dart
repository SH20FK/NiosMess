import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
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
          ],
        ),
        SettingsSection(
          title: context.l10n.appearanceAccentPalette,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: <Widget>[
                  Icon(Icons.text_fields_rounded, color: scheme.onSurfaceVariant, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    context.l10n.appearanceAccentPalette,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SegmentedButton<AppFontScale>(
                segments: <ButtonSegment<AppFontScale>>[
                  ButtonSegment<AppFontScale>(
                    value: AppFontScale.small,
                    label: Text('A'),
                  ),
                  ButtonSegment<AppFontScale>(
                    value: AppFontScale.normal,
                    label: Text('A', style: TextStyle(fontSize: 18)),
                  ),
                  ButtonSegment<AppFontScale>(
                    value: AppFontScale.large,
                    label: Text('A', style: TextStyle(fontSize: 22)),
                  ),
                  ButtonSegment<AppFontScale>(
                    value: AppFontScale.extraLarge,
                    label: Text('A', style: TextStyle(fontSize: 28)),
                  ),
                ],
                selected: {settings.fontScale},
                onSelectionChanged: (Set<AppFontScale> selection) {
                  ref.read(uiSettingsProvider.notifier).setFontScale(selection.first);
                },
              ),
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
                final notifier = ref.read(uiSettingsProvider.notifier);
                notifier.setThemeMode(ThemeMode.system);
                notifier.setSeedColor(const Color(0xFF6750A4));
                notifier.setNotifications(true);
                notifier.setCompactMode(false);
                notifier.setHaptics(true);
                notifier.setHideOnline(false);
                notifier.setSoundEffects(true);
                notifier.setSoundVolume(0.85);
                notifier.setUseSystemDynamic(false);
                notifier.setFontScale(AppFontScale.normal);
                notifier.setNavBarFloating(true);
                notifier.setOptimizeForWeakDevices(false);
                notifier.setPredictiveBackEnabled(true);
                notifier.setBackgroundMode(BackgroundMode.off);
                if (context.mounted) AppToast.showSuccess(context, context.l10n.preferencesResetConfirm);
              },
            ),
          ],
        ),
      ],
    );
  }
}
