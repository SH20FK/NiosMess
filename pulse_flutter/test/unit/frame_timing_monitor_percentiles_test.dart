import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/performance/frame_timing_monitor.dart';

void main() {
  group('FrameTimingMonitor O(1) Circular Ring Buffer & Percentiles', () {
    late FrameTimingMonitor monitor;
    const double budget60Hz = 16.67;

    setUp(() {
      monitor = FrameTimingMonitor(capacity: 10);
    });

    test('O(1) buffer accurately stores and wraps around capacity', () {
      expect(monitor.sampleCount, equals(0));
      expect(monitor.currentMetrics, isEmpty);

      // Record 5 frames
      for (int i = 1; i <= 5; i++) {
        monitor.recordMetric(
          FrameMetric(
            buildDurationMs: i * 2.0,
            rasterDurationMs: i * 1.5,
            totalSpanMs: i * 3.0,
          ),
          budget60Hz,
        );
      }

      expect(monitor.sampleCount, equals(5));
      expect(monitor.currentMetrics.length, equals(5));
      expect(monitor.currentMetrics.first.buildDurationMs, equals(2.0));
      expect(monitor.currentMetrics.last.buildDurationMs, equals(10.0));

      // Add 7 more frames to overflow capacity (total 12 recorded, capacity is 10)
      for (int i = 6; i <= 12; i++) {
        monitor.recordMetric(
          FrameMetric(
            buildDurationMs: i * 2.0,
            rasterDurationMs: i * 1.5,
            totalSpanMs: i * 3.0,
          ),
          budget60Hz,
        );
      }

      // Sample count should be clamped to capacity
      expect(monitor.sampleCount, equals(10));
      final metrics = monitor.currentMetrics;
      expect(metrics.length, equals(10));
      // First element should now be frame 3 (value: 3 * 2 = 6.0)
      expect(metrics.first.buildDurationMs, equals(6.0));
      // Last element should be frame 12 (value: 12 * 2 = 24.0)
      expect(metrics.last.buildDurationMs, equals(24.0));
    });

    test('Percentile interpolation algorithm is mathematically accurate', () {
      final List<double> values = <double>[10.0, 20.0, 30.0, 40.0, 50.0];
      // p50 (median) of [10, 20, 30, 40, 50] is 30.0
      expect(FrameTimingMonitor.computePercentile(values, 0.50), closeTo(30.0, 0.001));
      // p0 is 10.0, p1.0 is 50.0
      expect(FrameTimingMonitor.computePercentile(values, 0.0), equals(10.0));
      expect(FrameTimingMonitor.computePercentile(values, 1.0), equals(50.0));
      // p90: rank = 0.9 * 4 = 3.6 -> values[3] + 0.6 * (values[4] - values[3]) = 40 + 0.6 * 10 = 46.0
      expect(FrameTimingMonitor.computePercentile(values, 0.90), closeTo(46.0, 0.001));
    });

    test('Percentiles and UI vs Raster jank tracking under load', () {
      final monitor100 = FrameTimingMonitor(capacity: 100);

      // Record 80 smooth frames (build 4ms, raster 5ms)
      for (int i = 0; i < 80; i++) {
        monitor100.recordMetric(
          const FrameMetric(
            buildDurationMs: 4.0,
            rasterDurationMs: 5.0,
            totalSpanMs: 8.0,
          ),
          budget60Hz,
        );
      }

      // Record 15 UI-heavy frames (build 22ms > 16.67, raster 6ms)
      for (int i = 0; i < 15; i++) {
        monitor100.recordMetric(
          const FrameMetric(
            buildDurationMs: 22.0,
            rasterDurationMs: 6.0,
            totalSpanMs: 24.0,
          ),
          budget60Hz,
        );
      }

      // Record 5 Raster-heavy frames (build 5ms, raster 28ms > 16.67)
      for (int i = 0; i < 5; i++) {
        monitor100.recordMetric(
          const FrameMetric(
            buildDurationMs: 5.0,
            rasterDurationMs: 28.0,
            totalSpanMs: 30.0,
          ),
          budget60Hz,
        );
      }

      expect(monitor100.sampleCount, equals(100));
      expect(monitor100.getUiJankFrames(budget60Hz), equals(15));
      expect(monitor100.getRasterJankFrames(budget60Hz), equals(5));

      // Percentiles:
      // Build p50 should be 4.0ms, p90 should be near 22.0ms
      expect(monitor100.p50BuildMs, equals(4.0));
      expect(monitor100.p90BuildMs, closeTo(22.0, 2.0));
      expect(monitor100.p99BuildMs, closeTo(22.0, 2.0));

      // Raster p50 should be 5.0ms or 6.0ms, p99 should be 28.0ms
      expect(monitor100.p50RasterMs, closeTo(5.0, 1.0));
      expect(monitor100.p99RasterMs, closeTo(28.0, 1.0));

      final snapshot = monitor100.createSnapshot(
        refreshRate: 60.0,
        budgetMs: budget60Hz,
      );
      expect(snapshot.totalFramesSampled, equals(100));
      expect(snapshot.uiJankFrames, equals(15));
      expect(snapshot.rasterJankFrames, equals(5));
      expect(snapshot.p50BuildMs, equals(4.0));
      expect(snapshot.p99RasterMs, closeTo(28.0, 1.0));
    });

    test('reset() properly clears ring buffer, counters, and percentiles', () {
      for (int i = 0; i < 5; i++) {
        monitor.recordMetric(
          const FrameMetric(
            buildDurationMs: 25.0,
            rasterDurationMs: 30.0,
            totalSpanMs: 35.0,
          ),
          budget60Hz,
        );
      }

      expect(monitor.sampleCount, equals(5));
      monitor.reset();

      expect(monitor.sampleCount, equals(0));
      expect(monitor.currentMetrics, isEmpty);
      expect(monitor.p50BuildMs, equals(0.0));
      expect(monitor.p99RasterMs, equals(0.0));
      expect(monitor.getUiJankFrames(budget60Hz), equals(0));
    });
  });
}
