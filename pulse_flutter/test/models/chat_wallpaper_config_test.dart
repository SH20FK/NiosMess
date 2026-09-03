import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/models/chat_wallpaper_config.dart';

void main() {
  group('ChatWallpaperConfig', () {
    test('Default configuration holds correct defaults', () {
      const config = ChatWallpaperConfig.defaultPattern;
      expect(config.iconSource, IconSource.materialSymbols);
      expect(config.glyphName, 'star');
      expect(config.useAllIcons, true);
      expect(config.layoutMode, WallpaperLayoutMode.stagger);
      expect(config.density, 0.75);
      expect(config.seed, 42);
    });

    test('Serialization and deserialization works symmetrically', () {
      const original = ChatWallpaperConfig(
        iconSource: IconSource.lucide,
        glyphName: 'sparkles',
        glyphCodepoint: 0x1234,
        svgAssetPath: 'assets/svg/pattern_icons/lucide/sparkles.svg',
        useAllIcons: true,
        filled: true,
        weight: 600.0,
        cellSize: 64.0,
        gridAngle: 45.0,
        density: 0.85,
        layoutMode: WallpaperLayoutMode.spiral,
        staggerByRow: false,
        randomRotationDeg: 30.0,
        randomScaleJitter: 0.25,
        colorMode: WallpaperColorMode.palette,
        iconAlpha: 0.18,
        seed: 101,
        backgroundRole: 'surfaceContainerHighest',
        iconColorRole: 'tertiary',
      );

      final jsonStr = original.toJson();
      final restored = ChatWallpaperConfig.fromJson(jsonStr);

      expect(restored.iconSource, IconSource.lucide);
      expect(restored.glyphName, 'sparkles');
      expect(restored.useAllIcons, true);
      expect(restored.svgAssetPath, 'assets/svg/pattern_icons/lucide/sparkles.svg');
      expect(restored.filled, true);
      expect(restored.weight, 600.0);
      expect(restored.cellSize, 64.0);
      expect(restored.gridAngle, 45.0);
      expect(restored.density, 0.85);
      expect(restored.layoutMode, WallpaperLayoutMode.spiral);
      expect(restored.staggerByRow, false);
      expect(restored.randomRotationDeg, 30.0);
      expect(restored.randomScaleJitter, 0.25);
      expect(restored.colorMode, WallpaperColorMode.palette);
      expect(restored.iconAlpha, 0.18);
      expect(restored.seed, 101);
      expect(restored.backgroundRole, 'surfaceContainerHighest');
      expect(restored.iconColorRole, 'tertiary');
    });

    test('copyWith updates specified fields only', () {
      const config = ChatWallpaperConfig();
      final updated = config.copyWith(
        layoutMode: WallpaperLayoutMode.hex,
        cellSize: 80.0,
        useAllIcons: false,
      );
      expect(updated.layoutMode, WallpaperLayoutMode.hex);
      expect(updated.cellSize, 80.0);
      expect(updated.useAllIcons, false);
      expect(updated.density, config.density);
      expect(updated.seed, config.seed);
    });
  });
}
