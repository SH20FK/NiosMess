import 'package:flutter_m3shapes/flutter_m3shapes.dart';

/// Collections of official Material 3 Expressive shapes and curated wallpaper doodles.
///
/// Fully eliminates broken web SVGs and delivers pure vector rendering at 120 FPS.
class CuratedWallpaperCatalog {
  const CuratedWallpaperCatalog._();

  // ── 1. All 34 Official Material 3 Expressive Shapes ─────────────────────────
  static const List<Shapes> allM3Shapes = <Shapes>[
    // Organic & Hearts
    Shapes.gem,
    Shapes.flower,
    Shapes.hearth,
    Shapes.l4_leaf_clover,
    Shapes.puffy,
    Shapes.puffy_diamond,
    Shapes.ghostish,
    // Bursts & Radiance
    Shapes.burst,
    Shapes.soft_burst,
    Shapes.sunny,
    Shapes.very_sunny,
    Shapes.boom,
    Shapes.soft_boom,
    Shapes.l8_leaf_clover,
    // Cookie & Rosette Family
    Shapes.c4_sided_cookie,
    Shapes.c6_sided_cookie,
    Shapes.c7_sided_cookie,
    Shapes.c9_sided_cookie,
    Shapes.c12_sided_cookie,
    // Pure Geometry & Architecture
    Shapes.diamond,
    Shapes.pentagon,
    Shapes.slanted,
    Shapes.arch,
    Shapes.fan,
    Shapes.pill,
    Shapes.semicircle,
    Shapes.bun,
    Shapes.triangle,
    Shapes.arrow,
    Shapes.oval,
    Shapes.circle,
    Shapes.square,
    // Retro & Pixels
    Shapes.pixel_circle,
    Shapes.pixel_triangle,
  ];

  // ── 2. The 5 Curated M3 Expressive Shape Families ───────────────────────────

  /// Organic shapes, flowers, hearts and clovers
  static const List<Shapes> organicShapes = <Shapes>[
    Shapes.hearth,
    Shapes.gem,
    Shapes.flower,
    Shapes.l4_leaf_clover,
    Shapes.puffy,
    Shapes.puffy_diamond,
    Shapes.ghostish,
  ];

  /// Bursts, suns, explosions and radial stars
  static const List<Shapes> radianceShapes = <Shapes>[
    Shapes.soft_burst,
    Shapes.burst,
    Shapes.sunny,
    Shapes.very_sunny,
    Shapes.boom,
    Shapes.soft_boom,
    Shapes.l8_leaf_clover,
  ];

  /// Rosette and gear cookies (4, 6, 7, 9, 12 lobes)
  static const List<Shapes> cookieShapes = <Shapes>[
    Shapes.c9_sided_cookie,
    Shapes.c4_sided_cookie,
    Shapes.c6_sided_cookie,
    Shapes.c7_sided_cookie,
    Shapes.c12_sided_cookie,
  ];

  /// Architectural and clean geometric primitives
  static const List<Shapes> geometryShapes = <Shapes>[
    Shapes.diamond,
    Shapes.arch,
    Shapes.fan,
    Shapes.pill,
    Shapes.pentagon,
    Shapes.slanted,
    Shapes.bun,
    Shapes.semicircle,
    Shapes.triangle,
    Shapes.oval,
  ];

  /// Pixelated retro shapes
  static const List<Shapes> pixelShapes = <Shapes>[
    Shapes.pixel_circle,
    Shapes.pixel_triangle,
  ];

  // ── 3. Curated Messaging Wallpaper Doodles (Clean codepoints) ────────────────
  static const List<String> curatedChatDoodles = <String>[
    'chat',
    'favorite',
    'send',
    'bolt',
    'star',
    'auto_awesome',
    'notifications',
    'mood',
    'local_fire_department',
    'thumb_up',
  ];

