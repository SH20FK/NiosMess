import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool _registered = false;

/// The prebuilt OpenMLS library links Rust/C dependencies. Their upstream
/// notices ship with the app and load lazily when the user opens licenses.
void registerNiosProtocolLicenses() {
  if (_registered) return;
  _registered = true;
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'OpenMLS native dependencies',
    ], await rootBundle.loadString('assets/licenses/openmls-notices.txt'));
  });
}
