import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/widgets/settings/pressable_surface.dart';
import 'package:pulse_flutter/widgets/settings/settings_group_scope.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

enum SettingsListItemType { nav, toggle, value, action, danger }

/// The one Material 3 Expressive row for settings lists and grouped cards:
/// a 40x40 icon slot, 68dp text alignment, and spring touch physics.
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

  /// Indent of a divider that starts where the text does: row padding, icon
  /// slot and the gap after it (68 dp).
  static const double dividerIndent =
      AppSpacing.lg + AppHeights.sm + AppSpacing.md;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final group = SettingsGroupScope.maybeOf(context);
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
        : iconColor ??
              (isSection ? scheme.onPrimaryContainer : scheme.onSurfaceVariant);
    final iconWidget = leading is Icon
        ? Icon((leading as Icon).icon, size: 22, color: iconForeground)
        : leading ?? Icon(icon, size: 22, color: iconForeground);
    final toggle = type == SettingsListItemType.toggle;
    // A short value sits at the trailing edge, with or without a hint under
    // the title. A long one, or any value at a large text size, would be cut
    // there, so it wraps under the title instead.
    final inlineValue =
        (type == SettingsListItemType.nav ||
            type == SettingsListItemType.value) &&
        value?.trim().isNotEmpty == true &&
        value!.length <= 18 &&
        MediaQuery.textScalerOf(context).scale(14) <= 18;
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
    Widget? action = pending
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
                // The row is the control: one Tab stop, not a row and then
                // its switch.
                SettingsListItemType.toggle => ExcludeFocus(
                  child: Switch(
                    value: boolValue ?? false,
                    onChanged: interactive && onChanged != null ? change : null,
                  ),
                ),
                _ => null,
              };
    if (inlineValue) {
      action = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 88),
            child: Text(
              value!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: AppSpacing.xs),
            action,
          ],
        ],
      );
    }
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppHeights.rowCompact),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            if (showIcon) ...[
              SizedBox.square(
                dimension: AppHeights.sm,
                child: isSection
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? scheme.secondaryContainer
                              : scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(child: iconWidget),
                      )
                    : Center(child: iconWidget),
              ),
              const SizedBox(width: AppSpacing.md),
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
                      value != subtitle &&
                      !inlineValue) ...[
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
            if (action != null) ...[
              const SizedBox(width: AppSpacing.md),
              action,
            ],
          ],
        ),
      ),
    );
    // One node per row: title, hint and value are read once, and the switch
    // inside is not offered as a second control. The focus state and the tap
    // come from the surface above the label and land on the same node. A
    // custom trailing widget keeps a node of its own.
    final bool oneNode = toggle || trailing == null;
    final String semanticsLabel = <String>[
      title,
      if (subtitle?.trim().isNotEmpty == true) subtitle!,
      if (value?.trim().isNotEmpty == true && value != subtitle) value!,
      // The spinner in the trailing slot is hidden with the other children.
      if (pending) context.l10n.commonLoading,
    ].join(', ');
    return Semantics(
      container: true,
      button: toggle ? null : tap != null,
      toggled: toggle ? (boolValue ?? false) : null,
      enabled: interactive,
      selected: isSelected,
      child: PressableSurface(
        onTap: tap,
        onLongPress: interactive ? onLongPress : null,
        enabled: interactive && (tap != null || onLongPress != null),
        playFeedback: !toggle,
        borderRadius: group?.borderRadius ?? AppRadii.mdRadius,
        color: isSelected ? scheme.secondaryContainer : group?.color,
        child: oneNode
            ? Semantics(
                label: semanticsLabel,
                excludeSemantics: true,
                child: content,
              )
            : content,
      ),
    );
  }
}
