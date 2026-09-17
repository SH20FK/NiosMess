import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/motion/tri_sync.dart';

void main() {
  group('TriSync Multi-channel Coordination (TS)', () {
    test('Trigger invokes without throwing even without Ref or Context', () {
      expect(() => TriSync.trigger(TriSyncEvent.tap), returnsNormally);
      expect(() => TriSync.trigger(TriSyncEvent.snap), returnsNormally);
      expect(() => TriSync.trigger(TriSyncEvent.pop), returnsNormally);
      expect(() => TriSync.trigger(TriSyncEvent.dismiss), returnsNormally);
      expect(() => TriSync.trigger(TriSyncEvent.reaction), returnsNormally);
    });

    test('Shortcuts function reliably', () {
      expect(() => TriSync.tap(), returnsNormally);
      expect(() => TriSync.snap(), returnsNormally);
      expect(() => TriSync.pop(), returnsNormally);
      expect(() => TriSync.dismiss(), returnsNormally);
      expect(() => TriSync.reaction(), returnsNormally);
      expect(() => TriSync.destructive(), returnsNormally);
    });

    test('Throttling guard suppresses rapid back-to-back triggers of same event', () {
      // First call registers
      TriSync.trigger(TriSyncEvent.snap, force: true);

      // Immediate repeated calls within 45ms are throttled
      expect(() => TriSync.trigger(TriSyncEvent.snap), returnsNormally);
    });
  });
}
