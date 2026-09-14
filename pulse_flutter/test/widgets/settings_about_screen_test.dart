import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/screens/settings_about_screen.dart';

Widget _wrapWithApp(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        splashFactory: InkRipple.splashFactory,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ru'),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsAboutScreen 3-Tab Material 3 Expressive Tests', () {
    testWidgets('Renders Hero header, 3 Pill tabs, and initial Whats New tab',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1200));
      await tester.pumpWidget(_wrapWithApp(const SettingsAboutScreen(isEmbedded: true)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Check App name in Hero header
      expect(find.text('NiosMess'), findsWidgets);

      // Check the 3 Tabs
      expect(find.text('Что нового'), findsWidgets);
      expect(find.text('Документы'), findsWidgets);
      expect(find.text('Команда'), findsWidgets);

      // Verify NO fake or unverified text
      expect(find.textContaining('pulse_flutter'), findsNothing);
    });

    testWidgets('Switching to Documents tab displays all 4 legal documents',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1200));
      await tester.pumpWidget(_wrapWithApp(const SettingsAboutScreen(isEmbedded: true)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap Documents tab
      await tester.tap(find.text('Документы').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Verify all 4 legal documents
      expect(find.text('Политика конфиденциальности'), findsWidgets);
      expect(find.text('Условия использования'), findsWidgets);
      expect(find.text('Согласие на обработку данных'), findsOneWidget);
      expect(find.text('Сторонние лицензии и библиотеки'), findsOneWidget);
    });

    testWidgets('Switching to Team tab displays core contributors',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1200));
      await tester.pumpWidget(_wrapWithApp(const SettingsAboutScreen(isEmbedded: true)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap Team tab
      await tester.tap(find.text('Команда').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Check developers sanlsan and SH20FK
      expect(find.text('sanlsan'), findsOneWidget);
      expect(find.text('SH20FK'), findsOneWidget);
    });
  });
}
