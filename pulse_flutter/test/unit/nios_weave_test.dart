import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/identity/nios_weave.dart';
import 'package:pulse_flutter/models/chat_wallpaper_config.dart';

void main() {
  group('NiosWeave Binary Codec & Positional Hash (NW)', () {
    test('encode and decode roundtrip preserves essential wallpaper properties', () {
      final config = ChatWallpaperConfig(
        seed: 42105,
        layoutMode: WallpaperLayoutMode.hex,
        iconSource: IconSource.tabler,
        density: 0.65,
        cellSize: 72.0,
        gridAngle: 15.0,
        randomRotationDeg: 25.0,
        randomScaleJitter: 0.20,
        themePack: 'tech',
        useAllIcons: true,
        filled: true,
        staggerByRow: false,
        backgroundStyle: WallpaperBackgroundStyle.radialGlow,
        backgroundRole: 'surfaceContainerHigh',
        backgroundSecondaryRole: 'primaryContainer',
        gradientAngle: 90.0,
        iconColorRole: 'primary',
        colorMode: WallpaperColorMode.tonalAccent,
        iconAlpha: 0.85,
      );

      final String code = NiosWeave.encode(config);
      expect(code.startsWith('nwv1:'), isTrue);

      final ChatWallpaperConfig? decoded = NiosWeave.decode(code);
      expect(decoded, isNotNull);
      expect(decoded!.seed, equals(config.seed));
      expect(decoded.layoutMode, equals(config.layoutMode));
      expect(decoded.iconSource, equals(config.iconSource));
      expect(decoded.filled, equals(config.filled));
      expect(decoded.staggerByRow, equals(config.staggerByRow));
      expect(decoded.themePack, equals(config.themePack));
      expect(decoded.useAllIcons, equals(config.useAllIcons));
      expect(decoded.backgroundStyle, equals(config.backgroundStyle));
      expect(decoded.backgroundRole, equals(config.backgroundRole));
      expect(decoded.backgroundSecondaryRole, equals(config.backgroundSecondaryRole));
      expect(decoded.iconColorRole, equals(config.iconColorRole));
      expect(decoded.colorMode, equals(config.colorMode));

      // Clamped / quantized float metrics within reasonable epsilon
      expect((decoded.density - config.density).abs(), lessThan(0.02));
      expect((decoded.cellSize - config.cellSize).abs(), lessThan(1.0));
      expect((decoded.iconAlpha - config.iconAlpha).abs(), lessThan(0.02));
    });

    test('toShareUrl generates correct URL and decode parses it', () {
      const config = ChatWallpaperConfig.defaultPattern;
      final String code = NiosWeave.encode(config);
      final String url = NiosWeave.toShareUrl(code);

      expect(url.startsWith('https://ni-os.ru/w/'), isTrue);

      final ChatWallpaperConfig? fromUrl = NiosWeave.decode(url);
      expect(fromUrl, isNotNull);
      expect(fromUrl!.seed, equals(config.seed));
      expect(fromUrl.layoutMode, equals(config.layoutMode));
    });

    test('decode returns null for corrupted or invalid codes', () {
      expect(NiosWeave.decode(''), isNull);
      expect(NiosWeave.decode('invalid_prefix'), isNull);
      expect(NiosWeave.decode('nwv1:???bad_base64???'), isNull);
      expect(NiosWeave.decode('nwv1:AAAA'), isNull); // too short
      expect(NiosWeave.decode('nwv2:AQIDBAUGBwgJCgsMDQ4PEA=='), isNull); // wrong version
    });

    test('posHash 2D positional hashing guarantees deterministic, avalanche-mixed values', () {
      final int h1 = NiosWeave.posHash(12345, 10, 20);
      final int h2 = NiosWeave.posHash(12345, 10, 20);
      final int hDiffX = NiosWeave.posHash(12345, 11, 20);
      final int hDiffY = NiosWeave.posHash(12345, 10, 21);
      final int hDiffSeed = NiosWeave.posHash(12346, 10, 20);

      expect(h1, equals(h2));
      expect(h1 >= 0, isTrue);
      expect(h1, isNot(equals(hDiffX)));
      expect(h1, isNot(equals(hDiffY)));
      expect(h1, isNot(equals(hDiffSeed)));
    });

    test('deriveUserSignature generates deterministic personal Weave config', () {
      final sig1 = NiosWeave.deriveUserSignature('alice');
      final sig2 = NiosWeave.deriveUserSignature('alice');
      final sigBob = NiosWeave.deriveUserSignature('bob');

      expect(sig1.seed, equals(sig2.seed));
      expect(sig1.iconSource, equals(IconSource.niosMess));
      expect(sig1.seed, isNot(equals(sigBob.seed)));
    });
  });
}
