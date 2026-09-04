import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';
import 'package:pulse_flutter/core/performance/frame_timing_monitor.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('F1: Refresh Rate & Target Frame Budget Tests', () {
    test('computeBudgetMs and computeTargetFps for 120Hz flagship', () {
      expect(FrameTimingMonitor.computeBudgetMs(120.0), closeTo(8.33, 0.01));
      expect(FrameTimingMonitor.computeTargetFps(120.0), equals(120.0));
    });

    test('computeBudgetMs and computeTargetFps for 90Hz smooth display', () {
      expect(FrameTimingMonitor.computeBudgetMs(90.0), closeTo(11.11, 0.01));
      expect(FrameTimingMonitor.computeTargetFps(90.0), equals(90.0));
    });

    test('computeBudgetMs and computeTargetFps for standard 60Hz display', () {
      expect(FrameTimingMonitor.computeBudgetMs(60.0), closeTo(16.67, 0.01));
      expect(FrameTimingMonitor.computeTargetFps(60.0), equals(60.0));
    });

    test('FrameMetric jank classification against budget', () {
      const budget = 16.67;

      // Smooth frame (12ms build, 10ms raster)
      const smooth = FrameMetric(
        buildDurationMs: 12.0,
        rasterDurationMs: 10.0,
        totalSpanMs: 14.0,
      );
      expect(smooth.effectiveDurationMs, equals(12.0));
      expect(smooth.isJanky(budget), isFalse);
      expect(smooth.isSevereJanky(budget), isFalse);

      // Mild jank (18ms raster > 16.67ms, but <= 16.67 * 1.8 = 30.0)
      const mildJank = FrameMetric(
        buildDurationMs: 8.0,
        rasterDurationMs: 18.0,
        totalSpanMs: 20.0,
      );
      expect(mildJank.effectiveDurationMs, equals(18.0));
      expect(mildJank.isJanky(budget), isTrue);
      expect(mildJank.isSevereJanky(budget), isFalse);

      // Severe jank (35ms build > 30.0ms)
      const severeJank = FrameMetric(
        buildDurationMs: 35.0,
        rasterDurationMs: 12.0,
        totalSpanMs: 38.0,
      );
      expect(severeJank.effectiveDurationMs, equals(35.0));
      expect(severeJank.isJanky(budget), isTrue);
      expect(severeJank.isSevereJanky(budget), isTrue);
    });
  });

  group('F2 & F3: Anti-Flapping Hysteresis Engine Tests', () {
    late DateTime simulatedNow;
    late FrameTimingMonitor monitor;

    setUp(() {
      simulatedNow = DateTime(2026, 9, 4, 12, 0, 0);
      monitor = FrameTimingMonitor(
        capacity: 60,
        nowProvider: () => simulatedNow,
      );
    });

    test('1 or 2 isolated dropped frames do NOT trigger degradation', () {
      const budget = 16.67;

      // Feed 20 smooth frames
      for (int i = 0; i < 20; i++) {
        monitor.recordMetric(
          const FrameMetric(
            buildDurationMs: 10.0,
            rasterDurationMs: 8.0,
            totalSpanMs: 12.0,
          ),
          budget,
        );
      }

      // 2 isolated severe dropped frames
      monitor.recordMetric(
        const FrameMetric(
          buildDurationMs: 35.0,
          rasterDurationMs: 32.0,
          totalSpanMs: 40.0,
        ),
        budget,
      );
      monitor.recordMetric(
        const FrameMetric(
          buildDurationMs: 36.0,
          rasterDurationMs: 31.0,
          totalSpanMs: 42.0,
        ),
        budget,
      );

      // 2 frames is below threshold of 4 consecutive drops, and 2/12 = 16.6% but consecutive is 2
      // Next frame is smooth:
      monitor.recordMetric(
        const FrameMetric(
          buildDurationMs: 10.0,
          rasterDurationMs: 8.0,
          totalSpanMs: 12.0,
        ),
        budget,
      );

      // Severe consecutive count was reset by smooth frame
      expect(monitor.consecutiveSevereJankFrames, equals(0));
      expect(monitor.shouldDegrade(budgetMs: budget), isFalse);
    });

    test('4 consecutive severe drops trigger degradation and set 8-second cooldown', () {
      const budget = 16.67;

      // 4 consecutive severe dropped frames
      for (int i = 0; i < 4; i++) {
        monitor.recordMetric(
          const FrameMetric(
            buildDurationMs: 40.0,
            rasterDurationMs: 35.0,
            totalSpanMs: 45.0,
          ),
          budget,
        );
      }

      expect(monitor.consecutiveSevereJankFrames, equals(4));
      expect(monitor.shouldDegrade(budgetMs: budget), isTrue);

      // Mark degraded at simulatedNow
      monitor.markDegraded(currentTime: simulatedNow);

      expect(
        monitor.downgradeCooldownUntil,
        equals(simulatedNow.add(const Duration(seconds: 8))),
      );
      expect(monitor.consecutiveSmoothFrames, equals(0));

      // Attempt upgrade before 8 seconds expire — must be rejected
      simulatedNow = simulatedNow.add(const Duration(seconds: 5));
      expect(
        monitor.shouldUpgrade(budgetMs: budget, currentTime: simulatedNow),
        isFalse,
      );
    });

    test('Jank ratio > 15% across window triggers degradation', () {
      const budget = 16.67;

      // Feed 45 smooth frames
      for (int i = 0; i < 45; i++) {
        monitor.recordMetric(
          const FrameMetric(
            buildDurationMs: 10.0,
            rasterDurationMs: 10.0,
            totalSpanMs: 12.0,
          ),
          budget,
        );
      }

      // Feed 15 janky frames (15 / 60 = 25% > 15%)
      for (int i = 0; i < 15; i++) {
        monitor.recordMetric(
          const FrameMetric(
            buildDurationMs: 20.0,
            rasterDurationMs: 10.0,
            totalSpanMs: 22.0,
          ),
          budget,
        );
      }

      expect(monitor.sampleCount, equals(60));
      expect(monitor.getJankRatio(budget), closeTo(0.25, 0.01));
      expect(monitor.shouldDegrade(budgetMs: budget), isTrue);
    });

    test('Upgrade requires cooldown expiration AND 180 consecutive smooth frames', () {
      const budget = 16.67;

      // Trigger degradation
      monitor.markDegraded(currentTime: simulatedNow);

      // Advance time past 8-second cooldown (to +10s)
      simulatedNow = simulatedNow.add(const Duration(seconds: 10));

      // Feed only 100 smooth frames (< 180 threshold)
      for (int i = 0; i < 100; i++) {
        monitor.recordMetric(
          const FrameMetric(
            buildDurationMs: 8.0,
            rasterDurationMs: 8.0,
            totalSpanMs: 10.0,
          ),
          budget,
        );
      }
      expect(monitor.consecutiveSmoothFrames, equals(100));
      expect(
        monitor.shouldUpgrade(budgetMs: budget, currentTime: simulatedNow),
        isFalse,
      );

      // Feed 80 more smooth frames (100 + 80 = 180)
      for (int i = 0; i < 80; i++) {
        monitor.recordMetric(
          const FrameMetric(
            buildDurationMs: 8.0,
            rasterDurationMs: 8.0,
            totalSpanMs: 10.0,
          ),
          budget,
        );
      }
      expect(monitor.consecutiveSmoothFrames, equals(180));
      expect(monitor.getJankRatio(budget), equals(0.0));
      expect(
        monitor.shouldUpgrade(budgetMs: budget, currentTime: simulatedNow),
        isTrue,
      );
    });

    test('Ring buffer evicts oldest frame when reaching capacity 60', () {
      const budget = 16.67;

      for (int i = 0; i < 60; i++) {
        monitor.recordMetric(
          const FrameMetric(
            buildDurationMs: 10.0,
            rasterDurationMs: 10.0,
            totalSpanMs: 12.0,
          ),
          budget,
        );
      }
      expect(monitor.sampleCount, equals(60));

      // Add one more
      monitor.recordMetric(
        const FrameMetric(
          buildDurationMs: 12.0,
          rasterDurationMs: 12.0,
          totalSpanMs: 15.0,
        ),
        budget,
      );
      expect(monitor.sampleCount, equals(60));
    });
  });

  group('F2: Riverpod AdaptivePerformanceProvider State Tests', () {
    test('Default state initializes with balanced or flagship mode', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(adaptivePerformanceProvider);
      expect(state.targetFps, inInclusiveRange(60.0, 120.0));
      expect(state.targetFrameBudgetMs, inInclusiveRange(8.0, 17.0));
      expect(
        state.mode,
        anyOf(
          equals(PerformanceMode.flagship),
          equals(PerformanceMode.balanced),
          equals(PerformanceMode.powerSaver),
        ),
      );
    });

    test('Manual optimizeForWeakDevices override forces powerSaver tier', () {
      final container = ProviderContainer(
        overrides: [
          uiSettingsProvider.overrideWith(() => _WeakDeviceUiSettingsNotifier()),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(adaptivePerformanceProvider);
      expect(state.mode, equals(PerformanceMode.powerSaver));
      expect(state.tier, equals(PerformanceTier.tierC));
      expect(state.isDegraded, isTrue);
    });

    test('State transitions from flagship to balanced and powerSaver on degradation', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(adaptivePerformanceProvider.notifier);
      notifier.setMode(PerformanceMode.flagship);

      var state = container.read(adaptivePerformanceProvider);
      expect(state.mode, equals(PerformanceMode.flagship));
      expect(state.tier, equals(PerformanceTier.tierA));

      // Simulate 4 severe drops
      for (int i = 0; i < 4; i++) {
        notifier.recordMetric(
          const FrameMetric(
            buildDurationMs: 40.0,
            rasterDurationMs: 40.0,
            totalSpanMs: 50.0,
          ),
        );
      }

      state = container.read(adaptivePerformanceProvider);
      expect(state.mode, equals(PerformanceMode.balanced));
      expect(state.tier, equals(PerformanceTier.tierB));
      expect(state.isDegraded, isTrue);

      // Simulate 4 more severe drops
      for (int i = 0; i < 4; i++) {
        notifier.recordMetric(
          const FrameMetric(
            buildDurationMs: 40.0,
            rasterDurationMs: 40.0,
            totalSpanMs: 50.0,
          ),
        );
      }

      state = container.read(adaptivePerformanceProvider);
      expect(state.mode, equals(PerformanceMode.powerSaver));
      expect(state.tier, equals(PerformanceTier.tierC));
      expect(state.isDegraded, isTrue);
    });

    test('State upgrades back after smooth frames and cooldown expiration', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(adaptivePerformanceProvider.notifier);
      notifier.setMode(PerformanceMode.powerSaver);

      var now = DateTime(2026, 9, 4, 14, 0, 0);
      notifier.monitor.markDegraded(currentTime: now);

      // Advance time by 10s (past 8s cooldown)
      now = now.add(const Duration(seconds: 10));

      // Feed 180 smooth frames
      for (int i = 0; i < 180; i++) {
        notifier.recordMetric(
          const FrameMetric(
            buildDurationMs: 6.0,
            rasterDurationMs: 6.0,
            totalSpanMs: 8.0,
          ),
          currentTime: now,
        );
      }

      final state = container.read(adaptivePerformanceProvider);
      expect(state.mode, equals(PerformanceMode.balanced));
      expect(state.tier, equals(PerformanceTier.tierB));
      expect(state.isDegraded, isFalse);
    });
  });
}

class _WeakDeviceUiSettingsNotifier extends UiSettingsNotifier {
  @override
  UiSettingsState build() {
    return const UiSettingsState.defaults().copyWith(
      optimizeForWeakDevices: true,
    );
  }
}
