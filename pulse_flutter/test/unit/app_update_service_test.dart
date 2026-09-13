import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/services/update/app_update_service.dart';

void main() {
  group('AppUpdateService SemVer Tests', () {
    test('detects newer patch version', () {
      expect(AppUpdateService.isNewerVersion('3.36.2', '3.36.1'), isTrue);
      expect(AppUpdateService.isNewerVersion('3.36.1', '3.36.2'), isFalse);
    });

    test('detects newer minor version', () {
      expect(AppUpdateService.isNewerVersion('3.37.0', '3.36.1'), isTrue);
      expect(AppUpdateService.isNewerVersion('3.36.1', '3.37.0'), isFalse);
    });

    test('detects newer major version', () {
      expect(AppUpdateService.isNewerVersion('4.0.0', '3.36.1'), isTrue);
      expect(AppUpdateService.isNewerVersion('3.36.1', '4.0.0'), isFalse);
    });

    test('handles leading v prefix', () {
      expect(AppUpdateService.isNewerVersion('v3.37.0', '3.36.1'), isTrue);
      expect(AppUpdateService.isNewerVersion('v3.36.1', 'v3.36.1'), isFalse);
      expect(AppUpdateService.isNewerVersion('3.36.0', 'v3.36.1'), isFalse);
    });

    test('handles build numbers when base versions are identical', () {
      expect(AppUpdateService.isNewerVersion('3.36.1+86', '3.36.1+85'), isTrue);
      expect(AppUpdateService.isNewerVersion('3.36.1+85', '3.36.1+86'), isFalse);
      expect(AppUpdateService.isNewerVersion('3.36.1+85', '3.36.1+85'), isFalse);
    });

    test('equal versions return false', () {
      expect(AppUpdateService.isNewerVersion('3.36.1', '3.36.1'), isFalse);
    });

    test('handles empty or malformed strings gracefully', () {
      expect(AppUpdateService.isNewerVersion('', '3.36.1'), isFalse);
      expect(AppUpdateService.isNewerVersion('invalid', '3.36.1'), isFalse);
    });
  });
}
