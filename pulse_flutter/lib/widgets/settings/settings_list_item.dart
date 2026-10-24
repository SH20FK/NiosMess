import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/widgets/settings/pressable_surface.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

enum SettingsListItemType { nav, toggle, value, action, danger }

/// Unified Material 3 Expressive row for settings lists and grouped cards.
/// Replaces fragmented SettingsTile, SettingsSwitchTile, and SettingsInfoTile
/// with a consistent 40x40 icon slot, 68dp text alignment, and spring touch physics.
class SettingsListItem extends ConsumerWidget {
  const SettingsListItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.type = SettingsListItemType.nav,
    this.onTap,
    this.onLongPress,
    this.boolValue,
    this.onChanged,
    this.trailing,
    this.iconColor,
    this.enabled = true,
    this.isSelected = false,
    this.isSection = false,
    this.leading,
    this.showIcon = true,
    this.pending = false,
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
    bool isSection = false,
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
         isSection: isSection,
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
    VoidCallback? onLongPress,
    Color? iconColor,
    Key? key,
  }) : this(
         icon: icon,
         title: title,
         value: value,
         subtitle: subtitle,
         type: SettingsListItemType.value,
         onTap: onTap,
         onLongPress: onLongPress,
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
  final VoidCallback? onLongPress;
  final bool? boolValue;
  final ValueChanged<bool>? onChanged;
  final Widget? trailing;
  final Color? iconColor;
  final bool enabled;
  final bool isSelected;
  final bool isSection;
  final Widget? leading;
  final bool showIcon;
  final bool pending;

  /// Standard indent for divider matching text start: 16 (padding) + 40 (icon) + 12 (gap) = 68.
  static const double dividerIndent = 68.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final danger = type == SettingsListItemType.danger;
    final interactive = enabled && !pending;
    final foreground = danger
        ? scheme.error
        : isSelected
        ? scheme.onSecondaryContainer
        : interactive
        ? scheme.onSurface
        : scheme.onSurface.withValues(alpha: .38);
    final iconForeground = danger
        ? scheme.error
        : isSelected
        ? scheme.onSecondaryContainer
        : isSection
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;
    final iconWidget = leading is Icon
        ? Icon((leading as Icon).icon, size: 22, color: iconForeground)
        : leading ?? Icon(icon, size: 22, color: iconForeground);
    final toggle = type == SettingsListItemType.toggle;
    void change(bool next) {
      if (!interactive || onChanged == null) return;
      ref
          .read(appSoundProvider)
          .playEvent(next ? SoundEvent.toggleOn : SoundEvent.toggleOff);
      onChanged!(next);
    }

    final VoidCallback? tap = !interactive
        ? null
        : toggle
        ? (onChanged == null ? null : () => change(!(boolValue ?? false)))
        : onTap;
    final Widget? action = pending
        ? const SizedBox(
            width: 52,
            height: 48,
            child: Center(child: AppLoadingIndicator(size: 24)),
          )
        : trailing ??
              switch (type) {
                SettingsListItemType.nav => Icon(
                  Icons.chevron_right_rounded,
                  color: isSelected
                      ? scheme.onSecondaryContainer
                      : scheme.onSurfaceVariant,
                  size: 22,
                ),
                SettingsListItemType.toggle => Switch(
                  value: boolValue ?? false,
                  onChanged: interactive && onChanged != null ? change : null,
                ),
                _ => null,
              };
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (showIcon) ...[
              SizedBox.square(
                dimension: 40,
                child: isSection
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? scheme.secondaryContainer
                              : scheme.primaryContainer,
                          borderRadius: AppRadii.smRadius,
                        ),
                        child: Center(child: iconWidget),
                      )
                    : Center(child: iconWidget),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: textTheme.bodyLarge?.copyWith(
                      color: foreground,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                  if (subtitle?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: textTheme.bodySmall?.copyWith(
                        color: isSelected
                            ? scheme.onSecondaryContainer
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (value?.trim().isNotEmpty == true &&
                      value != subtitle) ...[
                    const SizedBox(height: 3),
                    Text(
                      value!,
                      style: textTheme.bodySmall?.copyWith(
                        color: isSelected
                            ? scheme.onSecondaryContainer
                            : scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (action != null) ...[const SizedBox(width: 12), action],
          ],
        ),
      ),
    );
    final row = Semantics(
      button: toggle ? null : tap != null,
      enabled: interactive,
      selected: isSelected,
      child: PressableSurface(
        onTap: tap,
        onLongPress: interactive ? onLongPress : null,
        enabled: interactive && (tap != null || onLongPress != null),
        playFeedback: !toggle,
        keyboardFocusable: !toggle,
        borderRadius: AppRadii.mdRadius,
        color: isSelected ? scheme.secondaryContainer : Colors.transparent,
        child: content,
      ),
    );
    // Switch and its label form one control. Do not add the title a second
    // time or expose both the row and its switch as separate toggles.
    return toggle ? MergeSemantics(child: row) : row;
  }
}
