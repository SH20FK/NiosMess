import 'dart:convert';
import 'package:flutter/material.dart';

enum IconSource {
  materialSymbols,
  phosphor,
  lucide,
  tabler,
  cupertino,
  niosMess,
}

enum MaterialSymbolsStyle {
  outlined,
  rounded,
  sharp,
}

enum WallpaperLayoutMode {
  grid,
  stagger,
  scatter,
  hex,
  spiral,
}

enum WallpaperColorMode {
  singleTone,
  palette,
  tonalAccent,
}

enum WallpaperBackgroundStyle {
  solid,
  linearGradient,
  radialGlow,
}

class ChatWallpaperPreset {
  const ChatWallpaperPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.config,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final ChatWallpaperConfig config;
}

class ChatWallpaperConfig {
  const ChatWallpaperConfig({
    this.iconSource = IconSource.niosMess,
    this.symbolsStyle = MaterialSymbolsStyle.rounded,
    this.glyphName = 'gem',
    this.glyphCodepoint = 0xe838,
    this.svgAssetPath,
    this.m3ShapeName,
    this.useAllIcons = true,
    this.filled = false,
    this.weight = 400.0,
    this.cellSize = 62.0,
    this.gridAngle = 0.0,
    this.density = 0.70,
    this.layoutMode = WallpaperLayoutMode.stagger,
    this.staggerByRow = true,
    this.randomRotationDeg = 15.0,
    this.randomScaleJitter = 0.15,
    this.colorMode = WallpaperColorMode.tonalAccent,
    this.iconAlpha = 0.16,
    this.seed = 42,
    this.backgroundRole = 'surfaceContainerLow',
    this.backgroundSecondaryRole = 'surfaceContainerLowest',
    this.backgroundStyle = WallpaperBackgroundStyle.solid,
    this.gradientAngle = 135.0,
    this.iconColorRole = 'primary',
    this.paletteRoles = const <String>[
      'primary',
      'secondary',
      'tertiary',
      'outline',
    ],
    this.themePack = 'm3_organic',
    this.selectedGlyphs = const <String>[],
    this.imagePath,
    this.imageBlur = 0.0,
    this.imageDim = 0.15,
  });

  final IconSource iconSource;
  final MaterialSymbolsStyle symbolsStyle;
  final String glyphName;
  final int glyphCodepoint;
  final String? svgAssetPath;
  final String? m3ShapeName;
  final bool useAllIcons;
  final bool filled;
  final double weight;
  final double cellSize;
  final double gridAngle;
  final double density;
  final WallpaperLayoutMode layoutMode;
  final bool staggerByRow;
  final double randomRotationDeg;
  final double randomScaleJitter;
  final WallpaperColorMode colorMode;
  final double iconAlpha;
  final int seed;
  final String backgroundRole;
  final String backgroundSecondaryRole;
  final WallpaperBackgroundStyle backgroundStyle;
  final double gradientAngle;
  final String iconColorRole;
  final List<String> paletteRoles;
  final String themePack;
  final List<String> selectedGlyphs;
  final String? imagePath;
  final double imageBlur;
  final double imageDim;

  static const ChatWallpaperConfig defaultPattern = ChatWallpaperConfig();

