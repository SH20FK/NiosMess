import 'package:pulse_flutter/features/settings/presentation/settings_row.dart';
import 'package:pulse_flutter/widgets/notifications/notification_settings_section.dart';
import 'package:pulse_flutter/core/platform/client_capabilities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

class SettingsPreferencesScreen extends ConsumerWidget {
  const SettingsPreferencesScreen({this.isEmbedded = false, super.key});

  final bool isEmbedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UiSettingsState settings = ref.watch(uiSettingsProvider);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return SettingsShell(
      title: context.l10n.settingsV2Notifications,
      isEmbedded: isEmbedded,
      children: <Widget>[
        const NotificationSettingsSection(),
        SettingsAnchor(
          id: 'sound_volume',
          child: SettingsSection(
            title: context.l10n.settingsPreferencesSoundHaptics,
            children: <Widget>[
              SettingsSwitchTile(
                icon: Icons.volume_up_rounded,
                title: context.l10n.appearanceSoundEffects,
                subtitle: context.l10n.noticeUiSoundsHint,
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
                          ref
                              .read(uiSettingsProvider.notifier)
                              .setSoundVolume(value);
                        },
                        onChangeEnd: (double value) {
                          ref
                              .read(appSoundProvider)
                              .playEvent(
                                SoundEvent.messageReceive,
                                volume: value,
                              );
                        },
                      ),
                    ],
                  ),
                ),
                SettingsTile(
                  icon: Icons.play_circle_outline_rounded,
                  title: context.l10n.noticeSoundTest,
                  subtitle: context.l10n.noticeSoundTestHint,
                  iconColor: scheme.primary,
                  onTap: () async {
                    final SoundService sound = ref.read(appSoundProvider);
                    await sound.playEvent(SoundEvent.uiTap);
                    await Future<void>.delayed(
                      const Duration(milliseconds: 350),
                    );
                    await sound.playEvent(SoundEvent.messageReceive);
                    await Future<void>.delayed(
                      const Duration(milliseconds: 400),
                    );
                    await sound.playEvent(SoundEvent.success);
                    await Future<void>.delayed(
                      const Duration(milliseconds: 400),
                    );
                    await sound.playEvent(SoundEvent.error);
                  },
                ),
              ],
              if (ref.watch(clientCapabilitiesProvider).haptics)
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
        ),
      ],
    );
  }
}
