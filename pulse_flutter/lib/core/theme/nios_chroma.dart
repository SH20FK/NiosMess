import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:pulse_flutter/core/identity/nios_mark.dart';

/// Nios Chroma — Partner-Harmonized Contextual Palette Engine.
///
/// Harmonizes the partner's unique Nios Mark color with the user's active theme
/// via [Blend.harmonize] to tint chat surfaces, bubbles, and accents without
/// clashing with user theme brightness or custom wallpapers.
abstract final class NiosChroma {
  /// Bounded LRU cache of harmonized [ColorScheme] instances per chat.
  static final LinkedHashMap<String, ColorScheme> _chromaCache =
      LinkedHashMap<String, ColorScheme>();
  static const int _maxCacheSize = 64;

  /// Determines whether Nios Chroma contextual palette should be applied to a chat.
  ///
  /// Per the design specification, custom user wallpapers take precedence over Chroma.
  static bool shouldApply({
    required bool hasCustomWallpaper,
    bool userChromaEnabled = true,
  }) {
    if (hasCustomWallpaper) return false;
    return userChromaEnabled;
  }

  /// Harmonizes partner color with [userScheme] and returns a cached [ColorScheme].
  static ColorScheme resolveChromaScheme({
    required ColorScheme userScheme,
    required String partnerId,
    required int chatId,
  }) {
    final String cacheKey =
        '${chatId}_${partnerId}_${userScheme.brightness.index}_${userScheme.primary.toARGB32()}';

    if (_chromaCache.containsKey(cacheKey)) {
      return _chromaCache[cacheKey]!;
    }

    // 1. Resolve partner's base identity color
    final Color partnerBaseColor = NiosMark.resolveColor(partnerId, userScheme);

    // 2. Harmonize partner color with user primary color
    final int harmonizedArgb = Blend.harmonize(
      partnerBaseColor.toARGB32(),
      userScheme.primary.toARGB32(),
    );
    final Color harmonizedSeed = Color(harmonizedArgb);

    // 3. Generate harmonized scheme using Material 3 tonal palette
    final ColorScheme harmonizedScheme = ColorScheme.fromSeed(
      seedColor: harmonizedSeed,
      brightness: userScheme.brightness,
    );

    // 4. Subtle accent blend: keep surface tones anchored to user's theme for legibility
    final ColorScheme blendedScheme = userScheme.copyWith(
      primary: harmonizedScheme.primary,
      secondary: harmonizedScheme.secondary,
      tertiary: harmonizedScheme.tertiary,
      primaryContainer: harmonizedScheme.primaryContainer,
      secondaryContainer: harmonizedScheme.secondaryContainer,
      tertiaryContainer: harmonizedScheme.tertiaryContainer,
      onPrimaryContainer: harmonizedScheme.onPrimaryContainer,
      onSecondaryContainer: harmonizedScheme.onSecondaryContainer,
    );

    if (_chromaCache.length >= _maxCacheSize) {
      _chromaCache.remove(_chromaCache.keys.first);
    }
    _chromaCache[cacheKey] = blendedScheme;

    return blendedScheme;
  }

  /// Clears cache when themes or user settings change globally.
  static void clearCache() {
    _chromaCache.clear();
  }
}
