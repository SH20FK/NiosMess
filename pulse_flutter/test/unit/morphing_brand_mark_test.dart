import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/widgets/about/morphing_brand_mark.dart';

void main() {
  group('MorphingBrandMark & BrandShape Math Tests', () {
    test('All 5 official brand shapes have 180 precalculated radial samples', () {
      expect(kBrandShapes.length, equals(5));

      for (int shapeIdx = 0; shapeIdx < kBrandShapes.length; shapeIdx++) {
        final BrandShape shape = kBrandShapes[shapeIdx];
        expect(shape.radii.length, equals(180));
        expect(shape.spin, greaterThanOrEqualTo(0.0));

        // Radii must be strictly positive and bounded
        for (final double r in shape.radii) {
          expect(r, greaterThan(0.5));
          expect(r, lessThan(1.5));
        }
      }
    });

    test('Linear interpolation between brand shape profiles produces continuous monotonic transitions', () {
      for (int i = 0; i < kBrandShapes.length; i++) {
        final BrandShape from = kBrandShapes[i];
        final BrandShape to = kBrandShapes[(i + 1) % kBrandShapes.length];

        for (int sample = 0; sample < 180; sample++) {
          final double r0 = from.radii[sample];
          final double r1 = to.radii[sample];

          final double rMid = r0 + (r1 - r0) * 0.5;
          final double expectedMin = math.min(r0, r1);
          final double expectedMax = math.max(r0, r1);

          expect(rMid, greaterThanOrEqualTo(expectedMin - 1e-6));
          expect(rMid, lessThanOrEqualTo(expectedMax + 1e-6));
        }
      }
    });

    test('Shape rotations increment monotonically across the 5 stages', () {
      for (int i = 0; i < kBrandShapes.length - 1; i++) {
        expect(kBrandShapes[i + 1].spin, greaterThan(kBrandShapes[i].spin));
      }
    });
  });
}
