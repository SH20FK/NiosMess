import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/widgets/settings/pressable_surface.dart';

enum SettingsListItemType {
  nav,
  toggle,
  value,
  action,
  danger,
}

/// Unified Material 3 Expressive row for settings lists and grouped cards.
/// Replaces fragmented SettingsTile, SettingsSwitchTile, and SettingsInfoTile
/// with a consistent 40x40 icon slot, 66dp text alignment, and spring touch physics.
class SettingsListItem extends ConsumerWidget {
  const SettingsListItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.type = SettingsListItemType.nav,
    this.onTap,
    this.boolValue,
    this.onChanged,
    this.trailing,
    this.iconColor,
    this.enabled = true,
    this.isSelected = false,
    super.key,
  });

  /// Factory for standard navigation tile (chevron trailing).
  const SettingsListItem.nav({
    required IconData icon,
    required String title,
    String? subtitle,
    String? value,
    VoidCallback? onTap,
    Widget? trailing,
    Color? iconColor,
    bool enabled = true,
    bool isSelected = false,
    Key? key,
  }) : this(
          icon: icon,
          title: title,
          subtitle: subtitle,
          value: value,
          type: SettingsListItemType.nav,
          onTap: onTap,
          trailing: trailing,
          iconColor: iconColor,
          enabled: enabled,
          isSelected: isSelected,
          key: key,
        );

  /// Factory for boolean switch tile (M3 Switch).
  const SettingsListItem.toggle({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
    Color? iconColor,
    bool enabled = true,
    Key? key,
  }) : this(
          icon: icon,
          title: title,
          subtitle: subtitle,
          boolValue: value,
          onChanged: onChanged,
          type: SettingsListItemType.toggle,
          iconColor: iconColor,
          enabled: enabled,
          key: key,
        );

  /// Factory for static informational value tile.
  const SettingsListItem.value({
    required IconData icon,
    required String title,
    String? value,
    String? subtitle,
    VoidCallback? onTap,
    Color? iconColor,
    Key? key,
  }) : this(
          icon: icon,
          title: title,
          value: value,
          subtitle: subtitle,
          type: SettingsListItemType.value,
          onTap: onTap,
          iconColor: iconColor,
          key: key,
        );

  /// Factory for destructive action tile (styled in scheme.error).
  const SettingsListItem.danger({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Key? key,
  }) : this(
          icon: icon,
          title: title,
          subtitle: subtitle,
          type: SettingsListItemType.danger,
          onTap: onTap,
          key: key,
        );

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final SettingsListItemType type;
  final VoidCallback? onTap;
  final bool? boolValue;
  final ValueChanged<bool>? onChanged;
  final Widget? trailing;
  final Color? iconColor;
  final bool enabled;
  final bool isSelected;

  /// Standard indent for divider matching text start: 12 (padding) + 40 (icon) + 14 (gap) = 66.
  static const double dividerIndent = 66.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final bool isDanger = type == SettingsListItemType.danger;

    final Color effectiveIconColor = isDanger
        ? scheme.error
        : isSelected
            ? scheme.onSecondaryContainer
            : (iconColor ?? scheme.primary);

    final Color effectiveIconBgColor = isDanger
        ? scheme.error.withValues(alpha: 0.12)
        : isSelected
            ? scheme.primary.withValues(alpha: 0.18)
            : effectiveIconColor.withValues(alpha: 0.12);

    final Color effectiveTextColor = isDanger
        ? scheme.error
        : isSelected
            ? scheme.onSecondaryContainer
            : (enabled ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.38));

    final Widget leadingIcon = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: effectiveIconBgColor,
        borderRadius: AppRadii.smRadius,
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: effectiveIconColor, size: 20),
    );

    final Widget textColumn = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            title,
            style: textTheme.bodyMedium?.copyWith(
              color: effectiveTextColor,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              fontSize: 14,
              height: 1.2,
            ),
          ),
          if (subtitle != null && subtitle!.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: textTheme.bodySmall?.copyWith(
                color: isSelected
                    ? scheme.onSecondaryContainer.withValues(alpha: 0.85)
                    : scheme.onSurfaceVariant,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );

    Widget? trailingWidget;
    switch (type) {
      case SettingsListItemType.nav:
        trailingWidget = trailing ??
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (value != null && value!.isNotEmpty) ...<Widget>[
                  Text(
                    value!,
                    style: textTheme.bodySmall?.copyWith(
                      color: isSelected
                          ? scheme.onSecondaryContainer.withValues(alpha: 0.85)
                          : scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Icon(
                  Icons.chevron_right_rounded,
                  color: isSelected
                      ? scheme.primary
                      : scheme.onSurfaceVariant.withValues(alpha: 0.45),
                  size: 20,
                ),
              ],
            );
        break;
      case SettingsListItemType.toggle:
        final bool isChecked = boolValue ?? false;
        trailingWidget = Switch(
          value: isChecked,
          thumbIcon: WidgetStateProperty.resolveWith<Icon?>((Set<WidgetState> states) {
            if (states.contains(WidgetState.selected)) {
              return Icon(Icons.check_rounded, size: 14, color: scheme.primary);
            }
            return null;
          }),
          onChanged: enabled && onChanged != null ? (bool v) => onChanged!(v) : null,
        );
        break;
      case SettingsListItemType.value:
        if (value != null && value!.isNotEmpty) {
          trailingWidget = Text(
            value!,
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          );
        }
        break;
      case SettingsListItemType.action:
      case SettingsListItemType.danger:
        trailingWidget = trailing;
        break;
    }

    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: <Widget>[
          leadingIcon,
          const SizedBox(width: 14),
          textColumn,
          if (trailingWidget != null) ...<Widget>[
            const SizedBox(width: 10),
            trailingWidget,
          ],
        ],
      ),
    );

    final VoidCallback? effectiveTap = type == SettingsListItemType.toggle
        ? (onChanged != null && enabled ? () => onChanged!(!(boolValue ?? false)) : null)
        : onTap;

    return Semantics(
      label: '$title${subtitle != null ? ', $subtitle' : ''}',
      button: type != SettingsListItemType.value,
      enabled: enabled,
      selected: isSelected,
      child: PressableSurface(
        onTap: effectiveTap,
        enabled: enabled && effectiveTap != null,
        borderRadius: AppRadii.mdRadius,
        color: isSelected
            ? scheme.secondaryContainer.withValues(alpha: 0.80)
            : Colors.transparent,
        child: content,
      ),
    );
  }
}
