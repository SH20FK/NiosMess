import 'package:material_ui/material_ui.dart';
import 'package:pulse_flutter/core/modal/app_modal.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/services/audio/voice_filter_preset.dart';

/// Shows a clean Material 3 sheet to pick a [VoiceFilterPreset].
Future<VoiceFilterPreset?> showVoiceEffectPickerSheet(
  BuildContext context, {
  required VoiceFilterPreset selected,
  String title = 'Фильтр голоса',
}) {
  return AppModal.showSheet<VoiceFilterPreset>(
    context: context,
    isDismissible: true,
    enableDrag: true,
    showDragHandle: true,
    builder: (ctx) => _VoiceEffectPickerSheet(
      selected: selected,
      title: title,
    ),
  );
}

class _VoiceEffectPickerSheet extends StatelessWidget {
  const _VoiceEffectPickerSheet({
    required this.selected,
    required this.title,
  });

  final VoiceFilterPreset selected;
  final String title;

  IconData _iconFor(VoiceFilterPreset preset) => switch (preset) {
    VoiceFilterPreset.none => Icons.record_voice_over_rounded,
    VoiceFilterPreset.robot => Icons.smart_toy_rounded,
    VoiceFilterPreset.radio => Icons.settings_input_antenna_rounded,
    VoiceFilterPreset.deep => Icons.graphic_eq_rounded,
    VoiceFilterPreset.helium => Icons.air_rounded,
    VoiceFilterPreset.echo => Icons.surround_sound_rounded,
    VoiceFilterPreset.anonymous => Icons.theater_comedy_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: VoiceFilterPreset.values.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final preset = VoiceFilterPreset.values[index];
                final isSelected = preset == selected;
                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  tileColor: isSelected
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHigh,
                  leading: Icon(
                    _iconFor(preset),
                    color: isSelected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                  title: Text(
                    preset.title,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? scheme.onPrimaryContainer
                          : scheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    preset.subtitle,
                    style: textTheme.bodySmall?.copyWith(
                      color: isSelected
                          ? scheme.onPrimaryContainer.withValues(alpha: 0.85)
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(
                          Icons.check_rounded,
                          color: scheme.onPrimaryContainer,
                        )
                      : null,
                  onTap: () {
                    HapticService.tap();
                    Navigator.of(context).pop(preset);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
