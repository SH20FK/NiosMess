import 'package:flutter/material.dart';

/// Материал 3 стилизованные кнопки для NiosMess
class Material3Buttons {
  /// Elevated Button в стиле Material 3
  static Widget elevatedButton({
    required VoidCallback onPressed,
    required String text,
    Color? backgroundColor,
    Color? foregroundColor,
    double? elevation,
    double borderRadius = 16.0,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        elevation: elevation ?? 2.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        padding: padding,
        shadowColor: Colors.black.withOpacity(0.2),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Filled Button в стиле Material 3
  static Widget filledButton({
    required VoidCallback onPressed,
    required String text,
    Color? backgroundColor,
    Color? foregroundColor,
    double borderRadius = 16.0,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
  }) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        padding: padding,
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Toned Button (Filled tonal) в стиле Material 3
  static Widget tonalButton({
    required VoidCallback onPressed,
    required String text,
    Color? backgroundColor,
    Color? foregroundColor,
    double borderRadius = 16.0,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
  }) {
    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        padding: padding,
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Outlined Button в стиле Material 3
  static Widget outlinedButton({
    required VoidCallback onPressed,
    required String text,
    Color? foregroundColor,
    Color? sideColor,
    double borderRadius = 16.0,
    double sideWidth = 1.5,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: foregroundColor,
        side: BorderSide(
          color: sideColor ?? foregroundColor ?? Colors.grey,
          width: sideWidth,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        padding: padding,
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Text Button в стиле Material 3
  static Widget textButton({
    required VoidCallback onPressed,
    required String text,
    Color? foregroundColor,
    double borderRadius = 16.0,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  }) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: foregroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        padding: padding,
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Icon Button в стиле Material 3
  static Widget iconButton({
    required VoidCallback onPressed,
    required IconData icon,
    Color? backgroundColor,
    Color? foregroundColor,
    double? size,
    double iconSize = 24.0,
    double borderRadius = 12.0,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: iconSize),
      style: IconButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        minimumSize: Size(size ?? 48, size ?? 48),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }

  /// Segmented Button в стиле Material 3
  static Widget segmentedButton<T>({
    required List<ButtonSegment<T>> segments,
    required ValueChanged<T> onSelectionChanged,
    required T selected,
  }) {
    return SegmentedButton<T>(
      segments: segments,
      selected: {selected},
      onSelectionChanged: (Set<T> newSelection) {
        onSelectionChanged(newSelection.first);
      },
    );
  }
}

/// Расширение для Theme для получения Material 3 стилей кнопок
extension Material3ButtonTheme on ThemeData {
  /// Возвращает стиль Elevated Button в Material 3
  ButtonStyle get elevatedButtonMaterial3 => ElevatedButton.styleFrom(
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      );

  /// Возвращает стиль Filled Button в Material 3
  ButtonStyle get filledButtonMaterial3 => FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      );

  /// Возвращает стиль Outlined Button в Material 3
  ButtonStyle get outlinedButtonMaterial3 => OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      );
}