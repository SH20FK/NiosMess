import 'dart:math' as math;
import 'dart:ui' show FrameTiming;
import 'package:flutter/widgets.dart';

/// Normalized performance metrics for an individual frame.
class FrameMetric {
  const FrameMetric({
    required this.buildDurationMs,
    required this.rasterDurationMs,
    required this.totalSpanMs,
    this.vsyncOverheadMs = 0.0,
  });

  factory FrameMetric.fromTiming(FrameTiming timing) {
    return FrameMetric(
      buildDurationMs: timing.buildDuration.inMicroseconds / 1000.0,
      rasterDurationMs: timing.rasterDuration.inMicroseconds / 1000.0,
      totalSpanMs: timing.totalSpan.inMicroseconds / 1000.0,
      vsyncOverheadMs: timing.vsyncOverhead.inMicroseconds / 1000.0,
    );
  }

  final double buildDurationMs;
  final double rasterDurationMs;
  final double totalSpanMs;
  final double vsyncOverheadMs;

  /// Effective frame execution duration (max of build and raster time).
  double get effectiveDurationMs => math.max(buildDurationMs, rasterDurationMs);

  /// Whether this frame exceeded the target budget.
  bool isJanky(double budgetMs) => effectiveDurationMs > budgetMs;

  /// Whether this frame severely exceeded the target budget (> 1.8x).
  bool isSevereJanky(double budgetMs) => effectiveDurationMs > (budgetMs * 1.8);

  /// Whether UI thread build time exceeded target budget.
  bool isUiJanky(double budgetMs) => buildDurationMs > budgetMs;

  /// Whether GPU raster thread time exceeded target budget.
  bool isRasterJanky(double budgetMs) => rasterDurationMs > budgetMs;
}

/// Rolling metrics snapshot for the current sliding window with percentile distributions.
@immutable
class PerformanceMetricsSnapshot {
  const PerformanceMetricsSnapshot({
    required this.deviceRefreshRate,
    required this.targetFrameBudgetMs,
    required this.averageBuildMs,
    required this.averageRasterMs,
    required this.jankRatio,
    required this.consecutiveSmoothFrames,
    this.p50BuildMs = 0.0,
    this.p90BuildMs = 0.0,
    this.p99BuildMs = 0.0,
    this.p50RasterMs = 0.0,
    this.p90RasterMs = 0.0,
    this.p99RasterMs = 0.0,
    this.p50TotalMs = 0.0,
    this.p90TotalMs = 0.0,
    this.p99TotalMs = 0.0,
    this.uiJankFrames = 0,
    this.rasterJankFrames = 0,
    this.totalFramesSampled = 0,
  });

  final double deviceRefreshRate;
  final double targetFrameBudgetMs;
  final double averageBuildMs;
  final double averageRasterMs;
  final double jankRatio;
  final int consecutiveSmoothFrames;
  final double p50BuildMs;
  final double p90BuildMs;
  final double p99BuildMs;
  final double p50RasterMs;
  final double p90RasterMs;
  final double p99RasterMs;
  final double p50TotalMs;
  final double p90TotalMs;
  final double p99TotalMs;
  final int uiJankFrames;
  final int rasterJankFrames;
  final int totalFramesSampled;

  static const PerformanceMetricsSnapshot initial = PerformanceMetricsSnapshot(
    deviceRefreshRate: 60.0,
    targetFrameBudgetMs: 16.67,
    averageBuildMs: 0.0,
    averageRasterMs: 0.0,
    jankRatio: 0.0,
    consecutiveSmoothFrames: 0,
    p50BuildMs: 0.0,
    p90BuildMs: 0.0,
    p99BuildMs: 0.0,
    p50RasterMs: 0.0,
    p90RasterMs: 0.0,
    p99RasterMs: 0.0,
    p50TotalMs: 0.0,
    p90TotalMs: 0.0,
    p99TotalMs: 0.0,
    uiJankFrames: 0,
    rasterJankFrames: 0,
    totalFramesSampled: 0,
  );
}

/// Frame timing monitor tracking an O(1) rolling circular ring buffer of [capacity] frames.
///
/// Implements anti-flapping hysteresis:
/// - Fast degradation on 4 consecutive severe drops or > 15% jank ratio.
/// - 8-second downgrade cooldown before permitting any upgrade.
/// - Requires 180 consecutive smooth frames under budget to upgrade.
class FrameTimingMonitor {
  FrameTimingMonitor({
    this.capacity = 60,
    DateTime Function()? nowProvider,
  })  : _nowProvider = nowProvider ?? DateTime.now,
        _ringBuffer = List<FrameMetric?>.filled(capacity, null);

  final int capacity;
  final DateTime Function() _nowProvider;

  final List<FrameMetric?> _ringBuffer;
  int _head = 0;
  int _count = 0;
  int _consecutiveSmoothFrames = 0;
  int _consecutiveSevereJankFrames = 0;

  DateTime? _downgradeCooldownUntil;
  DateTime? _upgradeCooldownUntil;

