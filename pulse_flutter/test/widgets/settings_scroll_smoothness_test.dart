import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

Widget _buildTestHarness({required Widget child}) {
  return ProviderScope(
    child: MaterialApp(
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        splashFactory: InkRipple.splashFactory,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ru'),
      home: Scaffold(
        body: child,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Settings Tiles Fluid Gesture & Scroll Tests', () {
    testWidgets('Scrolling does not trigger premature pressed scale twitching on SettingsTile',
        (WidgetTester tester) async {
      int tappedCount = 0;

      await tester.pumpWidget(
        _buildTestHarness(
          child: SettingsScaffold(
            title: 'Тест прокрутки',
            children: <Widget>[
              SettingsSection(
                title: 'Секция 1',
                children: List.generate(
                  15,
                  (index) => SettingsTile(
                    icon: Icons.star_rounded,
                    title: 'Элемент $index',
                    onTap: () => tappedCount++,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify all initial scales are 1.0
      final initialScales = tester.widgetList<AnimatedScale>(find.byType(AnimatedScale));
      for (final scale in initialScales) {
        expect(scale.scale, 1.0);
      }

      // Perform a drag/scroll gesture starting over the first tile
      final firstTile = find.text('Элемент 0');
      expect(firstTile, findsOneWidget);

      await tester.drag(firstTile, const Offset(0, -300));
      await tester.pump();

      // No tap should have been registered during a scroll drag
      expect(tappedCount, 0);

      // Verify that after drag, scales are at 1.0 and settle cleanly
      await tester.pumpAndSettle();
      final postScrollScales = tester.widgetList<AnimatedScale>(find.byType(AnimatedScale));
      for (final scale in postScrollScales) {
        expect(scale.scale, 1.0);
      }
    });

    testWidgets('Tapping SettingsTile triggers callback with tactile scale feedback',
        (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        _buildTestHarness(
          child: SettingsScaffold(
            title: 'Тест нажатия',
            children: <Widget>[
              SettingsSection(
                children: <Widget>[
                  SettingsTile(
                    icon: Icons.palette_rounded,
                    title: 'Тема оформления',
                    value: 'Тёмная',
                    onTap: () => tapped = true,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Тема оформления'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('SettingsSwitchTile toggles value with checkmark thumbIcon',
        (WidgetTester tester) async {
      bool switchVal = false;

      await tester.pumpWidget(
        _buildTestHarness(
          child: StatefulBuilder(
            builder: (context, setState) {
              return SettingsScaffold(
                title: 'Тест переключателя',
                children: <Widget>[
                  SettingsSection(
                    children: <Widget>[
                      SettingsSwitchTile(
                        icon: Icons.vibration_rounded,
                        title: 'Тактильный отклик',
                        value: switchVal,
                        onChanged: (val) => setState(() => switchVal = val),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(switchVal, isFalse);

      // Tap the tile to toggle
      await tester.tap(find.text('Тактильный отклик'));
      await tester.pumpAndSettle();

      expect(switchVal, isTrue);
    });

    testWidgets('SettingsInfoTile displays subtitle, value and handles long press',
        (WidgetTester tester) async {
      bool longPressed = false;

      await tester.pumpWidget(
        _buildTestHarness(
          child: SettingsScaffold(
            title: 'Инфо тест',
            children: <Widget>[
              SettingsSection(
                children: <Widget>[
                  SettingsInfoTile(
                    icon: Icons.info_outline_rounded,
                    title: 'Версия клиента',
                    subtitle: 'Официальная сборка',
                    value: 'v3.28.0',
                    onLongPress: () => longPressed = true,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Версия клиента'), findsOneWidget);
      expect(find.text('Официальная сборка'), findsOneWidget);
      expect(find.text('v3.28.0'), findsOneWidget);

      await tester.longPress(find.text('Версия клиента'));
      await tester.pumpAndSettle();

      expect(longPressed, isTrue);
    });
  });
}
