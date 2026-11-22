import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/widgets/motion/m3_staggered_list.dart';
import 'package:pulse_flutter/widgets/settings/settings_group_scope.dart';

export 'package:pulse_flutter/widgets/vector_illustrations.dart';
export 'package:pulse_flutter/widgets/settings/pressable_surface.dart';
export 'package:pulse_flutter/widgets/settings/settings_list_item.dart';
export 'package:pulse_flutter/widgets/settings/settings_shell.dart';
export 'package:pulse_flutter/widgets/settings/settings_choice_buttons.dart';

/// Connected tonal surfaces: generous outer corners, quiet inner corners.
/// Rows retain their own hit area and focus outline without a clipped card layer.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    required this.children,
    this.title,
    this.subtitle,
    this.isCard = true,
    this.stagger = false,
    super.key,
  });
  final String? title;
  final String? subtitle;
  final List<Widget> children;
  final bool isCard;

  /// The first rows rise into place one after another when the group first
  /// appears. For a list that is the screen itself, such as the hub.
  final bool stagger;

  /// Outer corner of a group. Follows the corner radius setting across its
  /// whole 8-28 range; the default 20 gives 24.
  static double outerRadius(BuildContext context) =>
      (AppRadii.of(context).lg + 4).clamp(12.0, 32.0);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final items = children.where((child) => child is! Divider).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    final outer = outerRadius(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title?.isNotEmpty == true || subtitle?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xs,
                AppSpacing.md,
                10,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title?.isNotEmpty == true)
                    Semantics(
                      header: true,
                      child: Text(
                        title!,
                        style: text.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (subtitle?.isNotEmpty == true) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle!,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          for (var index = 0; index < items.length; index++) ...[
            if (index != 0) const SizedBox(height: 2),
            Builder(
              builder: (context) {
                final radius = BorderRadius.vertical(
                  top: Radius.circular(index == 0 ? outer : 4),
                  bottom: Radius.circular(
                    index == items.length - 1 ? outer : 4,
                  ),
                );
                final color = isCard
                    ? scheme.surfaceContainerLow
                    : scheme.surface;
                final Widget row = SettingsGroupScope(
                  borderRadius: radius,
                  color: color,
                  child: Material(
                    color: color,
                    borderRadius: radius,
                    clipBehavior: Clip.none,
                    child: items[index],
                  ),
                );
                return stagger
                    ? M3StaggeredItem(index: index, child: row)
                    : row;
              },
            ),
          ],
        ],
      ),
    );
  }
}

// Rows live in settings/settings_list_item.dart (exported above).
