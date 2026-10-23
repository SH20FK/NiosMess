import 'package:test/test.dart';
import 'package:pulse_flutter/services/calls/call_capture_profile.dart';
import 'package:pulse_flutter/router/web_settings_location.dart';

void main() {
  for (final height in [240, 480, 720, 1080]) {
    test(
      'native capture requests the granted $height profile rather than old minimums',
      () {
        final profile = CallCaptureProfile(height);
        final native = profile.constraints(isWeb: false, video: true);
        expect((native['video'] as Map)['height'], height);
        expect((native['video'] as Map)['frameRate'], 30);
        expect((native['video'] as Map).containsKey('mandatory'), false);
        expect((native['audio'] as Map)['echoCancellation'], true);
        final browser =
            profile.constraints(isWeb: true, video: true)['video'] as Map;
        expect(browser['height'], {'ideal': height, 'max': height});
        expect(browser['frameRate'], {'ideal': 30, 'max': 30});
      },
    );
  }
  test(
    'voice calls never request a camera; invalid gateway limits fall back safely',
    () {
      expect(CallCaptureProfile(0).height, 480);
      expect(CallCaptureProfile(-10).height, 480);
      expect(CallCaptureProfile(2160).height, 1080);
      expect(CallCaptureProfile(100).height, 100);
      expect(
        CallCaptureProfile(480).constraints(isWeb: true, video: false)['video'],
        false,
      );
    },
  );
  test(
    'legacy settings links preserve their anchor and stay inside the workspace',
    () {
      final uri = Uri.parse(
        webSettingsRedirect(
          Uri.parse('/settings/language-region?anchor=locale'),
        )!,
      );
      expect(uri.path, '/main/settings');
      expect(uri.queryParameters, {
        'section': 'languageRegion',
        'anchor': 'locale',
      });
      expect(
        webSettingsRedirect(Uri.parse('/settings/system-device')),
        '/main/settings?section=about',
      );
      expect(
        webSettingsRedirect(Uri.parse('/settings/privacy/blocked-users')),
        isNull,
      );
      expect(
        webSettingsRedirect(Uri.parse('/main/settings?section=appearance')),
        isNull,
      );
    },
  );
}
