import 'package:flutter/material.dart';
import 'package:pulse_flutter/models/chat_wallpaper_config.dart';

/// Curated semantic wallpaper preset with user-facing aesthetic naming.
class CuratedWallpaperPreset {
  const CuratedWallpaperPreset({
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

final List<CuratedWallpaperPreset> kCuratedWallpaperPresets = <CuratedWallpaperPreset>[
  const CuratedWallpaperPreset(
    id: 'soft_waves',
    name: 'Мягкие волны',
    description: 'Органические формы и спокойные кристаллы',
    icon: Icons.water_rounded,
    config: ChatWallpaperConfig(
      iconSource: IconSource.niosMess,
      themePack: 'm3_organic',
      useAllIcons: false,
      layoutMode: WallpaperLayoutMode.stagger,
      density: 0.65,
      cellSize: 64.0,
      iconAlpha: 0.15,
      backgroundRole: 'surfaceContainerLow',
      backgroundSecondaryRole: 'surfaceContainerLowest',
      backgroundStyle: WallpaperBackgroundStyle.solid,
      colorMode: WallpaperColorMode.tonalAccent,
      filled: false,
      seed: 42,
    ),
  ),
  const CuratedWallpaperPreset(
    id: 'radiance',
    name: 'Сияние',
    description: 'Мягкий радиальный свет и искры',
    icon: Icons.auto_awesome_rounded,
    config: ChatWallpaperConfig(
      iconSource: IconSource.niosMess,
      themePack: 'm3_radiance',
      useAllIcons: false,
      layoutMode: WallpaperLayoutMode.scatter,
      density: 0.60,
      cellSize: 68.0,
      iconAlpha: 0.18,
      backgroundRole: 'surfaceContainerLowest',
      backgroundSecondaryRole: 'primaryContainer',
      backgroundStyle: WallpaperBackgroundStyle.radialGlow,
      colorMode: WallpaperColorMode.tonalAccent,
      filled: true,
      seed: 777,
    ),
  ),
  const CuratedWallpaperPreset(
    id: 'dots_grid',
    name: 'Точки и сетка',
    description: 'Минималистичные ровные маркеры',
    icon: Icons.grain_rounded,
    config: ChatWallpaperConfig(
      iconSource: IconSource.materialSymbols,
      glyphName: 'circle',
      glyphCodepoint: 0xef4a,
      useAllIcons: false,
      layoutMode: WallpaperLayoutMode.grid,
      density: 0.85,
      cellSize: 48.0,
      iconAlpha: 0.12,
      backgroundRole: 'surfaceContainerLow',
      backgroundStyle: WallpaperBackgroundStyle.solid,
      colorMode: WallpaperColorMode.singleTone,
      filled: true,
      seed: 101,
    ),
  ),
  const CuratedWallpaperPreset(
    id: 'midnight_matrix',
    name: 'Ночная сетка',
    description: 'Гексагональный узор с градиентным переливом',
    icon: Icons.hexagon_outlined,
    config: ChatWallpaperConfig(
      iconSource: IconSource.materialSymbols,
      glyphName: 'hexagon',
      glyphCodepoint: 0xeb3d,
      useAllIcons: false,
      layoutMode: WallpaperLayoutMode.hex,
      density: 0.70,
      cellSize: 58.0,
      iconAlpha: 0.14,
      backgroundRole: 'surfaceContainerLowest',
      backgroundSecondaryRole: 'surfaceContainerHigh',
      backgroundStyle: WallpaperBackgroundStyle.linearGradient,
      gradientAngle: 145.0,
      colorMode: WallpaperColorMode.palette,
      filled: false,
      seed: 808,
    ),
  ),
  const CuratedWallpaperPreset(
    id: 'crystals',
    name: 'Кристаллы',
    description: 'Геометрические грани в мягком свечении',
    icon: Icons.diamond_outlined,
    config: ChatWallpaperConfig(
      iconSource: IconSource.materialSymbols,
      glyphName: 'diamond',
      glyphCodepoint: 0xead5,
      useAllIcons: false,
      layoutMode: WallpaperLayoutMode.scatter,
      density: 0.55,
      cellSize: 72.0,
      iconAlpha: 0.16,
      backgroundRole: 'surfaceContainerLow',
      backgroundSecondaryRole: 'tertiaryContainer',
      backgroundStyle: WallpaperBackgroundStyle.radialGlow,
      colorMode: WallpaperColorMode.tonalAccent,
      filled: false,
      seed: 999,
    ),
  ),
  const CuratedWallpaperPreset(
    id: 'minimal_clean',
    name: 'Чистый минимал',
    description: 'Лаконичный фон без узоров и лишнего шума',
    icon: Icons.crop_square_rounded,
    config: ChatWallpaperConfig(
      iconSource: IconSource.materialSymbols,
      glyphName: 'blank',
      glyphCodepoint: 0,
      useAllIcons: false,
      density: 0.0,
      iconAlpha: 0.0,
      backgroundRole: 'surfaceContainerLow',
      backgroundStyle: WallpaperBackgroundStyle.solid,
      colorMode: WallpaperColorMode.singleTone,
      filled: false,
      seed: 1,
    ),
  ),
];
