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

  static TextTheme get textTheme => build(const ColorScheme.light());

  static TextTheme build(ColorScheme scheme) {
    return TextTheme(
      // Display: Bricolage Grotesque (Expressive hero headlines)
      displayLarge: TextStyle(
        fontFamily: AppFonts.headline,
        fontSize: 57,
        height: 64 / 57,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.25,
        color: scheme.onSurface,
        fontVariations: const <FontVariation>[
          FontVariation('wght', 800),
          FontVariation('opsz', 57),
        ],
      ),
      displayMedium: TextStyle(
        fontFamily: AppFonts.headline,
        fontSize: 45,
        height: 52 / 45,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: scheme.onSurface,
        fontVariations: const <FontVariation>[
          FontVariation('wght', 700),
          FontVariation('opsz', 45),
        ],
      ),
      displaySmall: TextStyle(
        fontFamily: AppFonts.headline,
        fontSize: 36,
        height: 44 / 36,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: scheme.onSurface,
        fontVariations: const <FontVariation>[
          FontVariation('wght', 700),
          FontVariation('opsz', 36),
        ],
      ),

      // Headlines: Bricolage Grotesque (Section and page headers)
      headlineLarge: TextStyle(
        fontFamily: AppFonts.headline,
        fontSize: 32,
        height: 40 / 32,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: scheme.onSurface,
        fontVariations: const <FontVariation>[
          FontVariation('wght', 700),
          FontVariation('opsz', 32),
        ],
      ),
      headlineMedium: TextStyle(
        fontFamily: AppFonts.headline,
        fontSize: 28,
        height: 36 / 28,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: scheme.onSurface,
        fontVariations: const <FontVariation>[
          FontVariation('wght', 700),
          FontVariation('opsz', 28),
        ],
      ),
      headlineSmall: TextStyle(
        fontFamily: AppFonts.headline,
        fontSize: 24,
        height: 32 / 24,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: scheme.onSurface,
        fontVariations: const <FontVariation>[
          FontVariation('wght', 600),
          FontVariation('opsz', 24),
        ],
      ),

      // Titles: Onest (Universal UI grotesque for cards, lists, and dialogs)
      titleLarge: TextStyle(
        fontFamily: AppFonts.ui,
        fontSize: 22,
        height: 28 / 22,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: scheme.onSurface,
        fontVariations: const <FontVariation>[
          FontVariation('wght', 700),
        ],
      ),
      titleMedium: TextStyle(
        fontFamily: AppFonts.ui,
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
        color: scheme.onSurface,
        fontVariations: const <FontVariation>[
          FontVariation('wght', 600),
        ],
      ),
      titleSmall: TextStyle(
        fontFamily: AppFonts.ui,
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: scheme.onSurface,
        fontVariations: const <FontVariation>[
          FontVariation('wght', 600),
        ],
      ),

      // Labels: Onest (Buttons, chips, badges, and tabs - colors decoupled for surfaces)
      labelLarge: TextStyle(
        fontFamily: AppFonts.ui,
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: scheme.onSurface,
        fontVariations: const <FontVariation>[
          FontVariation('wght', 600),
        ],
      ),
      labelMedium: TextStyle(
        fontFamily: AppFonts.ui,
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: scheme.onSurface,
        fontVariations: const <FontVariation>[
          FontVariation('wght', 600),
        ],
      ),
      labelSmall: TextStyle(
        fontFamily: AppFonts.ui,
        fontSize: 11,
        height: 16 / 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: scheme.onSurface,
        fontVariations: const <FontVariation>[
          FontVariation('wght', 500),
        ],
      ),

      // Body: Golos Text (ParaType reading comfort)
      bodyLarge: TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        color: scheme.onSurface,
      ),
      bodyMedium: TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        color: scheme.onSurface,
      ),
      bodySmall: TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}
