import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/screens/register_screen.dart';

Widget _createRegisterHarness() {
  final effectiveTheme = AppTheme.themed(
    const VisualThemeSettings(
      seedColor: Color(0xFF1E88E5),
      themeMode: ThemeMode.light,
      useSystemDynamic: false,
      predictiveBackEnabled: false,
    ),
    Brightness.light,
  );

  return ProviderScope(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: effectiveTheme,
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const RegisterScreen(),
    ),
  );
}

void main() {
  group('RegisterScreen Consolidation Tests', () {
    testWidgets('renders unified Nios ID auth hub on /register route', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_createRegisterHarness());
      await tester.pumpAndSettle();

      expect(find.text('NiosMess'), findsOneWidget);
      expect(find.text('Войти через Nios ID'), findsOneWidget);
      expect(find.text('Создать аккаунт Nios ID'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });
  });
}
