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
}

/// Rolling metrics snapshot for the current sliding window.
@immutable
class PerformanceMetricsSnapshot {
  const PerformanceMetricsSnapshot({
    required this.deviceRefreshRate,
    required this.targetFrameBudgetMs,
    required this.averageBuildMs,
    required this.averageRasterMs,
    required this.jankRatio,
    required this.consecutiveSmoothFrames,
  });

  final double deviceRefreshRate;
  final double targetFrameBudgetMs;
  final double averageBuildMs;
  final double averageRasterMs;
  final double jankRatio;
  final int consecutiveSmoothFrames;

  static const PerformanceMetricsSnapshot initial = PerformanceMetricsSnapshot(
    deviceRefreshRate: 60.0,
    targetFrameBudgetMs: 16.67,
    averageBuildMs: 0.0,
    averageRasterMs: 0.0,
    jankRatio: 0.0,
    consecutiveSmoothFrames: 0,
  );
}

/// Frame timing monitor tracking a rolling ring buffer of [capacity] frames.
///
/// Implements anti-flapping hysteresis:
/// - Fast degradation on 4 consecutive severe drops or > 15% jank ratio.
/// - 8-second downgrade cooldown before permitting any upgrade.
/// - Requires 180 consecutive smooth frames under budget to upgrade.
class FrameTimingMonitor {
  FrameTimingMonitor({
    this.capacity = 60,
    DateTime Function()? nowProvider,
  }) : _nowProvider = nowProvider ?? DateTime.now;

  final int capacity;
  final DateTime Function() _nowProvider;

  final List<FrameMetric> _ringBuffer = <FrameMetric>[];
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
  int get sampleCount => _ringBuffer.length;
  DateTime? get downgradeCooldownUntil => _downgradeCooldownUntil;
  DateTime? get upgradeCooldownUntil => _upgradeCooldownUntil;

  /// Inserts a frame metric into the rolling ring buffer and updates counters.
  void recordMetric(FrameMetric metric, double budgetMs) {
    if (_ringBuffer.length >= capacity) {
      _ringBuffer.removeAt(0);
    }
    _ringBuffer.add(metric);

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
    if (_ringBuffer.isEmpty) return 0.0;
    int jankyCount = 0;
    for (final metric in _ringBuffer) {
      if (metric.isJanky(budgetMs)) {
        jankyCount++;
      }
    }
    return jankyCount / _ringBuffer.length;
  }

  /// Computes average build time in milliseconds.
  double get averageBuildMs {
    if (_ringBuffer.isEmpty) return 0.0;
    double total = 0.0;
    for (final metric in _ringBuffer) {
      total += metric.buildDurationMs;
    }
    return total / _ringBuffer.length;
  }

  /// Computes average raster time in milliseconds.
  double get averageRasterMs {
    if (_ringBuffer.isEmpty) return 0.0;
    double total = 0.0;
    for (final metric in _ringBuffer) {
      total += metric.rasterDurationMs;
    }
    return total / _ringBuffer.length;
  }

  /// Evaluates whether the engine should degrade tier based on hysteresis rules.
  bool shouldDegrade({required double budgetMs}) {
    if (_consecutiveSevereJankFrames >= 4) {
      return true;
    }
    if (_ringBuffer.length >= 10 && getJankRatio(budgetMs) > 0.15) {
      return true;
    }
    return false;
  }

  /// Evaluates whether the engine should upgrade tier based on hysteresis rules.
  bool shouldUpgrade({required double budgetMs, DateTime? currentTime}) {
    final now = currentTime ?? _nowProvider();
    if (_downgradeCooldownUntil != null && now.isBefore(_downgradeCooldownUntil!)) {
      return false;
    }
    if (_upgradeCooldownUntil != null && now.isBefore(_upgradeCooldownUntil!)) {
      return false;
    }
    if (_consecutiveSmoothFrames >= 180 && getJankRatio(budgetMs) < 0.02) {
      return true;
    }
    return false;
  }

  /// Enters downgrade cooldown state (minimum 8 seconds).
  void markDegraded({DateTime? currentTime}) {
    final now = currentTime ?? _nowProvider();
    _downgradeCooldownUntil = now.add(const Duration(seconds: 8));
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
    );
  }

  /// Clears the ring buffer and resets counters and cooldowns.
  void reset() {
    _ringBuffer.clear();
    _consecutiveSmoothFrames = 0;
    _consecutiveSevereJankFrames = 0;
    _downgradeCooldownUntil = null;
    _upgradeCooldownUntil = null;
  }
}
