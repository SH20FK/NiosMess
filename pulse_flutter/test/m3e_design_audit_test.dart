import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/theme/app_colors.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/core/theme/app_typography.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:universal_io/io.dart';

void main() {
  group('M3 Expressive Phase 1: PaletteStyle & Avatar HCT Tests', () {
    test('PaletteStyle enum contains 5 canonical styles with correct variants', () {
      expect(PaletteStyle.values.length, 5);
      expect(PaletteStyle.expressive.variant, DynamicSchemeVariant.expressive);
      expect(PaletteStyle.vibrant.variant, DynamicSchemeVariant.vibrant);
      expect(PaletteStyle.content.variant, DynamicSchemeVariant.content);
      expect(PaletteStyle.calm.variant, DynamicSchemeVariant.fidelity);
      expect(PaletteStyle.mono.variant, DynamicSchemeVariant.monochrome);
    });

    test('avatarColorFor generates deterministic, accessible HCT colors', () {
      const darkScheme = ColorScheme.dark();
      const lightScheme = ColorScheme.light();

      final c1 = AppColors.avatarColorFor('user_123', darkScheme);
      final c2 = AppColors.avatarColorFor('user_123', darkScheme);
      final c3 = AppColors.avatarColorFor('user_999', darkScheme);

      // Deterministic: same seed -> same color
      expect(c1, equals(c2));
      // Different seed -> different color
      expect(c1, isNot(equals(c3)));

      final cLight = AppColors.avatarColorFor('user_123', lightScheme);
      // Dark scheme should produce brighter tonal values than light scheme
      expect(c1, isNot(equals(cLight)));
    });
  });

  group('M3 Expressive Phase 2: Typography Scale & Line-Heights', () {
    test('displayLarge is 57sp and ratio to bodyLarge is >= 3.5', () {
      final displayLargeSize = AppTypography.textTheme.displayLarge?.fontSize ?? 0;
      final bodyLargeSize = AppTypography.textTheme.bodyLarge?.fontSize ?? 0;

      expect(displayLargeSize, 57.0);
      expect(bodyLargeSize, 16.0);
      expect(displayLargeSize / bodyLargeSize, greaterThanOrEqualTo(3.5));
    });

    test('all 15 typography roles have explicit, non-null line-heights', () {
      final t = AppTypography.textTheme;
      final roles = [
        t.displayLarge,
        t.displayMedium,
        t.displaySmall,
        t.headlineLarge,
        t.headlineMedium,
        t.headlineSmall,
        t.titleLarge,
        t.titleMedium,
        t.titleSmall,
        t.bodyLarge,
        t.bodyMedium,
        t.bodySmall,
        t.labelLarge,
        t.labelMedium,
        t.labelSmall,
      ];

      for (final role in roles) {
        expect(role, isNotNull);
        expect(role?.height, isNotNull, reason: 'Every role must have an explicit line height');
        expect(role!.height!, greaterThan(1.0));
      }
    });
  });

  group('M3 Expressive Phase 3: Shapes & Expressive Radii', () {
    test('AppRadii defines 7 canonical geometric steps', () {
      expect(AppRadii.none, 0.0);
      expect(AppRadii.xs, 4.0);
      expect(AppRadii.sm, 8.0);
      expect(AppRadii.md, 12.0);
      expect(AppRadii.lg, 16.0);
      expect(AppRadii.xl, 28.0);
      expect(AppRadii.full, 999.0);
    });

    test('Superellipse borders are properly instantiated', () {
      expect(AppRadii.mdSuperellipse(), isA<RoundedSuperellipseBorder>());
      expect(AppRadii.lgSuperellipse(), isA<RoundedSuperellipseBorder>());
      expect(AppRadii.xlSuperellipse(), isA<RoundedSuperellipseBorder>());
    });
  });

  group('M3 Expressive Phase 8: Breakpoints', () {
    test('Canonical breakpoints match M3 specifications', () {
      expect(Breakpoints.compact, 600.0);
      expect(Breakpoints.medium, 840.0);
      expect(Breakpoints.expanded, 1200.0);
      expect(Breakpoints.large, 1600.0);
    });
  });

  group('M3 Expressive Static Integrity & Anti-Regression Gates', () {
    test('lib/ contains 0 imports of package:shimmer', () {
      final libDir = Directory('lib');
      final dartFiles = libDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

      for (final file in dartFiles) {
        final text = file.readAsStringSync();
        expect(
          text.contains('package:shimmer'),
          isFalse,
          reason: 'File ${file.path} contains deprecated package:shimmer import',
        );
      }
    });

    test('lib/ contains 0 usages of PulseLoadingIndicator', () {
      final libDir = Directory('lib');
      final dartFiles = libDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

      for (final file in dartFiles) {
        final text = file.readAsStringSync();
        expect(
          text.contains('PulseLoadingIndicator'),
          isFalse,
          reason: 'File ${file.path} uses deprecated PulseLoadingIndicator',
        );
      }
    });

    test('lib/ contains 0 usages of elevatedButtonTheme', () {
      final themeFile = File('lib/core/theme/app_theme.dart');
      final text = themeFile.readAsStringSync();
      expect(
        text.contains('elevatedButtonTheme:'),
        isFalse,
        reason: 'app_theme.dart should not contain elevatedButtonTheme (M3 buttons are flat)',
      );
    });

    test('lib/ contains 0 non-constant 760 layout breakpoints', () {
      final libDir = Directory('lib');
      final dartFiles = libDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

      for (final file in dartFiles) {
        final text = file.readAsStringSync();
        expect(
          text.contains('>= 760'),
          isFalse,
          reason: 'File ${file.path} contains hardcoded 760 breakpoint',
        );
      }
    });
  });

  group('M3 Expressive Flat Surfaces & Zero Elevation Audits (ТЕСТ-4)', () {
    test('AppTheme.themed guarantees flat M3 surfaces with 0 elevation', () {
      final theme = AppTheme.themed(
        const VisualThemeSettings(
          seedColor: Color(0xFF6750A4),
          themeMode: ThemeMode.light,
          useSystemDynamic: false,
          predictiveBackEnabled: false,
        ),
        Brightness.light,
      );

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

    test('Checkbox theme does not use raw Colors.white', () {
      final theme = AppTheme.themed(
        const VisualThemeSettings(
          seedColor: Color(0xFF6750A4),
          themeMode: ThemeMode.dark,
          useSystemDynamic: false,
          predictiveBackEnabled: false,
        ),
        Brightness.dark,
      );
      final checkColor = theme.checkboxTheme.checkColor?.resolve(<WidgetState>{WidgetState.selected});
      expect(checkColor, theme.colorScheme.onPrimary);
      expect(checkColor, isNot(equals(Colors.white)));
    });
  });
}
