import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/widgets/motion/m3_entrance.dart';
import 'package:pulse_flutter/widgets/motion/m3_staggered_list.dart';
import 'package:pulse_flutter/widgets/settings/settings_group_scope.dart';

export 'package:pulse_flutter/widgets/vector_illustrations.dart';
export 'package:pulse_flutter/widgets/settings/pressable_surface.dart';
export 'package:pulse_flutter/widgets/settings/settings_choice_buttons.dart';
export 'package:pulse_flutter/widgets/settings/settings_error_section.dart';
export 'package:pulse_flutter/widgets/settings/settings_hero_card.dart';
export 'package:pulse_flutter/widgets/settings/settings_list_item.dart';
export 'package:pulse_flutter/widgets/settings/settings_pane_scrollbar.dart';
export 'package:pulse_flutter/widgets/settings/settings_pane_scope.dart';
export 'package:pulse_flutter/widgets/settings/settings_shell.dart';
export 'package:pulse_flutter/widgets/settings/settings_skeleton.dart';

/// Connected tonal surfaces: generous outer corners, quiet inner corners.
/// Rows retain their own hit area and focus outline without a clipped card layer.
///
/// Every group is one card of [ColorScheme.surfaceContainerLow] on the tonal
/// page below it. The outer corner follows the user's `uiCornerRadius` through
/// [AppRadii], the seams between connected rows use the smallest token, so the
/// group reads as a single shape at any radius. An optional [accentIcon] /
/// [accentLabel] turns the heading into an expressive mark: a squircle badge
/// from `flutter_m3shapes` next to the label.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    required this.children,
    this.title,
    this.subtitle,
    this.isCard = true,
    this.stagger = false,
    this.selectedIndex,
    this.animateEntrance = true,
    this.accentIcon,
    this.accentColor,
    this.accentForeground,
    this.accentLabel,
    this.semanticLabel,
    super.key,
  });
  final String? title;
  final String? subtitle;
  final List<Widget> children;
  final bool isCard;

  /// The first rows rise into place one after another when the group first
  /// appears. For a list that is the screen itself, such as the hub.
  final bool stagger;

  /// The whole group fades and lifts in when the screen is built. Skipped
  /// under reduced motion and when [stagger] drives the rows instead.
  final bool animateEntrance;

  /// The row at this position leaves the connected shape and stands on its
  /// own: full corners on every side and no backdrop behind it. For the
  /// section that is open in the pane next to the list.
  final int? selectedIndex;

  /// Glyph of the expressive badge in the heading. Without a [title] the
  /// badge is not shown: it belongs to the label.
  final IconData? accentIcon;

  /// Fill of the accent badge; [ColorScheme.primaryContainer] when not given.
  final Color? accentColor;

  /// Ink of the accent badge and pill; the `on` role of the fill the theme
  /// pairs with [accentColor], or [ColorScheme.onPrimaryContainer] by default.
  final Color? accentForeground;

  /// Short uppercase text mark next to the heading, such as `NEW`.
  final String? accentLabel;

  /// Overrides what a screen reader announces for the whole group.
  final String? semanticLabel;

  /// Outer corner of a group. Follows the corner radius setting across its
  /// whole 8-28 range; the default 20 gives 24.
  static double outerRadius(BuildContext context) =>
      (AppRadii.of(context).lg + 4).clamp(12.0, 32.0);

  /// Seam between two rows of the same group. The smallest radius token, so
  /// the connected edges soften with the rest of the interface instead of
  /// cutting a 4 dp notch into a 32 dp corner.
  static double innerRadius(BuildContext context) =>
      AppRadii.of(context).xs.clamp(AppRadii.xs, AppSpacing.sm);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final items = children.where((child) => child is! Divider).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    final outer = outerRadius(context);
    final inner = Radius.circular(innerRadius(context));
    final bool hasHeading =
        title?.isNotEmpty == true ||
        subtitle?.isNotEmpty == true ||
        accentLabel?.trim().isNotEmpty == true;

    final Widget heading = hasHeading
        ? Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              AppSpacing.xs,
              AppSpacing.md,
              10,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                if (accentIcon != null && title?.isNotEmpty == true) ...<Widget>[
                  _SettingsSectionAccent(
                    icon: accentIcon!,
                    color: accentColor,
                    foreground: accentForeground,
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (title?.isNotEmpty == true)
                        Semantics(
                          header: true,
                          child: Text(
                            title!,
                            style: text.titleSmall?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
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
                if (accentLabel?.trim().isNotEmpty == true) ...<Widget>[
                  const SizedBox(width: AppSpacing.sm),
                  _SettingsSectionLabel(
                    label: accentLabel!,
                    color: accentColor,
                    foreground: accentForeground,
                  ),
                ],
              ],
            ),
          )
        : const SizedBox.shrink();

    final Widget rows = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        heading,
        for (var index = 0; index < items.length; index++) ...[
          if (index != 0) const SizedBox(height: 2),
          Builder(
            builder: (context) {
              final standsAlone = index == selectedIndex;
              final radius = standsAlone
                  ? BorderRadius.circular(outer)
                  : BorderRadius.vertical(
                      top: Radius.circular(index == 0 ? outer : inner.x),
                      bottom: Radius.circular(
                        index == items.length - 1 ? outer : inner.x,
                      ),
                    );
              final color = isCard
                  ? scheme.surfaceContainerLow
                  : scheme.surface;
              final Widget row = SettingsGroupScope(
                borderRadius: radius,
                color: color,
                child: Material(
                  // The row paints its own fill, so its rounder corners
                  // must not show a squarer tile underneath.
                  color: standsAlone ? Colors.transparent : color,
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
    );

    // The group is one block: it enters as a block, so the rows never arrive
    // out of step with their card. Reduced motion is handled inside
    // [M3Entrance]; a staggered group already owns the per-row timing.
    final Widget animated = stagger || !animateEntrance
        ? rows
        : M3Entrance(offsetY: 12, child: rows);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: semanticLabel == null
          ? animated
          : Semantics(container: true, label: semanticLabel, child: animated),
    );
  }
}

/// Heading badge: a small squircle tile in the accent's tonal pair.
class _SettingsSectionAccent extends StatelessWidget {
  const _SettingsSectionAccent({
    required this.icon,
    this.color,
    this.foreground,
  });

  final IconData icon;
  final Color? color;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color fill = color ?? scheme.primaryContainer;
    final Color ink = foreground ?? scheme.onPrimaryContainer;
    return M3Container(
      Shapes.square,
      width: 32,
      height: 32,
      color: fill,
      child: Center(child: Icon(icon, size: 18, color: ink)),
    );
  }
}

/// Heading pill for a short text mark next to the title.
class _SettingsSectionLabel extends StatelessWidget {
  const _SettingsSectionLabel({
    required this.label,
    this.color,
    this.foreground,
  });

  final String label;
  final Color? color;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color fill = color ?? scheme.secondaryContainer;
    final Color ink = foreground ?? scheme.onSecondaryContainer;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: AppRadii.fullRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 2,
          vertical: 3,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: ink,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

// Rows live in settings/settings_list_item.dart (exported above).
