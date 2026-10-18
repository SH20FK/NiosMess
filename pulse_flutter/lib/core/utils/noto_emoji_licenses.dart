import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool _registered = false;

/// Notices load only when the user opens Settings > Third-party licenses.
void registerNotoEmojiLicenses() {
  if (_registered) return;
  _registered = true;
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'Google Noto Color Emoji',
    ], await rootBundle.loadString('assets/licenses/noto-emoji-font.txt'));
    yield LicenseEntryWithLineBreaks(const [
      'Google Animated Noto Emoji',
    ], await rootBundle.loadString('assets/licenses/noto-emoji-animation.txt'));
    yield LicenseEntryWithLineBreaks(const [
      'Google Noto Emoji metadata',
    ], await rootBundle.loadString('assets/licenses/noto-emoji-metadata.txt'));
  });
}
