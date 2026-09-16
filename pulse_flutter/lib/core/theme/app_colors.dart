import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

class AppColors {
  const AppColors._();

  /// Unified semantic online presence green across all screens.
  static const Color statusOnline = Color(0xFF22C55E);

  /// Unified semantic call decline and destructive red across all screens.
  static const Color statusDanger = Color(0xFFE53935);

  /// Stable 32-bit FNV-1a hash algorithm across all platforms and Dart runtimes.
  static int _fnv1a32(String input) {
    var hash = 0x811c9dc5;
    for (var i = 0; i < input.length; i++) {
      hash ^= input.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    return hash;
  }

  /// Deterministic, scheme-harmonized avatar color for any user or chat ID.
  static Color avatarColorFor(String id, ColorScheme scheme) {
    final double hue = (_fnv1a32(id) % 360).toDouble();
    final bool isDark = scheme.brightness == Brightness.dark;
    return Color(Hct.from(hue, 44.0, isDark ? 68.0 : 44.0).toInt());
  }

  /// High-contrast readable foreground color for any avatar background.
  static Color avatarTextColorFor(Color backgroundColor, ColorScheme scheme) {
    final double luminance = backgroundColor.computeLuminance();
    return luminance > 0.45 ? scheme.onPrimaryContainer : scheme.onPrimary;
  }
}

/// Backward compatible top-level function that delegates to [AppColors.avatarColorFor].
Color avatarColorFor(String id, ColorScheme scheme) =>
    AppColors.avatarColorFor(id, scheme);


