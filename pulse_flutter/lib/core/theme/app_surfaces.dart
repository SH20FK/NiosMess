import 'package:flutter/material.dart';

/// Neutral app chrome. Accent colors still come from the user's palette.
abstract final class AppSurfaces {
  static Color background(Brightness brightness) =>
      brightness == Brightness.dark
      ? const Color(0xFF1A1A1A)
      : const Color(0xFFF2F2F2);

  static Color of(BuildContext context) =>
      background(Theme.of(context).brightness);

  static ColorScheme neutralize(ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    return scheme.copyWith(
      surface: background(scheme.brightness),
      surfaceDim: dark ? const Color(0xFF141414) : const Color(0xFFDEDEDE),
      surfaceBright: dark ? const Color(0xFF3A3A3A) : const Color(0xFFF9F9F9),
      surfaceContainerLowest: dark
          ? const Color(0xFF141414)
          : const Color(0xFFFCFCFC),
      surfaceContainerLow: dark
          ? const Color(0xFF202020)
          : const Color(0xFFEDEDED),
      surfaceContainer: dark
          ? const Color(0xFF252525)
          : const Color(0xFFE8E8E8),
      surfaceContainerHigh: dark
          ? const Color(0xFF2C2C2C)
          : const Color(0xFFE2E2E2),
      surfaceContainerHighest: dark
          ? const Color(0xFF353535)
          : const Color(0xFFDCDCDC),
      onSurface: dark ? const Color(0xFFE6E6E6) : const Color(0xFF1C1C1C),
      onSurfaceVariant: dark
          ? const Color(0xFFBEBEBE)
          : const Color(0xFF505050),
      outline: dark ? const Color(0xFF8C8C8C) : const Color(0xFF747474),
      outlineVariant: dark ? const Color(0xFF454545) : const Color(0xFFC7C7C7),
      inverseSurface: dark ? const Color(0xFFE6E6E6) : const Color(0xFF303030),
      onInverseSurface: dark
          ? const Color(0xFF303030)
          : const Color(0xFFF0F0F0),
    );
  }
}
