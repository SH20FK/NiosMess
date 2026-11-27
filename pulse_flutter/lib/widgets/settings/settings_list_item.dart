import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_motion.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/widgets/motion/m3_spring_switcher.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/widgets/settings/pressable_surface.dart';
import 'package:pulse_flutter/widgets/settings/settings_group_scope.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

enum SettingsListItemType { nav, toggle, value, choice, action, danger }

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
    this.disabledReason,
    this.dense = false,
    this.attention,
    this.attentionColor,
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
    Widget? leading,
    Color? iconColor,
    bool enabled = true,
    bool isSelected = false,
    bool isSection = false,
    bool dense = false,
    String? attention,
    Color? attentionColor,
    Key? key,
  }) : this(
         icon: icon,
         title: title,
         subtitle: subtitle,
         value: value,
         type: SettingsListItemType.nav,
         onTap: onTap,
         trailing: trailing,
         leading: leading,
         iconColor: iconColor,
         enabled: enabled,
         isSelected: isSelected,
         isSection: isSection,
         dense: dense,
         attention: attention,
         attentionColor: attentionColor,
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
    String? disabledReason,
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
         disabledReason: disabledReason,
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

  /// A row of a navigation list that stays on screen beside its content:
  /// lower, with a smaller icon slot and no chevron.
  final bool dense;

  /// Something in this section needs the user. Shows a dot at the trailing
  /// edge; the text is what a screen reader says about it.
  final String? attention;

  /// Colour of the [attention] dot. The error colour when not given.
  final Color? attentionColor;

  /// Shown in place of [subtitle] while the row is not [enabled], so a
  /// greyed-out row says what would bring it back.
  final String? disabledReason;

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
    // The glyph sits in a squircle tile, so the row's meaning reads before
    // the label does. The tile is a rounded superellipse painted by the
    // shape itself: a list never pays for a clip layer per row.
    final double iconSlot = dense ? AppHeights.controlCompact : AppHeights.sm;
    final Color slotFill = danger
        ? scheme.errorContainer.withValues(alpha: .45)
        : isSelected
        ? scheme.secondaryContainer
        : isSection
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest.withValues(alpha: .55);
    final toggle = type == SettingsListItemType.toggle;
    final String? hint = !enabled && disabledReason?.trim().isNotEmpty == true
        ? disabledReason
        : subtitle;
    // A short value sits at the trailing edge, with or without a hint under
    // the title. A long one, or any value at a large text size, would be cut
    // there, so it wraps under the title instead.
    final inlineValue =
        (type == SettingsListItemType.nav ||
            type == SettingsListItemType.value ||
            type == SettingsListItemType.choice) &&
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
                // In a dense list the fill of the open row says where it
                // leads, so the chevron goes.
                SettingsListItemType.nav => dense
                    ? null
                    : _SettingsChevron(
                        active: isSelected,
                        color: isSelected
                            ? scheme.onSecondaryContainer
                            : scheme.onSurfaceVariant,
                      ),
                // The row is the control: one Tab stop, not a row and then
                // its switch.
                SettingsListItemType.toggle => ExcludeFocus(
                  child: Switch(
                    value: boolValue ?? false,
                    onChanged: interactive && onChanged != null ? change : null,
                  ),
                ),
                // Opens a menu in place, so it does not point onwards.
                SettingsListItemType.choice => Icon(
                  Icons.unfold_more_rounded,
                  color: scheme.onSurfaceVariant,
                  size: 22,
                ),
                _ => null,
              };
    if (inlineValue) {
      action = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 88),
            // A new value fades in over the old one instead of snapping.
            child: M3SpringSwitcher(
              type: M3SwitcherType.fade,
              duration: M3Durations.short4,
              child: Text(
                value!,
                key: ValueKey<String>(value!),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
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
    if (attention != null) {
      final Widget dot = SizedBox.square(
        dimension: AppSpacing.sm,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: attentionColor ?? scheme.error,
            shape: BoxShape.circle,
          ),
        ),
      );
      action = action == null
          ? dot
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [dot, const SizedBox(width: AppSpacing.sm), action],
            );
    }
    final content = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: dense ? AppHeights.md : AppHeights.rowCompact,
      ),
      child: Padding(
        // Directional insets: a row in RTL leads with the icon on the right
        // and keeps the same breathing room on both reading edges.
        padding: EdgeInsetsDirectional.only(
          start: dense ? AppSpacing.md : AppSpacing.lg,
          end: dense ? AppSpacing.md : AppSpacing.lg,
          top: dense ? AppSpacing.xs : AppSpacing.md,
          bottom: dense ? AppSpacing.xs : AppSpacing.md,
        ),
        child: Row(
          children: [
            if (showIcon) ...[
              SizedBox.square(
                dimension: iconSlot,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: slotFill,
                    shape: AppRadii.superellipse(
                      AppRadii.of(context).md.clamp(8.0, 14.0),
                    ),
                  ),
                  child: Center(child: iconWidget),
                ),
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
                  if (hint?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 3),
                    Text(
                      hint!,
                      style: textTheme.bodySmall?.copyWith(
                        color: isSelected
                            ? scheme.onSecondaryContainer
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (value?.trim().isNotEmpty == true &&
                      value != hint &&
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
      if (hint?.trim().isNotEmpty == true) hint!,
      if (value?.trim().isNotEmpty == true && value != hint) value!,
      if (attention?.trim().isNotEmpty == true) attention!,
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

/// The chevron of a navigation row.
///
/// It points the way the text runs, nudges towards the edge under the pointer
/// and on the open row, and grows a hair when it is the row the pane shows.
/// Both moves ride the fast spatial spring, and neither happens under reduced
/// motion.
class _SettingsChevron extends StatefulWidget {
  const _SettingsChevron({required this.active, required this.color});

  final bool active;
  final Color color;

  @override
  State<_SettingsChevron> createState() => _SettingsChevronState();
}

class _SettingsChevronState extends State<_SettingsChevron> {
  static const double _size = 22.0;
  static const double _nudge = 2.0;

  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    final bool lively = _hovered || widget.active;
    final double shift = lively ? (rtl ? -_nudge : _nudge) : 0.0;
    return MouseRegion(
      onEnter: (_) {
        if (mounted && !_hovered) setState(() => _hovered = true);
      },
      onExit: (_) {
        if (mounted && _hovered) setState(() => _hovered = false);
      },
      child: AnimatedSlide(
        offset: Offset(shift / _size, 0),
        duration: context.motionDuration(M3Durations.short4),
        curve: M3SpringCurves.spatialFast,
        child: AnimatedScale(
          scale: widget.active ? 1.06 : 1.0,
          duration: context.motionDuration(M3Durations.short4),
          curve: M3SpringCurves.spatialFast,
          child: Icon(
            rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
            size: _size,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}
