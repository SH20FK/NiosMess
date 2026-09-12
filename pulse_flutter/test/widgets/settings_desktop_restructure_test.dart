import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

Widget _buildDesktopTestHarness({required Widget child, required Size size}) {
  return ProviderScope(
    child: MaterialApp(
      theme: ThemeData.light(useMaterial3: true),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ru'),
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Settings Desktop Restructuring Tests', () {
    testWidgets('SettingsScaffold in embedded mode centers content with default maxWidth 860',
        (WidgetTester tester) async {
      const Size desktopSize = Size(1920, 1080);
      tester.view.physicalSize = desktopSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _buildDesktopTestHarness(
          size: desktopSize,
          child: SettingsScaffold(
            isEmbedded: true,
            title: 'Настройки',
            children: <Widget>[
              SettingsSection(
                title: 'Секция 1',
                children: <Widget>[
                  SettingsTile(
                    icon: Icons.person_rounded,
                    title: 'Профиль',
                    onTap: () {},
                  ),
                ],
              ),
              SettingsSection(
                title: 'Секция 2',
                children: <Widget>[
                  SettingsTile(
                    icon: Icons.shield_rounded,
                    title: 'Безопасность',
                    onTap: () {},
                  ),
                ],
              ),
              SettingsSection(
                title: 'Секция 3',
                children: <Widget>[
                  SettingsTile(
                    icon: Icons.storage_rounded,
                    title: 'Память',
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final alignFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Align &&
            widget.alignment == Alignment.topCenter &&
            widget.child is ConstrainedBox,
      );
      expect(alignFinder, findsOneWidget);

      final alignWidget = tester.widget<Align>(alignFinder);
      final constrainedBox = alignWidget.child as ConstrainedBox;
      expect(constrainedBox.constraints.maxWidth, 860.0);

      expect(find.text('Секция 1'), findsOneWidget);
      expect(find.text('Секция 2'), findsOneWidget);
      expect(find.text('Секция 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Wide custom studio with maxWidth 1120 is properly constrained and centered',
        (WidgetTester tester) async {
      const Size desktopSize = Size(2560, 1440);
      tester.view.physicalSize = desktopSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _buildDesktopTestHarness(
          size: desktopSize,
          child: const SettingsScaffold(
            isEmbedded: true,
            maxWidth: 1120,
            title: 'Студия оформления',
            children: <Widget>[
              SettingsSection(
                title: 'Палитра',
                children: <Widget>[
                  Text('Выбор темы'),
                ],
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final alignFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Align &&
            widget.alignment == Alignment.topCenter &&
            widget.child is ConstrainedBox,
      );
      expect(alignFinder, findsOneWidget);

      final alignWidget = tester.widget<Align>(alignFinder);
      final constrainedBox = alignWidget.child as ConstrainedBox;
      expect(constrainedBox.constraints.maxWidth, 1120.0);
      expect(tester.takeException(), isNull);
    });
  });
}
