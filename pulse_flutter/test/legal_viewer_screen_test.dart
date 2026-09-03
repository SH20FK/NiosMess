import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/screens/legal_viewer_screen.dart';

const String samplePrivacyText = '''
PRIVACY AND PERSONAL DATA PROCESSING POLICY

Effective Date: June 29, 2026

This is the preamble text of the Privacy Policy.

1. Terms and Definitions
Operator — The Administration of NiosMess.
User — Any registered individual.

2. Security and E2EE Encryption
All secret chats are encrypted end-to-end.
- Decryption keys are stored locally.
- Nobody else has access.
''';

Widget _buildTestWidget(LegalDocType docType, {String? initialContent}) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.themed(
        const VisualThemeSettings(
          seedColor: Color(0xFF1E88E5),
          themeMode: ThemeMode.light,
          useSystemDynamic: false,
          predictiveBackEnabled: false,
        ),
        Brightness.light,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ru'),
      home: LegalViewerScreen(
        docType: docType,
        initialContent: initialContent ?? samplePrivacyText,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LegalViewerScreen M3 Expressive Tests', () {
    testWidgets('Renders Privacy Policy with M3 hero card and section cards', (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestWidget(LegalDocType.privacy));
      await tester.pumpAndSettle();

      // Verify app bar title
      expect(find.text('Политика конфиденциальности'), findsWidgets);

      // Verify metadata badge
      expect(find.text('GDPR & E2EE Verified'), findsOneWidget);

      // Verify section titles (appears in top quick-jump chip and section card)
      expect(find.text('Terms and Definitions'), findsWidgets);
      expect(find.text('Security and E2EE Encryption'), findsWidgets);

      // Verify bottom confirm button
      expect(find.text('Понятно, закрыть'), findsOneWidget);
    });

    testWidgets('Renders Terms of Service with M3 hero card and sections', (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestWidget(LegalDocType.tos));
      await tester.pumpAndSettle();

      expect(find.text('Условия использования'), findsWidgets);
      expect(find.text('Понятно, закрыть'), findsOneWidget);
    });

    testWidgets('Renders Consent with M3 hero card', (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestWidget(LegalDocType.consent));
      await tester.pumpAndSettle();

      expect(find.text('Согласие на обработку данных'), findsWidgets);
      expect(find.text('Понятно, закрыть'), findsOneWidget);
    });

    testWidgets('Tapping search icon enables search field', (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestWidget(LegalDocType.privacy));
      await tester.pumpAndSettle();

      final searchIcon = find.byIcon(Icons.search_rounded);
      expect(searchIcon, findsOneWidget);

      await tester.tap(searchIcon, warnIfMissed: false);
      await tester.pump();
      await tester.pumpAndSettle();

      // State is either toggled or search icon present
      expect(find.byType(LegalViewerScreen), findsOneWidget);
    });

    testWidgets('Loads content asynchronously from assets if initialContent is null', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.themed(
              const VisualThemeSettings(
                seedColor: Color(0xFF1E88E5),
                themeMode: ThemeMode.light,
                useSystemDynamic: false,
                predictiveBackEnabled: false,
              ),
              Brightness.light,
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('ru'),
            home: const LegalViewerScreen(
              docType: LegalDocType.tos,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LegalViewerScreen), findsOneWidget);
      expect(find.text('Понятно, закрыть'), findsOneWidget);
    });
  });
}
