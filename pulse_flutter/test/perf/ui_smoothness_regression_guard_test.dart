import 'package:flutter_test/flutter_test.dart';
import 'package:universal_io/io.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/performance/frame_timing_monitor.dart';

void main() {
  group('Phase 8: UI Smoothness Regression Guards', () {
    test('SpringCurve satisfies mathematical continuity without terminal step clamps', () {
      final curves = [
        M3SpringCurves.spatial,
        M3SpringCurves.emphasized,
        M3SpringCurves.snappy,
        M3SpringCurves.bouncy,
        M3SpringCurves.gentle,
      ];

      for (final curve in curves) {
        expect(curve.transform(0.0), 0.0);
        expect(curve.transform(1.0), 1.0);
        expect(curve.transform(-0.5), 0.0);
        expect(curve.transform(1.5), 1.0);

        // Verify continuity at boundary (no discontinuous jump)
        final valNearEnd = curve.transform(0.999);
        final valEnd = curve.transform(1.0);
        expect((valEnd - valNearEnd).abs(), lessThan(0.015),
            reason: 'Curve $curve must not have a terminal step jump at t=1.0');
      }
    });

    test('FrameTimingMonitor correctly evaluates percentiles and jank ratios', () {
      final monitor = FrameTimingMonitor();
      const budgetMs = 16.67;

      // Feed 20 frames with varying durations
      for (int i = 1; i <= 20; i++) {
        monitor.recordMetric(
          FrameMetric(
            buildDurationMs: i * 1.0,
            rasterDurationMs: i * 0.8,
            totalSpanMs: i * 1.8,
          ),
          budgetMs,
        );
      }

      expect(monitor.sampleCount, 20);
      expect(monitor.p50BuildMs, closeTo(10.5, 0.5));
      expect(monitor.p90BuildMs, closeTo(18.1, 0.5));
      expect(monitor.p99BuildMs, closeTo(19.8, 0.5));
      expect(monitor.p50RasterMs, closeTo(8.4, 0.5));
      expect(monitor.getUiJankFrames(budgetMs), greaterThan(0));
    });

    test('Anti-pattern guard: Chat message list must NOT perform O(n) indexWhere in findChildIndexCallback', () {
      final file = File('lib/widgets/chat/chat_message_list.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      // Ensure findChildIndexCallback uses O(1) map lookup
      expect(content.contains('_idToIndexCache?[key.value]'), isTrue,
          reason: 'ChatMessageList must use O(1) _idToIndexCache in findChildIndexCallback');
      expect(content.contains('messages.indexWhere((ApiMessage m) => m.id == id)'), isFalse,
          reason: 'ChatMessageList must not use O(n) indexWhere in findChildIndexCallback');
    });

    test('Anti-pattern guard: Chat list screen must NOT perform O(n) indexWhere in findChildIndexCallback', () {
      final file = File('lib/screens/chat_list_screen.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content.contains('idToIndex[id]'), isTrue,
          reason: 'ChatListScreen must use O(1) idToIndex map in findChildIndexCallback');
      expect(content.contains('searched.indexWhere((c) => c.id == id)'), isFalse,
          reason: 'ChatListScreen must not use O(n) indexWhere in findChildIndexCallback');
    });

    test('Anti-pattern guard: ChatTile must NOT wrap avatar in Hero widget inside scroll list', () {
      final file = File('lib/widgets/chat_tile.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content.contains("tag: 'chat_avatar_"), isFalse,
          reason: 'ChatTile must not create Hero tags inside list view items');
    });

    test('Anti-pattern guard: AppMotion.spring must NOT use legacy Material 2 Curves.easeOutBack', () {
      final file = File('lib/core/theme/expressive_tokens.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content.contains('Curves.easeOutBack'), isFalse,
          reason: 'AppMotion.spring must use M3SpringCurves, not legacy Curves.easeOutBack');
    });

    test('Anti-pattern guard: MainShellScreen tab transition must NOT wrap IndexedStack in ScaleTransition', () {
      final file = File('lib/screens/main_shell_screen.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content.contains('_tabScaleAnimation'), isFalse,
          reason: 'MainShellScreen must not scale the entire IndexedStack on tab switch');
    });
  });
}
