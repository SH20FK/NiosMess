import 'package:flutter/material.dart';

/// A standardized Material 3 Expressive action item for [MenuAnchor] menus.
///
/// Ensures unified typography, destructive error coloring, icon sizing,
/// and disabled states across toolbars, message actions, and cards.
class AppActionMenuItem {
  const AppActionMenuItem({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isDestructive = false,
    this.isDisabled = false,
    this.iconColor,
  });

  /// The visible action title.
  final String label;

  /// The leading glyph icon.
  final IconData icon;

  /// Callback executed when this action is tapped.
  final VoidCallback? onPressed;

  /// Whether this action represents a destructive or hazardous operation (e.g. Delete, Leave, Kick).
  final bool isDestructive;

  /// Whether this item is currently disabled.
  final bool isDisabled;

  /// Custom icon color override (defaults to error color if [isDestructive], or onSurfaceVariant).
  final Color? iconColor;

  /// Converts this descriptor into a Material 3 [MenuItemButton].
  Widget toMenuItem(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final Color effectiveColor = isDestructive
        ? scheme.error
        : (iconColor ?? scheme.onSurface);

    final Color effectiveIconColor = isDestructive
        ? scheme.error
        : (iconColor ?? scheme.onSurfaceVariant);

    return MenuItemButton(
      leadingIcon: Icon(
        icon,
        size: 20,
        color: isDisabled
            ? scheme.onSurface.withValues(alpha: 0.38)
            : effectiveIconColor,
      ),
      onPressed: isDisabled ? null : onPressed,
      child: Text(
        label,
        style: textTheme.labelLarge?.copyWith(
          color: isDisabled
              ? scheme.onSurface.withValues(alpha: 0.38)
              : effectiveColor,
          fontWeight: isDestructive ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );
  }

  /// Helper to convert a list of [AppActionMenuItem] into menu widgets.
  static List<Widget> buildItems(
    BuildContext context,
    List<AppActionMenuItem> items,
  ) {
    return items
        .map((AppActionMenuItem item) => item.toMenuItem(context))
        .toList(growable: false);
  }
}
