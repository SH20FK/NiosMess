import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/identity/nios_mark.dart';

class AppColors {
  const AppColors._();

  /// Unified semantic online presence green across all screens.
  static const Color statusOnline = Color(0xFF22C55E);

  /// Unified semantic call decline and destructive red across all screens.
  static const Color statusDanger = Color(0xFFE53935);

  /// Deterministic, scheme-harmonized avatar color for any user or chat ID.
  static Color avatarColorFor(String id, ColorScheme scheme) =>
      NiosMark.resolveColor(id, scheme);

  /// High-contrast readable foreground color for any avatar background.
  static Color avatarTextColorFor(Color backgroundColor, ColorScheme scheme) {
    final double luminance = backgroundColor.computeLuminance();
    return luminance > 0.45 ? scheme.onPrimaryContainer : scheme.onPrimary;
  }
}

/// Backward compatible top-level function that delegates to [AppColors.avatarColorFor].
Color avatarColorFor(String id, ColorScheme scheme) =>
    AppColors.avatarColorFor(id, scheme);


