import 'dart:ui' show FrameTiming;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';
import 'package:pulse_flutter/core/performance/frame_timing_monitor.dart';
import 'package:pulse_flutter/core/services/account_background_policy.dart';
import 'package:pulse_flutter/core/services/background_service.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

class _Settings extends UiSettingsNotifier {
  @override
  UiSettingsState build() => const UiSettingsState.defaults();
  void setWeak(bool value) =>
      state = state.copyWith(optimizeForWeakDevices: value);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('changing weak-device mode repeatedly preserves the monitor', () async {
    final container = ProviderContainer(
      overrides: [uiSettingsProvider.overrideWith(_Settings.new)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(adaptivePerformanceProvider.notifier);
    final monitor = notifier.monitor;
    for (var i = 0; i < 20; i++) {
      (container.read(uiSettingsProvider.notifier) as _Settings).setWeak(
        i.isEven,
      );
      await container.pump();
      final state = container.read(adaptivePerformanceProvider);
      expect(state.mode == PerformanceMode.powerSaver, i.isEven);
      expect(
        identical(
          container.read(adaptivePerformanceProvider.notifier).monitor,
          monitor,
        ),
        isTrue,
      );
    }
  });

  test('refresh changes use the actual display rate and clear old samples', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(adaptivePerformanceProvider.notifier);
    notifier.recordMetric(
      const FrameMetric(
        buildDurationMs: 5,
        rasterDurationMs: 5,
        totalSpanMs: 8,
      ),
    );
    notifier.refreshDisplayRate(refreshRate: 144);
    expect(
      container.read(adaptivePerformanceProvider).targetFrameBudgetMs,
      closeTo(1000 / 144, .0001),
    );
    expect(notifier.monitor.sampleCount, 0);
    expect(FrameTimingMonitor.computeTargetFps(double.nan), 60);
  });

  test('active user interaction defers mild tier changes, then releases', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(adaptivePerformanceProvider.notifier)
      ..setMode(PerformanceMode.flagship);
    notifier.refreshDisplayRate(refreshRate: 60);
    final owner = Object();
    notifier.setInteractionActive(owner, true);
    for (var i = 0; i < 30; i++) {
      notifier.recordMetric(
        const FrameMetric(
          buildDurationMs: 20,
          rasterDurationMs: 10,
          totalSpanMs: 24,
        ),
      );
    }
    expect(
      container.read(adaptivePerformanceProvider).mode,
      PerformanceMode.flagship,
    );
    notifier.setInteractionActive(owner, false);
    notifier.recordMetric(
      const FrameMetric(
        buildDurationMs: 20,
        rasterDurationMs: 10,
        totalSpanMs: 24,
      ),
    );
    expect(
      container.read(adaptivePerformanceProvider).mode,
      PerformanceMode.balanced,
    );
  });

  test('telemetry updates independently and keeps more than 60 samples', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(adaptivePerformanceProvider.notifier);
    final now = DateTime(2026, 10, 15);
    for (var i = 0; i < 200; i++) {
      notifier.recordMetric(
        const FrameMetric(
          buildDurationMs: 2,
          rasterDurationMs: 3,
          totalSpanMs: 6,
        ),
        currentTime: now,
      );
    }
    expect(container.read(performanceTelemetryProvider).totalFramesSampled, 1);
    notifier.recordMetric(
      const FrameMetric(
        buildDurationMs: 2,
        rasterDurationMs: 3,
        totalSpanMs: 6,
      ),
      currentTime: now.add(const Duration(seconds: 1)),
    );
    final snapshot = container.read(performanceTelemetryProvider);
    expect(snapshot.totalFramesSampled, 201);
    expect(snapshot.p99RasterMs, 3);
  });

  test(
    'a severe burst inside one timing batch survives later smooth frames',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(adaptivePerformanceProvider.notifier)
        ..setMode(PerformanceMode.flagship);
      notifier.setInteractionActive(Object(), true);
      FrameTiming frame(int duration) => FrameTiming(
        vsyncStart: 0,
        buildStart: 0,
        buildFinish: duration,
        rasterStart: duration,
        rasterFinish: duration * 2,
        rasterFinishWallTime: duration * 2,
      );
      notifier.onTimings([
        for (var i = 0; i < 4; i++) frame(40000),
        for (var i = 0; i < 4; i++) frame(1000),
      ]);
      expect(
        container.read(adaptivePerformanceProvider).mode,
        PerformanceMode.balanced,
      );
    },
  );

  test('reliable idle keeps delivery without holding a CPU wake lock', () {
    const policy = AccountBackgroundPolicy(
      authenticated: true,
      background: true,
      reliable: true,
      activeWork: false,
    );
    expect(policy.keepSocket, isTrue);
    expect(policy.keepService, isTrue);
    expect(policy.keepCpuAwake, isFalse);
  });

  test(
    'economy call or transfer temporarily keeps transport and CPU active',
    () {
      const policy = AccountBackgroundPolicy(
        authenticated: true,
        background: true,
        reliable: false,
        activeWork: true,
      );
      expect(
        policy.keepSocket && policy.keepService && policy.keepCpuAwake,
        isTrue,
      );
      const idle = AccountBackgroundPolicy(
        authenticated: true,
        background: true,
        reliable: false,
        activeWork: false,
      );
      expect(idle.keepSocket || idle.keepService || idle.keepCpuAwake, isFalse);
      const loggedOut = AccountBackgroundPolicy(
        authenticated: false,
        background: false,
        reliable: true,
        activeWork: true,
      );
      expect(
        loggedOut.keepSocket || loggedOut.keepService || loggedOut.keepCpuAwake,
        isFalse,
      );
    },
  );

  test('transfer ownership is independently released and idempotent', () {
    final initial = BackgroundService.workCount.value;
    final releaseA = BackgroundService.retainWork();
    final releaseB = BackgroundService.retainWork();
    expect(BackgroundService.workCount.value, initial + 2);
    releaseA();
    releaseA();
    expect(BackgroundService.workCount.value, initial + 1);
    releaseB();
    expect(BackgroundService.workCount.value, initial);
  });
}
