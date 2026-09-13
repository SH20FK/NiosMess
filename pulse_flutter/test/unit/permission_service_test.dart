import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/services/permission_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PermissionService tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('singleton instance is consistent', () {
      final PermissionService service1 = PermissionService();
      final PermissionService service2 = PermissionService();
      expect(identical(service1, service2), isTrue);
    });

    test('initialPermissionsRequestedKey is defined', () {
      expect(
        PermissionService.initialPermissionsRequestedKey,
        'has_requested_initial_permissions',
      );
    });

    test('requestInitialPermissionsIfNeeded sets requested flag in SharedPreferences', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final PermissionService service = PermissionService();

      final SharedPreferences prefsBefore = await SharedPreferences.getInstance();
      expect(
        prefsBefore.getBool(PermissionService.initialPermissionsRequestedKey),
        isNull,
      );

      await service.requestInitialPermissionsIfNeeded();

      final SharedPreferences prefsAfter = await SharedPreferences.getInstance();
      expect(
        prefsAfter.getBool(PermissionService.initialPermissionsRequestedKey),
        isTrue,
      );
    });

    test('requestInitialPermissionsIfNeeded is idempotent when already requested', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PermissionService.initialPermissionsRequestedKey: true,
      });
      final PermissionService service = PermissionService();

      await service.requestInitialPermissionsIfNeeded();

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(PermissionService.initialPermissionsRequestedKey),
        isTrue,
      );
    });
  });
}
