import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/theme/nios_chroma.dart';

void main() {
  group('NiosChroma Contextual Palette Engine (NC)', () {
    setUp(() {
      NiosChroma.clearCache();
    });

    test('Custom user wallpapers strictly take precedence over Chroma', () {
      expect(
        NiosChroma.shouldApply(hasCustomWallpaper: true, userChromaEnabled: true),
        isFalse,
      );
      expect(
        NiosChroma.shouldApply(hasCustomWallpaper: true, userChromaEnabled: false),
        isFalse,
      );
      expect(
        NiosChroma.shouldApply(hasCustomWallpaper: false, userChromaEnabled: true),
        isTrue,
      );
      expect(
        NiosChroma.shouldApply(hasCustomWallpaper: false, userChromaEnabled: false),
        isFalse,
      );
    });

    test('resolveChromaScheme caches result and returns identical instance on repeated queries', () {
      const userScheme = ColorScheme.light(primary: Color(0xFF1E88E5));

      final scheme1 = NiosChroma.resolveChromaScheme(
        userScheme: userScheme,
        partnerId: 'user_bob',
        chatId: 42,
      );

      final scheme2 = NiosChroma.resolveChromaScheme(
        userScheme: userScheme,
        partnerId: 'user_bob',
        chatId: 42,
      );

      expect(identical(scheme1, scheme2), isTrue);
      expect(scheme1.primary, equals(scheme2.primary));
    });

    test('clearCache invalidates cached schemes', () {
      const userScheme = ColorScheme.light(primary: Color(0xFF1E88E5));

      final scheme1 = NiosChroma.resolveChromaScheme(
        userScheme: userScheme,
        partnerId: 'user_alice',
        chatId: 101,
      );

      NiosChroma.clearCache();

      final scheme2 = NiosChroma.resolveChromaScheme(
        userScheme: userScheme,
        partnerId: 'user_alice',
        chatId: 101,
      );

      expect(scheme1.primary, equals(scheme2.primary));
      expect(identical(scheme1, scheme2), isFalse);
    });
  });
}
