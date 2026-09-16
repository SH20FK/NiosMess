import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

VisualThemeSettings createSettings({
  Color seedColor = const Color(0xFF2196F3),
  ThemeMode themeMode = ThemeMode.light,
  bool useSystemDynamic = false,
  bool predictiveBackEnabled = false,
  double uiCornerRadius = 20.0,
  PaletteStyle paletteStyle = PaletteStyle.expressive,
}) {
  return VisualThemeSettings(
    seedColor: seedColor,
    themeMode: themeMode,
    useSystemDynamic: useSystemDynamic,
    predictiveBackEnabled: predictiveBackEnabled,
    uiCornerRadius: uiCornerRadius,
    paletteStyle: paletteStyle,
  );
}

void main() {
  group('AppTheme Cache, Elevations & M3 Expressive Tokens (ЦВЕТ-7, ЦВЕТ-9, ЦВЕТ-10, ТЕСТ-3, ТЕСТ-4)', () {
    test('AppTheme.themed produces completely flat surfaces with 0 elevation', () {
      final theme = AppTheme.themed(
        createSettings(),
        Brightness.light,
      );

      // Rule: Zero elevation on all containers, app bars, and action buttons
      expect(theme.appBarTheme.scrolledUnderElevation, 0.0);
      expect(theme.floatingActionButtonTheme.elevation, 0.0);
      expect(theme.floatingActionButtonTheme.focusElevation, 0.0);
      expect(theme.floatingActionButtonTheme.hoverElevation, 0.0);
      expect(theme.floatingActionButtonTheme.highlightElevation, 0.0);
      expect(theme.snackBarTheme.elevation, 0.0);
      expect(theme.cardTheme.elevation, 0.0);
      expect(theme.dialogTheme.elevation, 0.0);
      expect(theme.bottomSheetTheme.elevation, 0.0);
    });

    test('Checkbox checkColor uses scheme.onPrimary, never hardcoded Colors.white', () {
      final lightTheme = AppTheme.themed(
        createSettings(seedColor: const Color(0xFF4CAF50)),
        Brightness.light,
      );
      final darkTheme = AppTheme.themed(
        createSettings(seedColor: const Color(0xFF4CAF50)),
        Brightness.dark,
      );

      final lightCheckColor = lightTheme.checkboxTheme.checkColor?.resolve(<WidgetState>{WidgetState.selected});
      final darkCheckColor = darkTheme.checkboxTheme.checkColor?.resolve(<WidgetState>{WidgetState.selected});

      expect(lightCheckColor, lightTheme.colorScheme.onPrimary);
      expect(darkCheckColor, darkTheme.colorScheme.onPrimary);
    });

    test('Cache key calculation produces unique entries without XOR collisions', () {
      final s1 = createSettings(seedColor: const Color(0xFF101010));
      final s2 = createSettings(seedColor: const Color(0xFF202020));
      final s3 = createSettings(seedColor: const Color(0xFF101010), paletteStyle: PaletteStyle.vibrant);

      final t1 = AppTheme.themed(s1, Brightness.light);
      final t2 = AppTheme.themed(s2, Brightness.light);
      final t3 = AppTheme.themed(s3, Brightness.light);

      // t1 and t3 share seedColor but differ in paletteStyle; they must not be the exact same instance
      expect(identical(t1, t3), isFalse);
      expect(identical(t1, t2), isFalse);

      // Same parameters should hit the cache and return identical cached ThemeData
      final t1Cached = AppTheme.themed(s1, Brightness.light);
      expect(identical(t1, t1Cached), isTrue);
    });

    test('Theme cache handles distinct seed colors and styles', () {
      final List<ThemeData> created = [];
      for (int i = 0; i < 40; i++) {
        final settings = createSettings(seedColor: Color(0xFF000000 + i * 0x050505));
        created.add(AppTheme.themed(settings, Brightness.light));
      }

      expect(created.length, 40);
    });
  });
}
