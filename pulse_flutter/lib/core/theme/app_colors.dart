import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

/// Scheme-aware avatar color: hue from the identity hash, chroma and tone
/// from the active scheme, so avatars always agree with the theme.
Color avatarColorFor(String id, ColorScheme scheme) {
  final double hue = (id.hashCode.abs() % 360).toDouble();
  final bool isDark = scheme.brightness == Brightness.dark;
  return Color(Hct.from(hue, 48.0, isDark ? 70.0 : 48.0).toInt());
}

class AppColors {
  const AppColors._();

  static Color avatarColorFor(String id, ColorScheme scheme) {
    final double hue = (id.hashCode.abs() % 360).toDouble();
    final bool isDark = scheme.brightness == Brightness.dark;
    return Color(Hct.from(hue, 48.0, isDark ? 70.0 : 48.0).toInt());
  }
}

