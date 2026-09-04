import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';
import 'package:pulse_flutter/widgets/adaptive/adaptive_glass.dart';

void main() {
  group('F4: AdaptiveGlass Widget Tests', () {
    testWidgets('renders BackdropFilter with tierASigma on Tier A', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(adaptivePerformanceProvider.notifier).setMode(PerformanceMode.flagship);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: AdaptiveGlass(
                tierASigma: 22.0,
                tierBSigma: 7.0,
                child: const Text('Tier A Glass'),
              ),
            ),
          ),
        ),
      );

      final backdropFinder = find.byType(BackdropFilter);
      expect(backdropFinder, findsOneWidget);

      final backdrop = tester.widget<BackdropFilter>(backdropFinder);
      expect(backdrop.filter.toString(), contains('22.0'));
      expect(find.text('Tier A Glass'), findsOneWidget);
    });

    testWidgets('renders BackdropFilter with tierBSigma on Tier B', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(adaptivePerformanceProvider.notifier).setMode(PerformanceMode.balanced);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: AdaptiveGlass(
                tierASigma: 22.0,
                tierBSigma: 7.0,
                child: const Text('Tier B Glass'),
              ),
            ),
          ),
        ),
      );

      final backdropFinder = find.byType(BackdropFilter);
      expect(backdropFinder, findsOneWidget);

      final backdrop = tester.widget<BackdropFilter>(backdropFinder);
      expect(backdrop.filter.toString(), contains('7.0'));
      expect(find.text('Tier B Glass'), findsOneWidget);
    });

    testWidgets('omits BackdropFilter completely on Tier C (zero blur passes)', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(adaptivePerformanceProvider.notifier).setMode(PerformanceMode.powerSaver);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: AdaptiveGlass(
                tierASigma: 22.0,
                tierBSigma: 7.0,
                child: const Text('Tier C Glass'),
              ),
            ),
          ),
        ),
      );

      // On Tier C, BackdropFilter must NOT be in the widget tree at all!
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('Tier C Glass'), findsOneWidget);
    });
  });
}
