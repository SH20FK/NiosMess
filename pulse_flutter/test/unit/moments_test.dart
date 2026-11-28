import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/motion/tri_sync.dart';

void main() {
  group('Phase 4: Moments motion', () {
    test('MOM-1 / MOM-5 / MOM-6 Normalized M3 Springs satisfy boundary invariant', () {
      expect(M3SpringCurves.spatialFast.transform(0.0), closeTo(0.0, 1e-6));
      expect(M3SpringCurves.spatialFast.transform(1.0), closeTo(1.0, 1e-6));

      expect(M3SpringCurves.spatialDefault.transform(0.0), closeTo(0.0, 1e-6));
      expect(M3SpringCurves.spatialDefault.transform(1.0), closeTo(1.0, 1e-6));

      expect(M3SpringCurves.spatialSlow.transform(0.0), closeTo(0.0, 1e-6));
      expect(M3SpringCurves.spatialSlow.transform(1.0), closeTo(1.0, 1e-6));

      expect(M3SpringCurves.effectsDefault.transform(0.0), closeTo(0.0, 1e-6));
      expect(M3SpringCurves.effectsDefault.transform(1.0), closeTo(1.0, 1e-6));
    });

    test('TriSync reaction and pop triggers execute cleanly', () {
      expect(() => TriSync.reaction(), returnsNormally);
      expect(() => TriSync.pop(), returnsNormally);
    });
  });
}
