import 'dart:ui' show FrameTiming;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/performance/frame_timing_monitor.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

/// 3-tier performance mode.
enum PerformanceMode {
  flagship,
  balanced,
  powerSaver;

  PerformanceTier get tier {
    switch (this) {
      case PerformanceMode.flagship:
        return PerformanceTier.tierA;
      case PerformanceMode.balanced:
        return PerformanceTier.tierB;
      case PerformanceMode.powerSaver:
        return PerformanceTier.tierC;
    }
  }
}

/// Abstract 3-tier graphics classification.
enum PerformanceTier {
  tierA,
  tierB,
  tierC;

  bool get isTierA => this == PerformanceTier.tierA;
  bool get isTierB => this == PerformanceTier.tierB;
  bool get isTierC => this == PerformanceTier.tierC;
}

/// State representation of the adaptive performance engine.
@immutable
class AdaptivePerformanceState {
  const AdaptivePerformanceState({
    required this.mode,
    required this.targetFps,
    required this.targetFrameBudgetMs,
    required this.recentJankRatio,
    required this.isDegraded,
    this.consecutiveSmoothFrames = 0,
    this.averageBuildMs = 0.0,
    this.averageRasterMs = 0.0,
    this.isPaused = false,
  });

  final PerformanceMode mode;
  final double targetFps;
  final double targetFrameBudgetMs;
  final double recentJankRatio;
  final bool isDegraded;
  final int consecutiveSmoothFrames;
  final double averageBuildMs;
  final double averageRasterMs;
  final bool isPaused;

  PerformanceTier get tier => mode.tier;

