import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/widgets/settings/settings_list_item.dart';
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
    super.key,
  });
  final String? title;
  final String? subtitle;
  final List<Widget> children;
  final bool isCard;

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
              padding: const EdgeInsets.fromLTRB(16, 4, 12, 10),
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
                    const SizedBox(height: 4),
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
                return SettingsGroupScope(
                  borderRadius: radius,
                  color: color,
                  child: Material(
                    color: color,
                    borderRadius: radius,
                    clipBehavior: Clip.none,
                    child: items[index],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class SettingsTile extends ConsumerWidget {
  const SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    required this.onTap,
    this.trailing,
    this.foregroundColor,
    this.iconColor,
    this.enabled = true,
    this.isSelected = false,
    this.isSection = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color? foregroundColor;
  final Color? iconColor;
  final bool enabled;
  final bool isSelected;
  final bool isSection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsListItem.nav(
      icon: icon,
      title: title,
      subtitle: subtitle,
      value: value,
      onTap: onTap,
      trailing: trailing,
      iconColor: iconColor ?? foregroundColor,
      enabled: enabled,
      isSelected: isSelected,
      isSection: isSection,
    );
  }
}

class SettingsSwitchTile extends ConsumerWidget {
  const SettingsSwitchTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.iconColor,
    this.enabled = true,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? iconColor;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsListItem.toggle(
      icon: icon,
      title: title,
      subtitle: subtitle,
      value: value,
      onChanged: onChanged,
      iconColor: iconColor,
      enabled: enabled,
    );
  }
}

class SettingsInfoTile extends ConsumerWidget {
  const SettingsInfoTile({
    required this.icon,
    required this.title,
    this.value,
    this.subtitle,
    this.onTap,
    this.onLongPress,
    this.iconColor,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? value;
  final String? subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? iconColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsListItem.value(
      icon: icon,
      title: title,
      value: value,
      subtitle: subtitle,
      onTap: onTap,
      onLongPress: onLongPress,
      iconColor: iconColor,
    );
  }
}
