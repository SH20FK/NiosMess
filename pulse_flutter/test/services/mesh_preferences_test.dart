import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulse_flutter/services/bluetooth_mesh/mesh_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Persisted Bluetooth preference', () {
    test('startup waits for a saved disabled value', () async {
      SharedPreferences.setMockInitialValues({MeshPreference.key: false});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(meshPreferenceProvider);
      final preference = container.read(meshPreferenceProvider.notifier);
      expect(preference.hydrated, isFalse);
      await preference.loaded;
      expect(preference.hydrated, isTrue);
      expect(container.read(meshPreferenceProvider), isFalse);
    });
    test(
      'new installations are enabled after settings finish loading',
      () async {
        SharedPreferences.setMockInitialValues({});
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final preference = container.read(meshPreferenceProvider.notifier);
        await preference.loaded;
        expect(preference.hydrated, isTrue);
        expect(container.read(meshPreferenceProvider), isTrue);
      },
    );
    test('a user change wins over an in-flight startup read', () async {
      SharedPreferences.setMockInitialValues({MeshPreference.key: true});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final preference = container.read(meshPreferenceProvider.notifier);
      await preference.setEnabled(false);
      await preference.loaded;
      expect(container.read(meshPreferenceProvider), isFalse);
      expect(
        (await SharedPreferences.getInstance()).getBool(MeshPreference.key),
        isFalse,
      );
    });
  });
}