  static const List<String> curatedSpaceDoodles = <String>[
    'rocket_launch',
    'star',
    'auto_awesome',
    'dark_mode',
    'public',
    'satellite_alt',
    'flare',
    'explore',
  ];

  static const List<String> curatedLifestyleDoodles = <String>[
    'coffee',
    'local_pizza',
    'cake',
    'cookie',
    'headphones',
    'sports_esports',
    'music_note',
  ];

  static const List<String> curatedNatureDoodles = <String>[
    'eco',
    'park',
    'local_florist',
    'water_drop',
    'wb_sunny',
    'ac_unit',
    'forest',
  ];

  // ── 4. Human-readable localized names for M3 Shapes ──────────────────────────
  static String shapeName(Shapes shape) {
    return switch (shape) {
      Shapes.hearth => 'Сердце',
      Shapes.gem => 'Кристалл',
      Shapes.flower => 'Цветок',
      Shapes.l4_leaf_clover => 'Клевер',
      Shapes.puffy => 'Облако',
      Shapes.puffy_diamond => 'Пуф-ромб',
      Shapes.ghostish => 'Привидение',
      Shapes.burst => 'Вспышка',
      Shapes.soft_burst => 'Сияние',
      Shapes.sunny => 'Солнце',
      Shapes.very_sunny => 'Звезда',
      Shapes.boom => 'Взрыв',
      Shapes.soft_boom => 'Поп-звезда',
      Shapes.l8_leaf_clover => 'Астра',
      Shapes.c4_sided_cookie => 'Куки 4',
      Shapes.c6_sided_cookie => 'Куки 6',
      Shapes.c7_sided_cookie => 'Куки 7',
      Shapes.c9_sided_cookie => 'Куки 9',
      Shapes.c12_sided_cookie => 'Куки 12',
      Shapes.diamond => 'Ромб',
      Shapes.pentagon => 'Пятиугольник',
      Shapes.slanted => 'Скос',
      Shapes.arch => 'Арка',
      Shapes.fan => 'Веер',
      Shapes.pill => 'Капсула',
      Shapes.semicircle => 'Полукруг',
      Shapes.bun => 'Булочка',
      Shapes.triangle => 'Треугольник',
      Shapes.arrow => 'Стрела',
      Shapes.oval => 'Овал',
      Shapes.circle => 'Круг',
      Shapes.square => 'Квадрат',
      Shapes.pixel_circle => 'Пиксель-круг',
      Shapes.pixel_triangle => 'Пиксель-треуг',
    };
  }

  /// Resolves an enum [Shapes] from its string name.
  static Shapes resolveShape(String name) {
    for (final Shapes s in Shapes.values) {
      if (s.name.toLowerCase() == name.toLowerCase() ||
          s.toString().split('.').last.toLowerCase() == name.toLowerCase()) {
        return s;
      }
    }
    // Fallback alias mappings
    return switch (name.toLowerCase()) {
      'heart' || 'hearth' => Shapes.hearth,
      'cookie' || 'c9' => Shapes.c9_sided_cookie,
      'clover' => Shapes.l4_leaf_clover,
      'star' || 'sun' => Shapes.sunny,
      'softburst' || 'soft_burst' => Shapes.soft_burst,
      'crystal' => Shapes.gem,
      _ => Shapes.gem,
    };
  }

  /// Theme collection identifiers for wallpaper styling
  static const String packOrganic = 'm3_organic';
  static const String packRadiance = 'm3_radiance';
  static const String packCookies = 'm3_cookies';
  static const String packGeometry = 'm3_geometry';
  static const String packPixels = 'm3_pixels';
  static const String packAllM3 = 'm3_all';

  /// Maps a pack identifier to its list of shapes
  static List<Shapes> getShapesForPack(String pack) {
    return switch (pack) {
      packOrganic => organicShapes,
      packRadiance => radianceShapes,
      packCookies => cookieShapes,
      packGeometry => geometryShapes,
      packPixels => pixelShapes,
      _ => allM3Shapes,
    };
  }
}
