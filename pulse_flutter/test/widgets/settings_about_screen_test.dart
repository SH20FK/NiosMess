import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/screens/settings_about_screen.dart';

Widget _wrapWithApp(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ru'),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsAboutScreen 4-Tab Material 3 Tests', () {
    testWidgets('Renders Hero header, 4 Pill tabs, and initial Developers tab',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1200));
      await tester.pumpWidget(_wrapWithApp(const SettingsAboutScreen(isEmbedded: true)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Check App name in Hero header
      expect(find.text('NiosMess'), findsWidgets);

      // Check the 4 Tabs
      expect(find.text('Разработчики'), findsWidgets);
      expect(find.text('Правовое'), findsWidgets);
      expect(find.text('FAQ'), findsWidgets);
      expect(find.text('Обновления'), findsWidgets);

      // Initially on Developers tab: Sanlsan and SH20FK
      expect(find.text('Sanlsan'), findsOneWidget);
      expect(find.text('SH20FK'), findsOneWidget);

      // Verify NO Open Source, pulse_flutter, or GitHub mentions
      expect(find.textContaining('Open Source'), findsNothing);
      expect(find.textContaining('pulse_flutter'), findsNothing);
      expect(find.textContaining('GitHub'), findsNothing);
    });

    testWidgets('Switching to Legal tab displays all 4 legal documents',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1200));
      await tester.pumpWidget(_wrapWithApp(const SettingsAboutScreen(isEmbedded: true)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap Legal tab
      await tester.tap(find.text('Правовое').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Verify all 4 legal documents
      expect(find.text('Политика конфиденциальности'), findsWidgets);
      expect(find.text('Условия использования'), findsWidgets);
      expect(find.text('Согласие на обработку данных'), findsOneWidget);
      expect(find.text('Сторонние лицензии и библиотеки'), findsOneWidget);
    });

    testWidgets('Switching to FAQ tab displays FAQ items',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1200));
      await tester.pumpWidget(_wrapWithApp(const SettingsAboutScreen(isEmbedded: true)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap FAQ tab
      await tester.tap(find.text('FAQ').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Verify FAQ tile exists
      expect(find.byType(ExpansionTile), findsWidgets);
    });

    testWidgets('Switching to Changelog tab displays current release',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1200));
      await tester.pumpWidget(_wrapWithApp(const SettingsAboutScreen(isEmbedded: true)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap Changelog tab
      await tester.tap(find.text('Обновления').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Verify Current version
      expect(find.text('v3.10.2 (Expressive)'), findsOneWidget);
      expect(find.text('Текущая'), findsOneWidget);
    });
  });
}
