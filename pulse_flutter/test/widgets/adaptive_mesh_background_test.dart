import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';
import 'package:pulse_flutter/widgets/adaptive/adaptive_mesh_background.dart';
import 'package:pulse_flutter/widgets/adaptive/adaptive_organic_background.dart';

void main() {
  group('F5: AdaptiveMeshBackground Widget Tests', () {
    testWidgets('renders animated blobs on Tier A', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(adaptivePerformanceProvider.notifier).setMode(PerformanceMode.flagship);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AdaptiveMeshBackground(
              child: Text('Mesh Child'),
            ),
          ),
        ),
      );

      final animatedBuilderInMesh = find.descendant(
        of: find.byType(RepaintBoundary),
        matching: find.byType(AnimatedBuilder),
      );
      expect(animatedBuilderInMesh, findsOneWidget);
      expect(find.text('Mesh Child'), findsOneWidget);
    });

    testWidgets('renders static blobs without AnimatedBuilder on Tier B', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(adaptivePerformanceProvider.notifier).setMode(PerformanceMode.balanced);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AdaptiveMeshBackground(
              child: Text('Mesh Child Tier B'),
            ),
          ),
        ),
      );

      final animatedBuilderInMesh = find.descendant(
        of: find.byType(RepaintBoundary),
        matching: find.byType(AnimatedBuilder),
      );
      expect(animatedBuilderInMesh, findsNothing);
      expect(find.byType(RepaintBoundary), findsWidgets);
      expect(find.text('Mesh Child Tier B'), findsOneWidget);
    });

    testWidgets('omits AnimatedBuilder and tickers on Tier C (hero gradient container)', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(adaptivePerformanceProvider.notifier).setMode(PerformanceMode.powerSaver);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AdaptiveMeshBackground(
              child: Text('Mesh Child Tier C'),
            ),
          ),
        ),
      );

      // On Tier C, AnimatedBuilder inside RepaintBoundary must NOT be present
      final animatedBuilderInMesh = find.descendant(
        of: find.byType(RepaintBoundary),
        matching: find.byType(AnimatedBuilder),
      );
      expect(animatedBuilderInMesh, findsNothing);
      expect(find.text('Mesh Child Tier C'), findsOneWidget);
    });
  });

  group('F5: AdaptiveOrganicBackground Widget Tests', () {
    testWidgets('renders CustomPaint with 54 blur on Tier A', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(adaptivePerformanceProvider.notifier).setMode(PerformanceMode.flagship);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AdaptiveOrganicBackground(
              child: Text('Organic Child A'),
            ),
          ),
        ),
      );

      final customPaintFinder = find.byType(CustomPaint);
      expect(customPaintFinder, findsWidgets);

      final customPaints = tester.widgetList<CustomPaint>(customPaintFinder);
      final organicPaint = customPaints.firstWhere(
        (p) => p.painter is AdaptiveOrganicBlobsPainter,
      );
      final painter = organicPaint.painter as AdaptiveOrganicBlobsPainter;
      expect(painter.blurSigma, equals(54.0));
      expect(painter.isTierB, isFalse);
    });

    testWidgets('renders CustomPaint with 16 blur on Tier B', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(adaptivePerformanceProvider.notifier).setMode(PerformanceMode.balanced);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AdaptiveOrganicBackground(
              child: Text('Organic Child B'),
            ),
          ),
        ),
      );

      final customPaintFinder = find.byType(CustomPaint);
      expect(customPaintFinder, findsWidgets);

      final customPaints = tester.widgetList<CustomPaint>(customPaintFinder);
      final organicPaint = customPaints.firstWhere(
        (p) => p.painter is AdaptiveOrganicBlobsPainter,
      );
      final painter = organicPaint.painter as AdaptiveOrganicBlobsPainter;
      expect(painter.blurSigma, equals(16.0));
      expect(painter.isTierB, isTrue);
    });

    testWidgets('omits CustomPaint and MaskFilter blur completely on Tier C', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(adaptivePerformanceProvider.notifier).setMode(PerformanceMode.powerSaver);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AdaptiveOrganicBackground(
              child: Text('Organic Child C'),
            ),
          ),
        ),
      );

      final customPaintFinder = find.byType(CustomPaint);
      final hasOrganicPaint = customPaintFinder.evaluate().any((e) {
        final widget = e.widget as CustomPaint;
        return widget.painter is AdaptiveOrganicBlobsPainter;
      });
      expect(hasOrganicPaint, isFalse);
      expect(find.text('Organic Child C'), findsOneWidget);
    });
  });
}
