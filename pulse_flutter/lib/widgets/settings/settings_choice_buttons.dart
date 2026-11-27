import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/motion/m3_selection_motion.dart';

/// Single-choice M3 controls that keep labels intact at large text sizes.
///
/// The segments are pills of one button group: the group's track tone is
/// [ColorScheme.surfaceContainerHigh], the answer in force is a filled
/// [ColorScheme.secondaryContainer] pill, and the selection lands with the
/// fast spatial spring ([M3SelectionMotion]) instead of a hard swap. The
/// answer to a pick (tick, sound and haptic click) lives here, so every screen
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
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Material(
      type: MaterialType.transparency,
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final segment in segments)
            _ChoicePill(
              segment: segment,
              scheme: scheme,
              text: text,
              isSelected: selected.contains(segment.value),
              showSelectedIcon: showSelectedIcon,
              enabled: segment.enabled && onSelectionChanged != null,
              onPick: () {
                // Tapping the answer that is already chosen changes nothing,
                // so it stays quiet.
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
}

/// One pill of the group. Kept a Material [ChoiceChip] on purpose: the chip
/// already owns the single-choice semantics, the large-text label metrics and
/// the tap target, and every screen that offers a choice is built on it. What
/// changes here is the shape (a stadium pill), the tonal pair of the group,
/// and the spring that carries the selection.
class _ChoicePill<T> extends StatelessWidget {
  const _ChoicePill({
    required this.segment,
    required this.scheme,
    required this.text,
    required this.isSelected,
    required this.showSelectedIcon,
    required this.enabled,
    required this.onPick,
  });

  final ButtonSegment<T> segment;
  final ColorScheme scheme;
  final TextTheme text;
  final bool isSelected;
  final bool showSelectedIcon;
  final bool enabled;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final Color ink = isSelected
        ? scheme.onSecondaryContainer
        : enabled
        ? scheme.onSurfaceVariant
        : scheme.onSurface.withValues(alpha: .38);
    return M3SelectionMotion(
      selected: isSelected,
      child: ChoiceChip(
        label: segment.label ?? const SizedBox.shrink(),
        avatar: segment.icon,
        tooltip: segment.tooltip,
        selected: isSelected,
        // Chip checkmarks paint in the avatar slot. Preserve semantic icons
        // (language/location/etc.); their selected tonal fill is sufficient.
        showCheckmark: showSelectedIcon && segment.icon == null,
        shape: const StadiumBorder(),
        side: BorderSide(
          color: isSelected
              ? scheme.secondaryContainer
              : scheme.outlineVariant.withValues(alpha: .55),
        ),
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.secondaryContainer,
        labelStyle: text.labelLarge?.copyWith(
          color: ink,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: ink, size: 18),
        checkmarkColor: scheme.onSecondaryContainer,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        materialTapTargetSize: MaterialTapTargetSize.padded,
        onSelected: !enabled ? null : (_) => onPick(),
      ),
    );
  }
}
