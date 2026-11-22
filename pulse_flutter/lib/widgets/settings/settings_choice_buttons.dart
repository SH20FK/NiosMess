import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

/// Single-choice M3 controls that keep labels intact at large text sizes.
/// The answer to a pick (tick and haptic click) lives here, so every screen
/// that offers a choice sounds and feels the same.
class SettingsChoiceButtons<T> extends ConsumerWidget {
  const SettingsChoiceButtons({
    required this.segments,
    required this.selected,
    required this.onSelectionChanged,
    this.showSelectedIcon = true,
    super.key,
  });
  final List<ButtonSegment<T>> segments;
  final Set<T> selected;
  final ValueChanged<Set<T>>? onSelectionChanged;
  final bool showSelectedIcon;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Material(
    type: MaterialType.transparency,
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final segment in segments)
          ChoiceChip(
            label: segment.label ?? const SizedBox.shrink(),
            avatar: segment.icon,
            tooltip: segment.tooltip,
            selected: selected.contains(segment.value),
            // Chip checkmarks paint in the avatar slot. Preserve semantic icons
            // (language/location/etc.); their selected tonal fill is sufficient.
            showCheckmark: showSelectedIcon && segment.icon == null,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            onSelected: !segment.enabled || onSelectionChanged == null
                ? null
                : (_) {
                    // Tapping the answer that is already chosen changes
                    // nothing, so it stays quiet.
                    if (!selected.contains(segment.value)) {
                      ref.read(appSoundProvider).playUiTick();
                      if (ref.read(uiSettingsProvider).haptics) {
                        HapticService.selection();
                      }
                    }
                    onSelectionChanged!({segment.value});
                  },
          ),
      ],
    ),
  );
}
