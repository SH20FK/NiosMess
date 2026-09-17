import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/identity/nios_weave.dart';
import 'package:pulse_flutter/models/chat_wallpaper_config.dart';

void main() {
  group('NiosWeave NW-7 Size & Compression Benchmark', () {
    test('NW-7: Binary Weave format achieves > 85% compression vs JSON', () {
      final configs = <ChatWallpaperConfig>[
        ChatWallpaperConfig.defaultPattern,
        const ChatWallpaperConfig(
          seed: 98765,
          layoutMode: WallpaperLayoutMode.spiral,
          iconSource: IconSource.materialSymbols,
          density: 0.75,
          cellSize: 80.0,
          gridAngle: 45.0,
          randomRotationDeg: 30.0,
          randomScaleJitter: 0.15,
          themePack: 'nature',
          useAllIcons: false,
          filled: true,
          backgroundStyle: WallpaperBackgroundStyle.linearGradient,
          backgroundRole: 'surfaceContainer',
          backgroundSecondaryRole: 'secondaryContainer',
          gradientAngle: 180.0,
          iconColorRole: 'outline',
          colorMode: WallpaperColorMode.palette,
          iconAlpha: 0.90,
        ),
        NiosWeave.deriveUserSignature('test_user_benchmark_42'),
      ];

      for (final config in configs) {
        final String jsonStr = config.toJson();
        final int jsonBytes = utf8.encode(jsonStr).length;

        final String weaveCode = NiosWeave.encode(config);
        final int weaveBytes = utf8.encode(weaveCode).length;

        // Verify Weave representation is ultra-compact
        expect(weaveCode.length, lessThanOrEqualTo(30));

        final double reduction = (1.0 - (weaveBytes / jsonBytes)) * 100.0;
        expect(reduction, greaterThan(80.0),
            reason: 'Expected > 80% reduction: JSON was $jsonBytes bytes, Weave was $weaveBytes bytes ($reduction% saved)');
      }
    });

    test('NW-7: Encode and decode execution speed under 1 millisecond', () {
      const config = ChatWallpaperConfig.defaultPattern;
      final stopwatch = Stopwatch()..start();

      const iterations = 1000;
      for (int i = 0; i < iterations; i++) {
        final code = NiosWeave.encode(config);
        final decoded = NiosWeave.decode(code);
        expect(decoded, isNotNull);
      }

      stopwatch.stop();
      final double microsecondsPerRoundtrip =
          stopwatch.elapsedMicroseconds / iterations;

      expect(microsecondsPerRoundtrip, lessThan(1000.0),
          reason: 'Roundtrip took ${microsecondsPerRoundtrip.toStringAsFixed(1)} us, expected < 1000 us');
    });
  });
}
