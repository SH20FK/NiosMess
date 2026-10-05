import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/features/settings/application/settings_registry.dart';

void main() {
  group('SettingsRegistry', () {
    test('setting ids and route anchors are unique', () {
      expect(() => validateSettingsRegistry(SettingsRegistry.all), returnsNormally);
    });

    test('all destinations have non-empty keywords and anchors', () {
      for (final dest in SettingsRegistry.all) {
        expect(dest.anchor, isNotEmpty);
        expect(dest.route, isNotEmpty);
        expect(dest.id.value, isNotEmpty);
      }
    });
  });
}
