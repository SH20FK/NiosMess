import 'dart:convert';

enum IconSource {
  materialSymbols,
  phosphor,
  lucide,
  tabler,
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

class ChatWallpaperConfig {
  const ChatWallpaperConfig({
    this.iconSource = IconSource.materialSymbols,
    this.symbolsStyle = MaterialSymbolsStyle.rounded,
    this.glyphName = 'star',
    this.glyphCodepoint = 0xe838,
    this.svgAssetPath,
    this.m3ShapeName,
    this.useAllIcons = true,
    this.filled = false,
    this.weight = 400.0,
    this.cellSize = 64.0,
    this.gridAngle = 0.0,
    this.density = 0.75,
    this.layoutMode = WallpaperLayoutMode.stagger,
    this.staggerByRow = true,
    this.randomRotationDeg = 15.0,
    this.randomScaleJitter = 0.15,
    this.colorMode = WallpaperColorMode.singleTone,
    this.iconAlpha = 0.12,
    this.seed = 42,
    this.backgroundRole = 'surfaceContainerLow',
    this.iconColorRole = 'primary',
    this.paletteRoles = const <String>[
      'primary',
      'secondary',
      'tertiary',
      'outline',
    ],
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
  final String iconColorRole;
  final List<String> paletteRoles;

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
    String? iconColorRole,
    List<String>? paletteRoles,
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
      iconColorRole: iconColorRole ?? this.iconColorRole,
      paletteRoles: paletteRoles ?? this.paletteRoles,
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
      'iconColorRole': iconColorRole,
      'paletteRoles': paletteRoles,
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
      iconColorRole: map['iconColorRole'] as String? ?? 'primary',
      paletteRoles: (map['paletteRoles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const <String>['primary', 'secondary', 'tertiary', 'outline'],
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
        other.iconColorRole == iconColorRole;
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
        iconColorRole,
      ]);
}
