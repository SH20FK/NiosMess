import 'package:flutter/material.dart';

/// Single-choice M3 controls that keep labels intact at large text sizes.
class SettingsChoiceButtons<T> extends StatelessWidget {
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
  Widget build(BuildContext context) => Material(
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
            showCheckmark: showSelectedIcon,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            onSelected: !segment.enabled || onSelectionChanged == null
                ? null
                : (_) => onSelectionChanged!({segment.value}),
          ),
      ],
    ),
  );
}
