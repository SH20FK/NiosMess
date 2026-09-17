import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/identity/nios_weave.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/motion/tri_sync.dart';
import 'package:pulse_flutter/core/services/app_url_launcher.dart';
import 'package:pulse_flutter/models/chat_wallpaper_config.dart';

void main() {
  group('Phase 4: Moments & Deep Link Routing', () {
    test('AppUrlLauncher resolves /w/{code} to wallpaper settings route', () {
      final Uri uri = Uri.parse('https://ni-os.ru/w/ARI0ITEKtDItMgF4KDI');
      final String? route = AppUrlLauncher.resolveInternalAppRoute(uri);
      expect(route, equals('/settings/wallpaper?code=ARI0ITEKtDItMgF4KDI'));
    });

    test('AppUrlLauncher resolves niosmess://w/{code} deep link', () {
      final Uri uri = Uri.parse('niosmess://w/sample_code_123');
      final String? route = AppUrlLauncher.resolveInternalAppRoute(uri);
      expect(route, equals('/settings/wallpaper?code=sample_code_123'));
    });

    test('AppUrlLauncher resolves /wallpaper?code=... parameter', () {
      final Uri uri = Uri.parse('https://ni-os.ru/wallpaper?code=sample_code_456');
      final String? route = AppUrlLauncher.resolveInternalAppRoute(uri);
      expect(route, equals('/settings/wallpaper?code=sample_code_456'));
    });

    test('MOM-1 / MOM-5 / MOM-6 Normalized M3 Springs satisfy boundary invariant', () {
      expect(M3SpringCurves.emphasized.transform(0.0), closeTo(0.0, 1e-6));
      expect(M3SpringCurves.emphasized.transform(1.0), closeTo(1.0, 1e-6));

      expect(M3SpringCurves.spatial.transform(0.0), closeTo(0.0, 1e-6));
      expect(M3SpringCurves.spatial.transform(1.0), closeTo(1.0, 1e-6));

      expect(M3SpringCurves.bouncy.transform(0.0), closeTo(0.0, 1e-6));
      expect(M3SpringCurves.bouncy.transform(1.0), closeTo(1.0, 1e-6));

      expect(M3SpringCurves.gentle.transform(0.0), closeTo(0.0, 1e-6));
      expect(M3SpringCurves.gentle.transform(1.0), closeTo(1.0, 1e-6));
    });

    test('TriSync reaction and pop triggers execute cleanly', () {
      expect(() => TriSync.reaction(), returnsNormally);
      expect(() => TriSync.pop(), returnsNormally);
    });

    test('NiosWeave share URL matches backend /w/{code} endpoint', () {
      const config = ChatWallpaperConfig.defaultPattern;
      final String shareUrl = NiosWeave.generateShareUrl(config);
      expect(shareUrl, startsWith('https://ni-os.ru/w/'));
      final Uri parsed = Uri.parse(shareUrl);
      final String? resolvedRoute = AppUrlLauncher.resolveInternalAppRoute(parsed);
      expect(resolvedRoute, isNotNull);
      expect(resolvedRoute, startsWith('/settings/wallpaper?code='));
    });
  });
}