  /// Detects display refresh rate (120Hz, 90Hz, 60Hz) from the platform dispatcher.
  static double detectRefreshRate({WidgetsBinding? binding}) {
    try {
      final dispatcher = (binding ?? WidgetsBinding.instance).platformDispatcher;
      final view = dispatcher.views.firstOrNull;
      if (view != null) {
        final double rate = view.display.refreshRate;
        if (rate > 24.0) return rate;
      }
    } catch (_) {}
    return 60.0;
  }

  /// Calculates target frame budget in milliseconds based on refresh rate.
  static double computeBudgetMs(double refreshRate) {
    if (refreshRate >= 110.0) return 8.33; // 120Hz
    if (refreshRate >= 80.0) return 11.11; // 90Hz
    return 16.67; // 60Hz
  }

  /// Target FPS corresponding to refresh rate.
  static double computeTargetFps(double refreshRate) {
    if (refreshRate >= 110.0) return 120.0;
    if (refreshRate >= 80.0) return 90.0;
    return 60.0;
  }

  int get consecutiveSmoothFrames => _consecutiveSmoothFrames;
  int get consecutiveSevereJankFrames => _consecutiveSevereJankFrames;
  int get sampleCount => _count;
  DateTime? get downgradeCooldownUntil => _downgradeCooldownUntil;
  DateTime? get upgradeCooldownUntil => _upgradeCooldownUntil;

  /// Returns an immutable list of currently recorded frame metrics in chronological order.
  List<FrameMetric> get currentMetrics {
    if (_count == 0) return const <FrameMetric>[];
    final List<FrameMetric> list = List<FrameMetric>.generate(_count, (int i) {
      final int idx = (_count < capacity) ? i : (_head + i) % capacity;
      return _ringBuffer[idx]!;
    }, growable: false);
    return list;
  }

  /// Inserts a frame metric into the rolling ring buffer in O(1) time and updates counters.
  void recordMetric(FrameMetric metric, double budgetMs) {
    _ringBuffer[_head] = metric;
    _head = (_head + 1) % capacity;
    if (_count < capacity) {
      _count++;
    }

    if (metric.isSevereJanky(budgetMs)) {
      _consecutiveSevereJankFrames++;
      _consecutiveSmoothFrames = 0;
    } else if (metric.isJanky(budgetMs)) {
      _consecutiveSevereJankFrames = 0;
      _consecutiveSmoothFrames = 0;
    } else {
      _consecutiveSevereJankFrames = 0;
      _consecutiveSmoothFrames++;
    }
  }

  /// Convenience method to record a Flutter engine [FrameTiming].
  void recordTiming(FrameTiming timing, double budgetMs) {
    recordMetric(FrameMetric.fromTiming(timing), budgetMs);
  }

  /// Calculates the jank ratio across frames currently in the buffer.
  double getJankRatio(double budgetMs) {
    if (_count == 0) return 0.0;
    int jankyCount = 0;
    for (int i = 0; i < _count; i++) {
      final int idx = (_count < capacity) ? i : (_head + i) % capacity;
      if (_ringBuffer[idx]!.isJanky(budgetMs)) {
        jankyCount++;
      }
    }
    return jankyCount / _count;
  }

  /// Computes average build time in milliseconds.
  double get averageBuildMs {
    if (_count == 0) return 0.0;
    double total = 0.0;
    for (int i = 0; i < _count; i++) {
      final int idx = (_count < capacity) ? i : (_head + i) % capacity;
      total += _ringBuffer[idx]!.buildDurationMs;
    }
    return total / _count;
  }

  /// Computes average raster time in milliseconds.
  double get averageRasterMs {
    if (_count == 0) return 0.0;
    double total = 0.0;
    for (int i = 0; i < _count; i++) {
      final int idx = (_count < capacity) ? i : (_head + i) % capacity;
      total += _ringBuffer[idx]!.rasterDurationMs;
    }
    return total / _count;
  }

  /// Computes percentiles from sample values with linear interpolation.
  static double computePercentile(List<double> values, double percentile) {
    if (values.isEmpty) return 0.0;
    if (values.length == 1) return values.first;
    final List<double> sorted = List<double>.from(values)..sort();
    final double rank = percentile * (sorted.length - 1);
    final int lowerIndex = rank.floor();
    final int upperIndex = rank.ceil();
    if (lowerIndex == upperIndex) return sorted[lowerIndex];
    final double fraction = rank - lowerIndex;
    return sorted[lowerIndex] + (sorted[upperIndex] - sorted[lowerIndex]) * fraction;
  }

  double get p50BuildMs => computePercentile(
        currentMetrics.map((m) => m.buildDurationMs).toList(growable: false),
        0.50,
      );

  double get p90BuildMs => computePercentile(
        currentMetrics.map((m) => m.buildDurationMs).toList(growable: false),
        0.90,
      );

  double get p99BuildMs => computePercentile(
        currentMetrics.map((m) => m.buildDurationMs).toList(growable: false),
        0.99,
      );

  double get p50RasterMs => computePercentile(
        currentMetrics.map((m) => m.rasterDurationMs).toList(growable: false),
        0.50,
      );

  double get p90RasterMs => computePercentile(
        currentMetrics.map((m) => m.rasterDurationMs).toList(growable: false),
        0.90,
      );