  ChatWallpaperConfig copyWith({
    IconSource? iconSource,
    MaterialSymbolsStyle? symbolsStyle,
    String? glyphName,
    int? glyphCodepoint,
    String? svgAssetPath,
    String? m3ShapeName,
    bool? useAllIcons,
    bool? filled,
    double? weight,
    double? cellSize,
    double? gridAngle,
    double? density,
    WallpaperLayoutMode? layoutMode,
    bool? staggerByRow,
    double? randomRotationDeg,
    double? randomScaleJitter,
    WallpaperColorMode? colorMode,
    double? iconAlpha,
    int? seed,
    String? backgroundRole,
    String? backgroundSecondaryRole,
    WallpaperBackgroundStyle? backgroundStyle,
    double? gradientAngle,
    String? iconColorRole,
    List<String>? paletteRoles,
    String? themePack,
    List<String>? selectedGlyphs,
    String? imagePath,
    bool clearImagePath = false,
    double? imageBlur,
    double? imageDim,
  }) {
    return ChatWallpaperConfig(
      iconSource: iconSource ?? this.iconSource,
      symbolsStyle: symbolsStyle ?? this.symbolsStyle,
      glyphName: glyphName ?? this.glyphName,
      glyphCodepoint: glyphCodepoint ?? this.glyphCodepoint,
      svgAssetPath: svgAssetPath ?? this.svgAssetPath,
      m3ShapeName: m3ShapeName ?? this.m3ShapeName,
      useAllIcons: useAllIcons ?? this.useAllIcons,
      filled: filled ?? this.filled,
      weight: weight ?? this.weight,
      cellSize: cellSize ?? this.cellSize,
      gridAngle: gridAngle ?? this.gridAngle,
      density: density ?? this.density,
      layoutMode: layoutMode ?? this.layoutMode,
      staggerByRow: staggerByRow ?? this.staggerByRow,
      randomRotationDeg: randomRotationDeg ?? this.randomRotationDeg,
      randomScaleJitter: randomScaleJitter ?? this.randomScaleJitter,
      colorMode: colorMode ?? this.colorMode,
      iconAlpha: iconAlpha ?? this.iconAlpha,
      seed: seed ?? this.seed,
      backgroundRole: backgroundRole ?? this.backgroundRole,
      backgroundSecondaryRole:
          backgroundSecondaryRole ?? this.backgroundSecondaryRole,
      backgroundStyle: backgroundStyle ?? this.backgroundStyle,
      gradientAngle: gradientAngle ?? this.gradientAngle,
      iconColorRole: iconColorRole ?? this.iconColorRole,
      paletteRoles: paletteRoles ?? this.paletteRoles,
      themePack: themePack ?? this.themePack,
      selectedGlyphs: selectedGlyphs ?? this.selectedGlyphs,
      imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
      imageBlur: imageBlur ?? this.imageBlur,
      imageDim: imageDim ?? this.imageDim,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'iconSource': iconSource.name,
      'symbolsStyle': symbolsStyle.name,
      'glyphName': glyphName,
      'glyphCodepoint': glyphCodepoint,
      if (svgAssetPath != null) 'svgAssetPath': svgAssetPath,
      if (m3ShapeName != null) 'm3ShapeName': m3ShapeName,
      'useAllIcons': useAllIcons,
      'filled': filled,
      'weight': weight,
      'cellSize': cellSize,
      'gridAngle': gridAngle,
      'density': density,
      'layoutMode': layoutMode.name,
      'staggerByRow': staggerByRow,
      'randomRotationDeg': randomRotationDeg,
      'randomScaleJitter': randomScaleJitter,
      'colorMode': colorMode.name,
      'iconAlpha': iconAlpha,
      'seed': seed,
      'backgroundRole': backgroundRole,
      'backgroundSecondaryRole': backgroundSecondaryRole,
      'backgroundStyle': backgroundStyle.name,
      'gradientAngle': gradientAngle,
      'iconColorRole': iconColorRole,
      'paletteRoles': paletteRoles,
      'themePack': themePack,
      'selectedGlyphs': selectedGlyphs,
      if (imagePath != null) 'imagePath': imagePath,
      'imageBlur': imageBlur,
      'imageDim': imageDim,
    };
  }

