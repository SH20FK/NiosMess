// Contract tests for the shell's bottom navigation chrome:
// * M3 80dp bar with a solid tonal indicator (active tab must read instantly).
// * Unread badge pinned above the destination icon, capped at `99+`, and
//   hidden on the selected destination (INBOX_VISUAL_AUDIT_2026-11-16, #2/#4).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/app_bottom_nav.dart';

class _NavSettings extends UiSettingsNotifier {
  @override
  UiSettingsState build() =>
      const UiSettingsState.defaults().copyWith(soundEffects: false);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> pumpNav(
    WidgetTester tester, {
    required int unread,
    int index = 1,
  }) async {
    final container = ProviderContainer(
      overrides: [
        uiSettingsProvider.overrideWith(_NavSettings.new),
        totalUnreadCountProvider.overrideWithValue(unread),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.themed(
            const UiSettingsState.defaults().visualTheme,
            Brightness.light,
          ),
          home: Scaffold(
            bottomNavigationBar: AppBottomNav(
              currentIndex: index,
              hapticsEnabled: false,
              onTap: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('navigation bar is 80dp tall with a solid tonal indicator', (
    tester,
  ) async {
    await pumpNav(tester, unread: 0);

    final Finder nav = find.byType(NavigationBar);
    expect(nav, findsOneWidget);
    expect(tester.getSize(nav).height, 80);

    final NavigationBar bar = tester.widget<NavigationBar>(nav);
    expect(bar.labelBehavior, NavigationDestinationLabelBehavior.alwaysShow);

    final BuildContext navContext = tester.element(nav);
    final ColorScheme scheme = Theme.of(navContext).colorScheme;
    expect(
      NavigationBarTheme.of(navContext).indicatorColor,
      scheme.secondaryContainer,
    );
    expect(
      tester
          .widgetList<TabMorphIcon>(find.byType(TabMorphIcon))
          .every((TabMorphIcon icon) => icon.size == 24),
      isTrue,
    );
  });

  testWidgets('unread badge is capped and sits above the icon, not on it', (
    tester,
  ) async {
    await pumpNav(tester, unread: 128, index: 1);

    final Finder label = find.text('99+');
    expect(label, findsOneWidget);
    expect(find.text('120'), findsNothing);

    final Rect labelRect = tester.getRect(label);
    final Rect iconRect = tester.getRect(find.byType(TabMorphIcon).first);
    // The pill hugs the icon's top edge: it may overlap by a couple of
    // pixels but must never paint over the glyph.
    expect(labelRect.bottom, lessThanOrEqualTo(iconRect.top + 4));
    // And it must not drift into the neighbouring destination.
    expect(labelRect.left, greaterThan(iconRect.left - 24));
  });

  testWidgets('badge is hidden on the selected destination', (tester) async {
    await pumpNav(tester, unread: 128, index: 0);

    expect(find.text('99+'), findsNothing);
    expect(find.byType(Badge), findsNothing);
  });

  testWidgets('small unread counts render as a number, zero renders nothing', (
    tester,
  ) async {
    await pumpNav(tester, unread: 7, index: 1);
    expect(find.text('7'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await pumpNav(tester, unread: 0, index: 1);
    expect(find.byType(Badge), findsNothing);
  });

  testWidgets('tapping the active destination reselects instead of navigating', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        uiSettingsProvider.overrideWith(_NavSettings.new),
        totalUnreadCountProvider.overrideWithValue(0),
      ],
    );
    addTearDown(container.dispose);
    final List<int> taps = <int>[];
    final List<int> reselects = <int>[];
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            bottomNavigationBar: AppBottomNav(
              currentIndex: 0,
              hapticsEnabled: false,
              onTap: taps.add,
              onReselect: (int index) {
                reselects.add(index);
                return true;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(NavigationDestination).first);
    expect(reselects, <int>[0]);
    expect(taps, isEmpty);

    await tester.tap(find.byType(NavigationDestination).last);
    expect(taps, <int>[2]);
    expect(reselects, <int>[0]);
  });
}
