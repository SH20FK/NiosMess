import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/services/update/app_update_service.dart';

void main() {
  group('AppUpdateService.isNewerVersion tests', () {
    test('detects major version bump', () {
      expect(AppUpdateService.isNewerVersion('4.0.0', '3.47.0'), isTrue);
      expect(AppUpdateService.isNewerVersion('3.0.0', '4.0.0'), isFalse);
    });

    test('detects minor version bump', () {
      expect(AppUpdateService.isNewerVersion('3.49.0', '3.47.0'), isTrue);
      expect(AppUpdateService.isNewerVersion('3.45.0', '3.47.0'), isFalse);
    });

    test('detects patch version bump', () {
      expect(AppUpdateService.isNewerVersion('3.47.1', '3.47.0'), isTrue);
      expect(AppUpdateService.isNewerVersion('3.47.0', '3.47.1'), isFalse);
    });

    test('detects build number bump with equal semver', () {
      expect(
        AppUpdateService.isNewerVersion('3.47.0+102', '3.47.0+98'),
        isTrue,
      );
      expect(
        AppUpdateService.isNewerVersion('3.47.0+98', '3.47.0+102'),
        isFalse,
      );
    });

    test('returns false for identical versions', () {
      expect(AppUpdateService.isNewerVersion('3.47.0', '3.47.0'), isFalse);
      expect(
        AppUpdateService.isNewerVersion('3.47.0+98', '3.47.0+98'),
        isFalse,
      );
    });

    test('handles v-prefix cleanly', () {
      expect(AppUpdateService.isNewerVersion('v3.49.1', '3.47.0'), isTrue);
      expect(AppUpdateService.isNewerVersion('V3.49.1+102', '3.47.0+98'), isTrue);
    });

    test('handles build number on latest with no build on current', () {
      expect(AppUpdateService.isNewerVersion('3.47.0+1', '3.47.0'), isTrue);
    });
  });

  group('AppUpdateService.parseChangelog tests', () {
    const String sampleChangelog = '''
# Changelog

## [3.58.1]
• Feature A
• Feature B

## [3.58.0]
• Older Feature C
''';

    test('extracts specific version cleanly', () {
      final String notes =
          AppUpdateService.parseChangelog(sampleChangelog, '3.58.1+122');
      expect(notes, contains('Feature A'));
      expect(notes, contains('Feature B'));
      expect(notes, isNot(contains('Older Feature C')));
    });

    test('fallbacks to first section if target version not found', () {
      final String notes =
          AppUpdateService.parseChangelog(sampleChangelog, '3.99.0');
      expect(notes, contains('Feature A'));
      expect(notes, isNot(contains('Older Feature C')));
    });

    test('returns empty for blank input', () {
      final String notes = AppUpdateService.parseChangelog('', '3.58.1');
      expect(notes, isEmpty);
    });

    test('returns raw input as-is when no headers present', () {
      const String plain = '• Simple bullet 1\n• Simple bullet 2';
      final String notes = AppUpdateService.parseChangelog(plain, '3.58.1');
      expect(notes, equals(plain));
    });
  });
}