  factory ChatWallpaperConfig.fromMap(Map<String, dynamic> map) {
    return ChatWallpaperConfig(
      iconSource: IconSource.values.firstWhere(
        (e) => e.name == map['iconSource'],
        orElse: () => IconSource.materialSymbols,
      ),
      symbolsStyle: MaterialSymbolsStyle.values.firstWhere(
        (e) => e.name == map['symbolsStyle'],
        orElse: () => MaterialSymbolsStyle.rounded,
      ),
      glyphName: map['glyphName'] as String? ?? 'star',
      glyphCodepoint: (map['glyphCodepoint'] as num?)?.toInt() ?? 0xe838,
      svgAssetPath: map['svgAssetPath'] as String?,
      m3ShapeName: map['m3ShapeName'] as String?,
      useAllIcons: map['useAllIcons'] as bool? ?? true,
      filled: map['filled'] as bool? ?? false,
      weight: (map['weight'] as num?)?.toDouble() ?? 400.0,
      cellSize: (map['cellSize'] as num?)?.toDouble() ?? 64.0,
      gridAngle: (map['gridAngle'] as num?)?.toDouble() ?? 0.0,
      density: (map['density'] as num?)?.toDouble() ?? 0.75,
      layoutMode: WallpaperLayoutMode.values.firstWhere(
        (e) => e.name == map['layoutMode'],
        orElse: () => WallpaperLayoutMode.stagger,
      ),
      staggerByRow: map['staggerByRow'] as bool? ?? true,
      randomRotationDeg: (map['randomRotationDeg'] as num?)?.toDouble() ?? 15.0,
      randomScaleJitter: (map['randomScaleJitter'] as num?)?.toDouble() ?? 0.15,
      colorMode: WallpaperColorMode.values.firstWhere(
        (e) => e.name == map['colorMode'],
        orElse: () => WallpaperColorMode.singleTone,
      ),
      iconAlpha: (map['iconAlpha'] as num?)?.toDouble() ?? 0.12,
      seed: (map['seed'] as num?)?.toInt() ?? 42,
      backgroundRole: map['backgroundRole'] as String? ?? 'surfaceContainerLow',
      backgroundSecondaryRole:
          map['backgroundSecondaryRole'] as String? ?? 'surfaceContainerLowest',
      backgroundStyle: WallpaperBackgroundStyle.values.firstWhere(
        (e) => e.name == map['backgroundStyle'],
        orElse: () => WallpaperBackgroundStyle.solid,
      ),
      gradientAngle: (map['gradientAngle'] as num?)?.toDouble() ?? 135.0,
      iconColorRole: map['iconColorRole'] as String? ?? 'primary',
      paletteRoles: (map['paletteRoles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const <String>['primary', 'secondary', 'tertiary', 'outline'],
      themePack: map['themePack'] as String? ?? 'all',
      selectedGlyphs: (map['selectedGlyphs'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const <String>[],
      imagePath: map['imagePath'] as String?,
      imageBlur: (map['imageBlur'] as num?)?.toDouble() ?? 0.0,
      imageDim: (map['imageDim'] as num?)?.toDouble() ?? 0.15,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory ChatWallpaperConfig.fromJson(String source) {
    try {
      final dynamic decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) {
        return ChatWallpaperConfig.fromMap(decoded);
      }
    } catch (_) {}
    return const ChatWallpaperConfig();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatWallpaperConfig &&
        other.iconSource == iconSource &&
        other.symbolsStyle == symbolsStyle &&
        other.glyphName == glyphName &&
        other.glyphCodepoint == glyphCodepoint &&
        other.svgAssetPath == svgAssetPath &&
        other.m3ShapeName == m3ShapeName &&
        other.useAllIcons == useAllIcons &&
        other.filled == filled &&
        other.weight == weight &&
        other.cellSize == cellSize &&
        other.gridAngle == gridAngle &&
        other.density == density &&
        other.layoutMode == layoutMode &&
        other.staggerByRow == staggerByRow &&
        other.randomRotationDeg == randomRotationDeg &&
        other.randomScaleJitter == randomScaleJitter &&
        other.colorMode == colorMode &&
        other.iconAlpha == iconAlpha &&
        other.seed == seed &&
        other.backgroundRole == backgroundRole &&
        other.backgroundSecondaryRole == backgroundSecondaryRole &&
        other.backgroundStyle == backgroundStyle &&
        other.gradientAngle == gradientAngle &&
        other.iconColorRole == iconColorRole &&
        _listEquals(other.paletteRoles, paletteRoles) &&
        other.themePack == themePack &&
        _listEquals(other.selectedGlyphs, selectedGlyphs) &&
        other.imagePath == imagePath &&
        other.imageBlur == imageBlur &&
        other.imageDim == imageDim;
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[
        iconSource,
        symbolsStyle,
        glyphName,
        glyphCodepoint,
        svgAssetPath,
        m3ShapeName,
        useAllIcons,
        filled,
        weight,
        cellSize,
        gridAngle,
        density,
        layoutMode,
        staggerByRow,
        randomRotationDeg,
        randomScaleJitter,
        colorMode,
        iconAlpha,
        seed,
        backgroundRole,
        backgroundSecondaryRole,
        backgroundStyle,
        gradientAngle,
        iconColorRole,
        Object.hashAll(paletteRoles),
        themePack,
        Object.hashAll(selectedGlyphs),
        imagePath,
        imageBlur,
        imageDim,
      ]);
}

/// Curated high-aesthetic wallpaper presets
final List<ChatWallpaperPreset> kDefaultWallpaperPresets = <ChatWallpaperPreset>[
  const ChatWallpaperPreset(
    id: 'm3_organic',
    name: 'M3E Органика',
    description: 'Фирменные кристаллы, цветы, сердца и клевер',
    icon: Icons.favorite_rounded,
    config: ChatWallpaperConfig(
      iconSource: IconSource.niosMess,
      themePack: 'm3_organic',
      useAllIcons: false,
      layoutMode: WallpaperLayoutMode.stagger,
      density: 0.70,
      cellSize: 62.0,
      iconAlpha: 0.16,
      backgroundRole: 'surfaceContainerLow',
      backgroundSecondaryRole: 'surfaceContainerLowest',
      backgroundStyle: WallpaperBackgroundStyle.solid,
      colorMode: WallpaperColorMode.tonalAccent,
      filled: false,
      seed: 42,
    ),
  ),
  const ChatWallpaperPreset(
    id: 'm3_radiance',
    name: 'M3E Сияние',
    description: 'Мягкие вспышки, солнца и звездные лучи',
    icon: Icons.auto_awesome_rounded,
    config: ChatWallpaperConfig(
      iconSource: IconSource.niosMess,
      themePack: 'm3_radiance',
      useAllIcons: false,
      layoutMode: WallpaperLayoutMode.scatter,
      density: 0.65,
      cellSize: 64.0,
      iconAlpha: 0.18,
      backgroundRole: 'surfaceContainerLowest',
      backgroundSecondaryRole: 'primaryContainer',
      backgroundStyle: WallpaperBackgroundStyle.radialGlow,
      colorMode: WallpaperColorMode.tonalAccent,
      filled: true,
      seed: 777,
    ),
  ),
  const ChatWallpaperPreset(
    id: 'm3_cookies',
    name: 'M3E Печеньки',
    description: 'Семейство розеток и печенек от 4 до 12 лепестков',
    icon: Icons.cookie_rounded,
    config: ChatWallpaperConfig(
      iconSource: IconSource.niosMess,
      themePack: 'm3_cookies',
      useAllIcons: false,
      layoutMode: WallpaperLayoutMode.hex,
      density: 0.72,
      cellSize: 60.0,
      iconAlpha: 0.18,
      backgroundRole: 'surfaceContainerLowest',
      backgroundSecondaryRole: 'surfaceContainerHigh',
      backgroundStyle: WallpaperBackgroundStyle.linearGradient,
      gradientAngle: 135.0,
      colorMode: WallpaperColorMode.tonalAccent,
      filled: false,
      seed: 2026,
    ),
  ),
  const ChatWallpaperPreset(
    id: 'm3_geometry',
    name: 'M3E Геометрия',
    description: 'Чистые архитектурные арки, ромбы, вееры и капсулы',
    icon: Icons.category_rounded,
    config: ChatWallpaperConfig(
      iconSource: IconSource.niosMess,
      themePack: 'm3_geometry',
      useAllIcons: false,
      layoutMode: WallpaperLayoutMode.grid,
      density: 0.60,
      cellSize: 66.0,
      iconAlpha: 0.15,
      backgroundRole: 'surfaceContainerLow',
      backgroundSecondaryRole: 'secondaryContainer',
      backgroundStyle: WallpaperBackgroundStyle.linearGradient,
      gradientAngle: 90.0,
      colorMode: WallpaperColorMode.singleTone,
      filled: true,
      seed: 888,
    ),
  ),
  const ChatWallpaperPreset(
    id: 'doodles_chat',
    name: 'Nios Дудлы',
    description: 'Кураторские символы чата, искр и сообщений',
    icon: Icons.chat_bubble_rounded,
    config: ChatWallpaperConfig(
      iconSource: IconSource.materialSymbols,
      themePack: 'chat',
      useAllIcons: false,
      layoutMode: WallpaperLayoutMode.stagger,
      density: 0.68,
      cellSize: 60.0,
      iconAlpha: 0.15,
      backgroundRole: 'surfaceContainerLowest',
      backgroundSecondaryRole: 'surfaceContainerHigh',
      backgroundStyle: WallpaperBackgroundStyle.radialGlow,
      colorMode: WallpaperColorMode.palette,
      filled: false,
      seed: 101,
    ),
  ),
  const ChatWallpaperPreset(
    id: 'oled_minimal',
    name: 'OLED Минимал',
    description: 'Глубокий черный фон со строгой M3E-формой',
    icon: Icons.dark_mode_rounded,
    config: ChatWallpaperConfig(
      iconSource: IconSource.niosMess,
      themePack: 'm3_organic',
      useAllIcons: false,
      layoutMode: WallpaperLayoutMode.grid,
      density: 0.50,
      cellSize: 72.0,
      iconAlpha: 0.12,
      backgroundRole: 'surfaceContainerLowest',
      backgroundStyle: WallpaperBackgroundStyle.solid,
      colorMode: WallpaperColorMode.singleTone,
      iconColorRole: 'outline',
      filled: false,
      seed: 555,
    ),
  ),
];