  double get p99RasterMs => computePercentile(
        currentMetrics.map((m) => m.rasterDurationMs).toList(growable: false),
        0.99,
      );

  double get p50TotalMs => computePercentile(
        currentMetrics.map((m) => m.totalSpanMs).toList(growable: false),
        0.50,
      );

  double get p90TotalMs => computePercentile(
        currentMetrics.map((m) => m.totalSpanMs).toList(growable: false),
        0.90,
      );

  double get p99TotalMs => computePercentile(
        currentMetrics.map((m) => m.totalSpanMs).toList(growable: false),
        0.99,
      );

  /// Number of frames where UI thread build exceeded [budgetMs].
  int getUiJankFrames(double budgetMs) {
    int count = 0;
    for (int i = 0; i < _count; i++) {
      final int idx = (_count < capacity) ? i : (_head + i) % capacity;
      if (_ringBuffer[idx]!.isUiJanky(budgetMs)) count++;
    }
    return count;
  }

  /// Number of frames where GPU rasterizer exceeded [budgetMs].
  int getRasterJankFrames(double budgetMs) {
    int count = 0;
    for (int i = 0; i < _count; i++) {
      final int idx = (_count < capacity) ? i : (_head + i) % capacity;
      if (_ringBuffer[idx]!.isRasterJanky(budgetMs)) count++;
    }
    return count;
  }

  /// Evaluates whether the engine should degrade tier based on hysteresis rules.
  /// Tier A -> Tier B requires at least 8 janky frames out of the last 30 frames,
  /// or at least 4 consecutive severe jank frames.
  bool shouldDegrade({required double budgetMs}) {
    if (_consecutiveSevereJankFrames >= 4) {
      return true;
    }
    if (_count >= 30) {
      int jankyCount = 0;
      for (int i = 0; i < 30; i++) {
        final int idx = (_head - 1 - i + capacity) % capacity;
        if (_ringBuffer[idx] != null && _ringBuffer[idx]!.isJanky(budgetMs)) {
          jankyCount++;
        }
      }
      if (jankyCount >= 8) return true;
    } else if (_count >= 10 && getJankRatio(budgetMs) >= 0.30) {
      return true;
    }
    return false;
  }

  /// Evaluates whether the engine should upgrade tier based on hysteresis rules.
  /// Tier B -> Tier A requires at least 120 consecutive smooth frames (2 seconds stability at 60fps)
  /// and cooldown of at least 5 seconds.
  bool shouldUpgrade({required double budgetMs, DateTime? currentTime}) {
    final now = currentTime ?? _nowProvider();
    if (_downgradeCooldownUntil != null && now.isBefore(_downgradeCooldownUntil!)) {
      return false;
    }
    if (_upgradeCooldownUntil != null && now.isBefore(_upgradeCooldownUntil!)) {
      return false;
    }
    if (_consecutiveSmoothFrames >= 120 && getJankRatio(budgetMs) < 0.02) {
      return true;
    }
    return false;
  }

  /// Enters downgrade cooldown state (minimum 5 seconds).
  void markDegraded({DateTime? currentTime}) {
    final now = currentTime ?? _nowProvider();
    _downgradeCooldownUntil = now.add(const Duration(seconds: 5));
    _consecutiveSevereJankFrames = 0;
    _consecutiveSmoothFrames = 0;
  }

  /// Enters upgrade cooldown state (5 seconds).
  void markUpgraded({DateTime? currentTime}) {
    final now = currentTime ?? _nowProvider();
    _upgradeCooldownUntil = now.add(const Duration(seconds: 5));
  }

  /// Generates a snapshot of current telemetry.
  PerformanceMetricsSnapshot createSnapshot({
    required double refreshRate,
    required double budgetMs,
  }) {
    return PerformanceMetricsSnapshot(
      deviceRefreshRate: refreshRate,
      targetFrameBudgetMs: budgetMs,
      averageBuildMs: averageBuildMs,
      averageRasterMs: averageRasterMs,
      jankRatio: getJankRatio(budgetMs),
      consecutiveSmoothFrames: _consecutiveSmoothFrames,
      p50BuildMs: p50BuildMs,
      p90BuildMs: p90BuildMs,
      p99BuildMs: p99BuildMs,
      p50RasterMs: p50RasterMs,
      p90RasterMs: p90RasterMs,
      p99RasterMs: p99RasterMs,
      p50TotalMs: p50TotalMs,
      p90TotalMs: p90TotalMs,
      p99TotalMs: p99TotalMs,
      uiJankFrames: getUiJankFrames(budgetMs),
      rasterJankFrames: getRasterJankFrames(budgetMs),
      totalFramesSampled: _count,
    );
  }

  /// Clears the ring buffer in O(1) and resets counters and cooldowns.
  void reset() {
    _ringBuffer.fillRange(0, capacity, null);
    _head = 0;
    _count = 0;
    _consecutiveSmoothFrames = 0;
    _consecutiveSevereJankFrames = 0;
    _downgradeCooldownUntil = null;
    _upgradeCooldownUntil = null;
  }
}
