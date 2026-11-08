import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/platform/client_capabilities.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/features/settings/presentation/settings_row.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/notifications/notification_settings_section.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:pulse_flutter/widgets/motion/m3_reveal.dart';

class SettingsPreferencesScreen extends ConsumerStatefulWidget {
  const SettingsPreferencesScreen({this.isEmbedded = false, super.key});
  final bool isEmbedded;

  @override
  ConsumerState<SettingsPreferencesScreen> createState() =>
      _SettingsPreferencesScreenState();
}

class _SettingsPreferencesScreenState
    extends ConsumerState<SettingsPreferencesScreen> {
  Timer? _previewTimer;
  bool get _previewing => _previewTimer != null;

  void _stopPreview() {
    _previewTimer?.cancel();
    _previewTimer = null;
  }

  void _previewSounds() {
    if (_previewing) return;
    final sound = ref.read(appSoundProvider);
    // The settings row supplies the first UI tap; do not play it twice.
    const events = [
      SoundEvent.messageReceive,
      SoundEvent.success,
      SoundEvent.error,
    ];
    var index = 0;
    setState(() {
      _previewTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
        if (!mounted || !ref.read(uiSettingsProvider).soundEffects) {
          _stopPreview();
          if (mounted) setState(() {});
          return;
        }
        unawaited(sound.playEvent(events[index++]));
        if (index == events.length) {
          setState(_stopPreview);
        }
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!TickerMode.valuesOf(context).enabled) _stopPreview();
  }

  @override
  void dispose() {
    _stopPreview();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(uiSettingsProvider);
    final scheme = Theme.of(context).colorScheme;
    return SettingsShell(
      title: context.l10n.settingsV2Notifications,
      isEmbedded: widget.isEmbedded,
      children: [
        const NotificationSettingsSection(),
        SettingsAnchor(
          id: 'sound_volume',
          child: SettingsSection(
            title: context.l10n.settingsPreferencesSoundHaptics,
            children: [
              SettingsSwitchTile(
                icon: Icons.volume_up_rounded,
                title: context.l10n.appearanceSoundEffects,
                subtitle: context.l10n.noticeUiSoundsHint,
                value: settings.soundEffects,
                onChanged: (value) {
                  if (!value) setState(_stopPreview);
                  ref.read(uiSettingsProvider.notifier).setSoundEffects(value);
                  if (value) {
                    unawaited(
                      ref.read(appSoundProvider).playEvent(SoundEvent.toggleOn),
                    );
                  }
                },
              ),
              M3Reveal(
                duration: M3Durations.medium2,
                revealed: settings.soundEffects,
                child: IgnorePointer(
                  ignoring: !settings.soundEffects,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '${context.l10n.settingsVolume} · '
                              '${(settings.soundVolume * 100).round()}%',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                            Slider(
                              value: settings.soundVolume,
                              divisions: 10,
                              label: '${(settings.soundVolume * 100).round()}%',
                              onChanged: ref
                                  .read(uiSettingsProvider.notifier)
                                  .setSoundVolume,
                              onChangeEnd: (value) => ref
                                  .read(appSoundProvider)
                                  .playEvent(
                                    SoundEvent.messageReceive,
                                    volume: value,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      SettingsListItem(
                        key: const ValueKey('settings-sound-preview'),
                        type: SettingsListItemType.action,
                        icon: Icons.play_circle_outline_rounded,
                        title: context.l10n.noticeSoundTest,
                        subtitle: context.l10n.noticeSoundTestHint,
                        pending: _previewing,
                        onTap: _previewSounds,
                      ),
                    ],
                  ),
                ),
              ),
              if (ref.watch(clientCapabilitiesProvider).haptics)
                SettingsSwitchTile(
                  icon: Icons.vibration_rounded,
                  title: context.l10n.settingsHapticFeedback,
                  subtitle: context.l10n.settingsHapticFeedbackSubtitle,
                  value: settings.haptics,
                  onChanged: ref.read(uiSettingsProvider.notifier).setHaptics,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
