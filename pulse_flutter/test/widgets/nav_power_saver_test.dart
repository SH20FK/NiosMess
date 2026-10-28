import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';
import 'package:pulse_flutter/core/performance/frame_timing_monitor.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/app_bottom_nav.dart';

class _NavTestSettings extends UiSettingsNotifier {
  @override
  UiSettingsState build() =>
      const UiSettingsState.defaults().copyWith(soundEffects: false);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'automatic power saver keeps navigation motion, while reduced motion disables it',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          uiSettingsProvider.overrideWith(_NavTestSettings.new),
          totalUnreadCountProvider.overrideWithValue(0),
        ],
      );
      addTearDown(container.dispose);
      var index = 0;
      var reduced = false;
      late StateSetter update;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(disableAnimations: reduced),
                  child: Scaffold(
                    bottomNavigationBar: AppBottomNav(
                      currentIndex: index,
                      hapticsEnabled: false,
                      onTap: (next) => setState(() => index = next),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      final performance = container.read(adaptivePerformanceProvider.notifier);
      performance.setMode(PerformanceMode.balanced);
      await tester.pump();
      await tester.tap(find.text('Лента'));
      await tester.pump(const Duration(milliseconds: 60));
      for (var i = 0; i < 4; i++) {
        performance.recordMetric(
          const FrameMetric(
            buildDurationMs: 100,
            rasterDurationMs: 100,
            totalSpanMs: 100,
          ),
        );
      }
      expect(
        container.read(adaptivePerformanceProvider).mode,
        PerformanceMode.powerSaver,
      );
      await tester.pump();
      final nav = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(nav.animationDuration, greaterThan(Duration.zero));
      expect(
        tester
            .widgetList<TabMorphIcon>(find.byType(TabMorphIcon))
            .every((icon) => icon.animate),
        isTrue,
      );
      update(() => reduced = true);
      await tester.pump();
      expect(
        tester
            .widget<NavigationBar>(find.byType(NavigationBar))
            .animationDuration,
        Duration.zero,
      );
      expect(
        tester
            .widgetList<TabMorphIcon>(find.byType(TabMorphIcon))
            .every((icon) => !icon.animate),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
