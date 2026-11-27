import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/platform/client_capabilities.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/features/settings/presentation/settings_row.dart';
import 'package:pulse_flutter/providers/notification_preferences_provider.dart';
import 'package:pulse_flutter/providers/push_permission_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/notifications/notification_settings_section.dart';
import 'package:pulse_flutter/widgets/settings/background_delivery_section.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:pulse_flutter/widgets/motion/m3_reveal.dart';

class SettingsNotificationsScreen extends ConsumerStatefulWidget {
  const SettingsNotificationsScreen({this.isEmbedded = false, super.key});
  final bool isEmbedded;

  @override
  ConsumerState<SettingsNotificationsScreen> createState() =>
      _SettingsNotificationsScreenState();
}

class _SettingsNotificationsScreenState
    extends ConsumerState<SettingsNotificationsScreen> {
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
    final settings = ref.watch(
      uiSettingsProvider.select(
        (UiSettingsState s) => (
          soundEffects: s.soundEffects,
          soundVolume: s.soundVolume,
          haptics: s.haptics,
        ),
      ),
    );
    return SettingsShell(
      title: context.l10n.settingsV2Notifications,
      isEmbedded: widget.isEmbedded,
      onRefresh: () async {
        ref.invalidate(notificationPreferencesProvider);
        await Future.wait<void>(<Future<void>>[
          ref.read(notificationPreferencesProvider.future),
          ref.read(pushPermissionProvider.notifier).refresh(),
        ]);
      },
      children: [
        const NotificationSettingsSection(),
        if (!kIsWeb) const BackgroundDeliverySection(),
        SettingsAnchor(
          id: 'sound_volume',
          child: SettingsSection(
            title: context.l10n.settingsPreferencesSoundHaptics,
            accentIcon: Icons.volume_up_rounded,
            children: [
              SettingsListItem.toggle(
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
                      _VolumeSliderTile(
                        value: settings.soundVolume,
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
                SettingsListItem.toggle(
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

/// The volume row of the sound section, after `_SliderSettingTile` from the
/// appearance page: the live value sits at the trailing edge of the row, the
/// slider applies while the thumb moves, and releasing it plays the preview
/// at the level that was just set.
class _VolumeSliderTile extends StatefulWidget {
  const _VolumeSliderTile({
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  State<_VolumeSliderTile> createState() => _VolumeSliderTileState();
}

class _VolumeSliderTileState extends State<_VolumeSliderTile> {
  bool _isDragging = false;
  late double _localValue;

  @override
  void initState() {
    super.initState();
    _localValue = widget.value;
  }

  @override
  void didUpdateWidget(covariant _VolumeSliderTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging) _localValue = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    final String percent = '${(_localValue * 100).round()}%';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsListItem.value(
          icon: Icons.tune_rounded,
          title: context.l10n.settingsVolume,
          value: percent,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(trackHeight: 16),
            child: Slider(
              value: _localValue.clamp(0.0, 1.0),
              divisions: 10,
              label: percent,
              onChangeStart: (_) => setState(() => _isDragging = true),
              onChangeEnd: (value) {
                setState(() => _isDragging = false);
                widget.onChangeEnd(value);
              },
              onChanged: (value) {
                setState(() => _localValue = value);
                // Applied while dragging: the same write the slider always
                // did, so the next sound plays at the level under the thumb.
                widget.onChanged(value);
              },
            ),
          ),
        ),
      ],
    );
  }
}
