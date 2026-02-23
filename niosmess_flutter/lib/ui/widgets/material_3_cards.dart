import 'package:flutter/material.dart';

/// Material 3 стилизованные карточки для NiosMess
class Material3Cards {
  /// Standard Card в стиле Material 3
  static Widget standardCard({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
    double borderRadius = 16.0,
    Color? backgroundColor,
    Color? surfaceTintColor,
    double? elevation,
    List<BoxShadow>? shadow,
    EdgeInsets margin = EdgeInsets.zero,
  }) {
    return Card(
      elevation: elevation ?? 1.0,
      shadowColor: shadow?.firstOrNull?.color ?? Colors.black.withOpacity(0.1),
      surfaceTintColor: surfaceTintColor,
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: BorderSide(
          color: Colors.transparent,
        ),
      ),
      margin: margin,
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }

  /// Elevated Card в стиле Material 3
  static Widget elevatedCard({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
    double borderRadius = 16.0,
    Color? backgroundColor,
    Color? surfaceTintColor,
    double elevation = 3.0,
    EdgeInsets margin = EdgeInsets.zero,
  }) {
    return Card(
      elevation: elevation,
      surfaceTintColor: surfaceTintColor,
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      margin: margin,
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }

  /// Outlined Card в стиле Material 3
  static Widget outlinedCard({
    required BuildContext context,
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
    double borderRadius = 16.0,
    Color? backgroundColor,
    Color? outlineColor,
    double outlineWidth = 1.0,
    double elevation = 0.0,
    EdgeInsets margin = EdgeInsets.zero,
  }) {
    return Card(
      elevation: elevation,
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: BorderSide(
          color: outlineColor ?? Theme.of(context).colorScheme.outline,
          width: outlineWidth,
        ),
      ),
      margin: margin,
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }

  /// Filled Card в стиле Material 3
  static Widget filledCard({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
    double borderRadius = 16.0,
    Color? backgroundColor,
    double elevation = 0.0,
    EdgeInsets margin = EdgeInsets.zero,
  }) {
    return Card(
      elevation: elevation,
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      margin: margin,
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }

  /// Tinted Card (с поверхностью с оттенком) в стиле Material 3
  static Widget tintedCard({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
    double borderRadius = 16.0,
    Color? backgroundColor,
    Color? surfaceTintColor,
    double elevation = 0.0,
    EdgeInsets margin = EdgeInsets.zero,
  }) {
    return Card(
      elevation: elevation,
      color: backgroundColor,
      surfaceTintColor: surfaceTintColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      margin: margin,
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }

  /// Navigation Card (для навигационных элементов) в стиле Material 3
  static Widget navigationCard({
    required Widget child,
    required VoidCallback onTap,
    EdgeInsets padding = const EdgeInsets.all(16),
    double borderRadius = 16.0,
    Color? backgroundColor,
    Color? surfaceTintColor,
    double elevation = 1.0,
    EdgeInsets margin = EdgeInsets.zero,
  }) {
    return Card(
      elevation: elevation,
      color: backgroundColor,
      surfaceTintColor: surfaceTintColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      margin: margin,
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// Расширение для Theme для получения Material 3 стилей карточек
extension Material3CardTheme on ThemeData {
  /// Возвращает стиль Card в Material 3
  ShapeBorder get cardShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      );

  /// Возвращает стиль для заполненных карточек
  CardTheme get filledCard => CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      );

  /// Возвращает стиль для карточек с обводкой
  CardTheme get outlinedCard => CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.outline,
          ),
        ),
      );
}

/// Виджет для карточки чата в стиле Material 3
class ChatCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isSelected;
  final Color? selectedColor;

  const ChatCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.isSelected = false,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Material3Cards.navigationCard(
      onTap: onTap ?? () {},
      backgroundColor: isSelected 
          ? selectedColor?.withOpacity(0.1) ?? colorScheme.primary.withOpacity(0.1)
          : null,
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isSelected 
                        ? selectedColor ?? colorScheme.primary
                        : colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Виджет для карточки настроек в стиле Material 3
class SettingsCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  const SettingsCard({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    Widget content = Row(
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
    
    if (onTap != null) {
      return Material3Cards.navigationCard(
        onTap: onTap!,
        padding: padding,
        child: content,
      );
    } else {
      return Material3Cards.standardCard(
        padding: padding,
        child: content,
      );
    }
  }
}