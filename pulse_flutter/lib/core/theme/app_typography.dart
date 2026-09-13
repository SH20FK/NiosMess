import 'package:flutter/material.dart';

class AppFonts {
  const AppFonts._();

  /// Expressive headlines and display titles with optical size, variable weight, and ink traps.
  static const String headline = 'BricolageGrotesque';

  /// Universal geometric & humanist grotesque for UI elements, titles, navigation, and badges.
  static const String ui = 'Onest';

  /// Comfortable reading font for chat messages, descriptions, long paragraphs, and bios.
  static const String body = 'GolosText';

  /// Fallbacks
  static const String fallbackDisplay = 'PlusJakartaSans';
  static const String fallbackBody = 'Inter';
}

class AppTypography {
  const AppTypography._();

  static TextTheme build(ColorScheme scheme) {
    return TextTheme(
      // Display: Bricolage Grotesque
      displayLarge: TextStyle(
        fontFamily: AppFonts.headline,
        fontSize: 36,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: scheme.onSurface,
      ),
      displayMedium: TextStyle(
        fontFamily: AppFonts.headline,
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.45,
        color: scheme.onSurface,
      ),
      displaySmall: TextStyle(
        fontFamily: AppFonts.headline,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: scheme.onSurface,
      ),

      // Headlines: Bricolage Grotesque
      headlineLarge: TextStyle(
        fontFamily: AppFonts.headline,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: scheme.onSurface,
      ),
      headlineMedium: TextStyle(
        fontFamily: AppFonts.headline,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: scheme.onSurface,
      ),
      headlineSmall: TextStyle(
        fontFamily: AppFonts.headline,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: scheme.onSurface,
      ),

      // Titles: Onest (Universal UI grotesque)
      titleLarge: TextStyle(
        fontFamily: AppFonts.ui,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: scheme.onSurface,
      ),
      titleMedium: TextStyle(
        fontFamily: AppFonts.ui,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: scheme.onSurface,
      ),
      titleSmall: TextStyle(
        fontFamily: AppFonts.ui,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),

      // Labels: Onest (Crisp buttons, tags, tabs)
      labelLarge: TextStyle(
        fontFamily: AppFonts.ui,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
      labelMedium: TextStyle(
        fontFamily: AppFonts.ui,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: scheme.onSurfaceVariant,
      ),
      labelSmall: TextStyle(
        fontFamily: AppFonts.ui,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: scheme.onSurfaceVariant,
      ),

      // Body: Golos Text (Korolkova & Kuzmin / ParaType, reading comfort)
      bodyLarge: TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 16,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: scheme.onSurface,
      ),
      bodyMedium: TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 14,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: scheme.onSurface,
      ),
      bodySmall: TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}
