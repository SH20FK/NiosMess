import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/features/security/domain/app_lock_policy.dart';

void main() {
  group('AppLockTimeout', () {
    test('durations are accurate', () {
      expect(AppLockTimeout.immediately.duration, Duration.zero);
      expect(AppLockTimeout.after30Seconds.duration, const Duration(seconds: 30));
      expect(AppLockTimeout.after1Minute.duration, const Duration(minutes: 1));
      expect(AppLockTimeout.after5Minutes.duration, const Duration(minutes: 5));
      expect(AppLockTimeout.after30Minutes.duration, const Duration(minutes: 30));
    });

    test('fromString parses correctly or falls back to immediately', () {
      expect(AppLockTimeout.fromString('immediately'), AppLockTimeout.immediately);
      expect(AppLockTimeout.fromString('after30Seconds'), AppLockTimeout.after30Seconds);
      expect(AppLockTimeout.fromString('after1Minute'), AppLockTimeout.after1Minute);
      expect(AppLockTimeout.fromString('after5Minutes'), AppLockTimeout.after5Minutes);
      expect(AppLockTimeout.fromString('after30Minutes'), AppLockTimeout.after30Minutes);
      expect(AppLockTimeout.fromString('invalid'), AppLockTimeout.immediately);
      expect(AppLockTimeout.fromString(null), AppLockTimeout.immediately);
    });

    test('labels are non-empty', () {
      for (final AppLockTimeout t in AppLockTimeout.values) {
        expect(t.labelRu.isNotEmpty, isTrue);
        expect(t.labelEn.isNotEmpty, isTrue);
      }
    });
  });

  group('AppLockState', () {
    test('default state is unlocked and unconfigured', () {
      const AppLockState state = AppLockState();
      expect(state.isEnabled, isFalse);
      expect(state.isLocked, isFalse);
      expect(state.isSupported, isTrue);
      expect(state.timeout, AppLockTimeout.immediately);
      expect(state.lastBackgroundedAt, isNull);
    });

    test('copyWith updates fields correctly', () {
      const AppLockState initial = AppLockState();
      final DateTime now = DateTime.now();
      final AppLockState updated = initial.copyWith(
        isEnabled: true,
        isLocked: true,
        timeout: AppLockTimeout.after1Minute,
        lastBackgroundedAt: now,
      );

      expect(updated.isEnabled, isTrue);
      expect(updated.isLocked, isTrue);
      expect(updated.timeout, AppLockTimeout.after1Minute);
      expect(updated.lastBackgroundedAt, now);

      final AppLockState cleared = updated.copyWith(clearLastBackgroundedAt: true);
      expect(cleared.lastBackgroundedAt, isNull);
    });
  });
}