  AdaptivePerformanceState copyWith({
    PerformanceMode? mode,
    double? targetFps,
    double? targetFrameBudgetMs,
    double? recentJankRatio,
    bool? isDegraded,
    int? consecutiveSmoothFrames,
    double? averageBuildMs,
    double? averageRasterMs,
    bool? isPaused,
  }) {
    return AdaptivePerformanceState(
      mode: mode ?? this.mode,
      targetFps: targetFps ?? this.targetFps,
      targetFrameBudgetMs: targetFrameBudgetMs ?? this.targetFrameBudgetMs,
      recentJankRatio: recentJankRatio ?? this.recentJankRatio,
      isDegraded: isDegraded ?? this.isDegraded,
      consecutiveSmoothFrames:
          consecutiveSmoothFrames ?? this.consecutiveSmoothFrames,
      averageBuildMs: averageBuildMs ?? this.averageBuildMs,
      averageRasterMs: averageRasterMs ?? this.averageRasterMs,
      isPaused: isPaused ?? this.isPaused,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdaptivePerformanceState &&
          runtimeType == other.runtimeType &&
          mode == other.mode &&
          targetFps == other.targetFps &&
          targetFrameBudgetMs == other.targetFrameBudgetMs &&
          recentJankRatio == other.recentJankRatio &&
          isDegraded == other.isDegraded &&
          consecutiveSmoothFrames == other.consecutiveSmoothFrames &&
          averageBuildMs == other.averageBuildMs &&
          averageRasterMs == other.averageRasterMs &&
          isPaused == other.isPaused;

  @override
  int get hashCode =>
      mode.hashCode ^
      targetFps.hashCode ^
      targetFrameBudgetMs.hashCode ^
      recentJankRatio.hashCode ^
      isDegraded.hashCode ^
      consecutiveSmoothFrames.hashCode ^
      averageBuildMs.hashCode ^
      averageRasterMs.hashCode ^
      isPaused.hashCode;
}

/// Riverpod 3.x Notifier managing adaptive performance state.
class AdaptivePerformanceNotifier extends Notifier<AdaptivePerformanceState>
    with WidgetsBindingObserver {
  late final FrameTimingMonitor _monitor;
  bool _callbackRegistered = false;
  bool _observerRegistered = false;
  double _detectedRefreshRate = 60.0;

  FrameTimingMonitor get monitor => _monitor;

  @override
  AdaptivePerformanceState build() {
    _monitor = FrameTimingMonitor();
    _detectedRefreshRate = FrameTimingMonitor.detectRefreshRate();
    final double budget = FrameTimingMonitor.computeBudgetMs(_detectedRefreshRate);
    final double fps = FrameTimingMonitor.computeTargetFps(_detectedRefreshRate);

    // Initial tier based on hardware capabilities
    PerformanceMode initialMode = PerformanceMode.balanced;
    if (_detectedRefreshRate >= 110.0) {
      initialMode = PerformanceMode.flagship;
    } else if (_detectedRefreshRate < 70.0) {
      initialMode = PerformanceMode.balanced;
    }

    // Check if user has already forced weak device optimization
    final bool weakDeviceForced =
        ref.watch(uiSettingsProvider.select((s) => s.optimizeForWeakDevices));
    if (weakDeviceForced) {
      initialMode = PerformanceMode.powerSaver;
    }

    // Setup lifecycle and frame timings callbacks safely
    _registerLifecycleObserver();
    _registerTimingsCallback();

    ref.onDispose(() {
      _unregisterTimingsCallback();
      _unregisterLifecycleObserver();
    });

    return AdaptivePerformanceState(
      mode: initialMode,
      targetFps: fps,
      targetFrameBudgetMs: budget,
      recentJankRatio: 0.0,
      isDegraded: initialMode == PerformanceMode.powerSaver,
      consecutiveSmoothFrames: 0,
      averageBuildMs: 0.0,
      averageRasterMs: 0.0,
    );
  }

  void _registerLifecycleObserver() {
    if (_observerRegistered) return;
    try {
      final binding = WidgetsBinding.instance;
      binding.addObserver(this);
      _observerRegistered = true;
    } catch (_) {}
  }

  void _unregisterLifecycleObserver() {
    if (!_observerRegistered) return;
    try {
      final binding = WidgetsBinding.instance;
      binding.removeObserver(this);
      _observerRegistered = false;
    } catch (_) {}
  }

  void _registerTimingsCallback() {
    if (_callbackRegistered) return;
    try {
      final binding = WidgetsBinding.instance;
      binding.addTimingsCallback(_handleTimings);
      _callbackRegistered = true;
    } catch (_) {}
  }

  void _unregisterTimingsCallback() {
    if (!_callbackRegistered) return;
    try {
      final binding = WidgetsBinding.instance;
      binding.removeTimingsCallback(_handleTimings);
      _callbackRegistered = false;
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _unregisterTimingsCallback();
      this.state = this.state.copyWith(isPaused: true);
    } else if (state == AppLifecycleState.resumed) {
      _registerTimingsCallback();
      this.state = this.state.copyWith(isPaused: false);
    }
  }

  void _handleTimings(List<FrameTiming> timings) {
    onTimings(timings);
  }

  /// Processes frame timings and performs anti-flapping hysteresis evaluation.
  void onTimings(List<FrameTiming> timings, {DateTime? currentTime}) {
    if (timings.isEmpty) return;

    final budget = state.targetFrameBudgetMs;
    for (final timing in timings) {
      _monitor.recordTiming(timing, budget);
    }

    _evaluateHysteresis(currentTime: currentTime);
  }

  /// Directly records a single [FrameMetric] (useful for testing).
  void recordMetric(FrameMetric metric, {DateTime? currentTime}) {
    _monitor.recordMetric(metric, state.targetFrameBudgetMs);
    _evaluateHysteresis(currentTime: currentTime);
  }

  void _evaluateHysteresis({DateTime? currentTime}) {
    final bool weakDeviceForced =
        ref.read(uiSettingsProvider.select((s) => s.optimizeForWeakDevices));

    if (weakDeviceForced) {
      if (state.mode != PerformanceMode.powerSaver || !state.isDegraded) {
        state = state.copyWith(
          mode: PerformanceMode.powerSaver,
          isDegraded: true,
          recentJankRatio: _monitor.getJankRatio(state.targetFrameBudgetMs),
          consecutiveSmoothFrames: _monitor.consecutiveSmoothFrames,
          averageBuildMs: _monitor.averageBuildMs,
          averageRasterMs: _monitor.averageRasterMs,
        );
      }
      return;
    }

    final double budget = state.targetFrameBudgetMs;
    final now = currentTime ?? DateTime.now();

    PerformanceMode currentMode = state.mode;
    bool isDegraded = state.isDegraded;

    // Check degradation
    if (_monitor.shouldDegrade(budgetMs: budget)) {
      if (currentMode == PerformanceMode.flagship) {
        currentMode = PerformanceMode.balanced;
        isDegraded = true;
        _monitor.markDegraded(currentTime: now);
      } else if (currentMode == PerformanceMode.balanced) {
        currentMode = PerformanceMode.powerSaver;
        isDegraded = true;
        _monitor.markDegraded(currentTime: now);
      }
    }
    // Check upgrade
    else if (_monitor.shouldUpgrade(budgetMs: budget, currentTime: now)) {
      if (currentMode == PerformanceMode.powerSaver) {
        currentMode = PerformanceMode.balanced;
        isDegraded = false;
        _monitor.markUpgraded(currentTime: now);
      } else if (currentMode == PerformanceMode.balanced && _detectedRefreshRate >= 90.0) {
        currentMode = PerformanceMode.flagship;
        isDegraded = false;
        _monitor.markUpgraded(currentTime: now);
      }
    }

    state = state.copyWith(
      mode: currentMode,
      isDegraded: isDegraded,
      recentJankRatio: _monitor.getJankRatio(budget),
      consecutiveSmoothFrames: _monitor.consecutiveSmoothFrames,
      averageBuildMs: _monitor.averageBuildMs,
      averageRasterMs: _monitor.averageRasterMs,
    );
  }

  /// Manually forces a performance mode.
  void setMode(PerformanceMode mode) {
    state = state.copyWith(
      mode: mode,
      isDegraded: mode == PerformanceMode.powerSaver,
    );
  }

  /// Resets rolling metrics and anti-flapping hysteresis cooldowns.
  void resetMetrics() {
    _monitor.reset();
    state = state.copyWith(
      recentJankRatio: 0.0,
      consecutiveSmoothFrames: 0,
      averageBuildMs: 0.0,
      averageRasterMs: 0.0,
    );
  }
}

/// Global provider for the adaptive performance engine.
final adaptivePerformanceProvider =
    NotifierProvider<AdaptivePerformanceNotifier, AdaptivePerformanceState>(
  AdaptivePerformanceNotifier.new,
);
