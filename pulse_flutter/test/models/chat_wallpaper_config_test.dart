import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/models/chat_wallpaper_config.dart';

void main() {
  group('ChatWallpaperConfig', () {
    test('Default configuration holds correct defaults', () {
      const config = ChatWallpaperConfig.defaultPattern;
      expect(config.iconSource, IconSource.niosMess);
      expect(config.glyphName, 'gem');
      expect(config.useAllIcons, true);
      expect(config.layoutMode, WallpaperLayoutMode.stagger);
      expect(config.density, 0.70);
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

    test('themePack and selectedGlyphs serialization and copyWith', () {
      const original = ChatWallpaperConfig(
        themePack: 'tech',
        selectedGlyphs: <String>['code', 'terminal', 'cpu'],
      );
      final jsonStr = original.toJson();
      final restored = ChatWallpaperConfig.fromJson(jsonStr);

      expect(restored.themePack, 'tech');
      expect(restored.selectedGlyphs, <String>['code', 'terminal', 'cpu']);

      final modified = restored.copyWith(themePack: 'space', selectedGlyphs: <String>['rocket']);
      expect(modified.themePack, 'space');
      expect(modified.selectedGlyphs, <String>['rocket']);
    });

    test('Gradient styles and new icon sources serialize correctly', () {
      const config = ChatWallpaperConfig(
        iconSource: IconSource.cupertino,
        backgroundStyle: WallpaperBackgroundStyle.linearGradient,
        backgroundSecondaryRole: 'primaryContainer',
        gradientAngle: 135.0,
      );

      final jsonStr = config.toJson();
      final restored = ChatWallpaperConfig.fromJson(jsonStr);

      expect(restored.iconSource, IconSource.cupertino);
      expect(restored.backgroundStyle, WallpaperBackgroundStyle.linearGradient);
      expect(restored.backgroundSecondaryRole, 'primaryContainer');
      expect(restored.gradientAngle, 135.0);
    });

    test('paletteRoles affects equality and hashCode', () {
      const config1 = ChatWallpaperConfig(
        paletteRoles: <String>['primary', 'secondary'],
      );
      const config2 = ChatWallpaperConfig(
        paletteRoles: <String>['primary', 'tertiary'],
      );
      const config3 = ChatWallpaperConfig(
        paletteRoles: <String>['primary', 'secondary'],
      );

      expect(config1 == config2, isFalse);
      expect(config1 == config3, isTrue);
      expect(config1.hashCode == config3.hashCode, isTrue);
    });

    test('kDefaultWallpaperPresets contains valid curated presets', () {
      expect(kDefaultWallpaperPresets, isNotEmpty);
      for (final preset in kDefaultWallpaperPresets) {
        expect(preset.id, isNotEmpty);
        expect(preset.name, isNotEmpty);
        expect(preset.config, isNotNull);
      }
    });

    test('Custom photo wallpaper fields serialize and deserialize correctly', () {
      const config = ChatWallpaperConfig(
        imagePath: '/path/to/my_custom_wallpaper.png',
        imageBlur: 8.5,
        imageDim: 0.35,
      );

      final jsonStr = config.toJson();
      final restored = ChatWallpaperConfig.fromJson(jsonStr);

      expect(restored.imagePath, '/path/to/my_custom_wallpaper.png');
      expect(restored.imageBlur, 8.5);
      expect(restored.imageDim, 0.35);

      final updated = restored.copyWith(imageBlur: 12.0, imageDim: 0.5);
      expect(updated.imageBlur, 12.0);
      expect(updated.imageDim, 0.5);
      expect(updated.imagePath, '/path/to/my_custom_wallpaper.png');

      final cleared = updated.copyWith(imagePath: '');
      expect(cleared.imagePath, '');
    });
  });
}

