import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/widgets/chat/m3_speed_dial_fab.dart';

Widget _wrapWidget({
  required Widget child,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
    ),
    home: Scaffold(
      floatingActionButton: child,
    ),
  );
}

void main() {
  group('M3SpeedDialFab Widget Tests', () {
    testWidgets('renders initial collapsed state with edit icon', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrapWidget(
          child: M3SpeedDialFab(
            onSelectGroup: () {},
            onSelectChannel: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
      expect(find.text('Новая группа'), findsNothing);
      expect(find.text('Новый канал'), findsNothing);
    });

    testWidgets('expands on tap and shows group and channel actions', (
      WidgetTester tester,
    ) async {
      bool groupSelected = false;
      bool channelSelected = false;

      await tester.pumpWidget(
        _wrapWidget(
          child: M3SpeedDialFab(
            onSelectGroup: () => groupSelected = true,
            onSelectChannel: () => channelSelected = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap main FAB
      await tester.tap(find.byType(M3SpeedDialFab));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.groups_rounded), findsOneWidget);
      expect(find.byIcon(Icons.campaign_rounded), findsOneWidget);

      // Tap "New Group"
      await tester.tap(find.byIcon(Icons.groups_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(groupSelected, isTrue);
      expect(channelSelected, isFalse);
    });

    testWidgets('tapping channel action triggers onSelectChannel', (
      WidgetTester tester,
    ) async {
      bool channelSelected = false;

      await tester.pumpWidget(
        _wrapWidget(
          child: M3SpeedDialFab(
            onSelectGroup: () {},
            onSelectChannel: () => channelSelected = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(M3SpeedDialFab));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byIcon(Icons.campaign_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(channelSelected, isTrue);
    });

    testWidgets('respects visible: false by scaling down', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrapWidget(
          child: M3SpeedDialFab(
            visible: false,
            onSelectGroup: () {},
            onSelectChannel: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final AnimatedScale scaleWidget = tester.widget(find.byType(AnimatedScale).first);
      expect(scaleWidget.scale, 0.0);
    });
  });
}
