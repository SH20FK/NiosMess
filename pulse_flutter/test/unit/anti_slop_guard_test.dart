import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_io/io.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

void main() {
  group('Anti-Slop Forensic Guards', () {
    test('no duplicate assets exist by SHA-256', () {
      final Directory assetsDir = Directory('assets');
      if (!assetsDir.existsSync()) return;

      final Map<String, String> seenHashes = <String, String>{};
      final List<String> duplicates = <String>[];

      for (final FileSystemEntity entity in assetsDir.listSync(recursive: true)) {
        if (entity is! File) continue;
        final String path = entity.path.replaceAll('\\', '/');

        // Allow identical codepoints for 3 MaterialSymbols variants
        if (path.endsWith('.codepoints')) continue;

        final List<int> bytes = entity.readAsBytesSync();
        final String hash = sha256.convert(bytes).toString();

        if (seenHashes.containsKey(hash)) {
          duplicates.add('$path is duplicate of ${seenHashes[hash]}');
        } else {
          seenHashes[hash] = path;
        }
      }

      expect(duplicates, isEmpty, reason: duplicates.join('\n'));
    });

    test('no fractional font sizes exist in production lib code', () {
      final Directory libDir = Directory('lib');
      final RegExp fractionalFontSize = RegExp(r'fontSize:\s*\d+\.5');
      final List<String> violations = <String>[];

      for (final FileSystemEntity entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final String content = entity.readAsStringSync();
        if (fractionalFontSize.hasMatch(content)) {
          violations.add(entity.path.replaceAll('\\', '/'));
        }
      }

      expect(violations, isEmpty, reason: 'Fractional font sizes found in: ${violations.join(', ')}');
    });

    test('no unmanaged infinite repeat in idle screens or widgets', () {
      final Directory libDir = Directory('lib');
      final RegExp repeatPattern = RegExp(r'\.repeat\(');
      final Set<String> allowlist = <String>{
        'lib/screens/calls/active_voice_call_screen.dart',
        'lib/screens/calls/incoming_call_overlay.dart',
        'lib/screens/calls/outgoing_call_screen.dart',
        'lib/screens/circle_video_recorder_screen.dart',
        'lib/widgets/chat/voice_recording_panel.dart',
      };
      final List<String> violations = <String>[];

      for (final FileSystemEntity entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final String relPath = entity.path.replaceAll('\\', '/').replaceFirst(RegExp(r'^.*?lib/'), 'lib/');
        final String content = entity.readAsStringSync();
        if (repeatPattern.hasMatch(content)) {
          if (!allowlist.contains(relPath)) {
            violations.add('$relPath contains unmanaged .repeat()');
          }
        }
      }

      expect(violations, isEmpty, reason: violations.join('\n'));
    });

    test('no BackdropFilter used outside allowlist', () {
      final Directory libDir = Directory('lib');
      final RegExp backdropPattern = RegExp(r'\bBackdropFilter\s*\(');
      final Set<String> allowlist = <String>{
        'lib/widgets/adaptive/adaptive_glass.dart',
        'lib/core/theme/app_theme.dart',
        'lib/l10n/app_localizations.dart',
        'lib/l10n/app_localizations_en.dart',
        'lib/l10n/app_localizations_ru.dart',
      };
      final List<String> violations = <String>[];

      for (final FileSystemEntity entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final String relPath = entity.path.replaceAll('\\', '/').replaceFirst(RegExp(r'^.*?lib/'), 'lib/');
        final String content = entity.readAsStringSync();
        if (backdropPattern.hasMatch(content)) {
          if (!allowlist.contains(relPath)) {
            violations.add('$relPath contains forbidden BackdropFilter');
          }
        }
      }

      expect(violations, isEmpty, reason: violations.join('\n'));
    });

    test('no raw exception interpolation in AppToast.showError', () {
      final Directory libDir = Directory('lib');
      final RegExp rawErrorPattern = RegExp(r'AppToast\.showError\([^,]+,\s*(?:[^\,\)]*\$e|error\.toString\(\)|e\.toString\(\))');
      final List<String> violations = <String>[];

      for (final FileSystemEntity entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final String relPath = entity.path.replaceAll('\\', '/').replaceFirst(RegExp(r'^.*?lib/'), 'lib/');
        final String content = entity.readAsStringSync();
        if (rawErrorPattern.hasMatch(content)) {
          violations.add('$relPath passes raw exception to AppToast.showError');
        }
      }

      expect(violations, isEmpty, reason: violations.join('\n'));
    });

    test('AppTheme defaults to standard M3 rounded control borders, not StadiumBorder', () {
      const VisualThemeSettings settings = VisualThemeSettings(
        seedColor: Color(0xFF6750A4),
        themeMode: ThemeMode.light,
        useSystemDynamic: false,
        predictiveBackEnabled: false,
      );
      final ThemeData theme = AppTheme.themed(settings, Brightness.light);

      final OutlinedBorder? filledShape = theme.filledButtonTheme.style?.shape?.resolve(<WidgetState>{});
      expect(filledShape, isNot(isA<StadiumBorder>()), reason: 'FilledButton must not be StadiumBorder');
      expect(filledShape, isA<RoundedSuperellipseBorder>());

      final OutlinedBorder? textShape = theme.textButtonTheme.style?.shape?.resolve(<WidgetState>{});
      expect(textShape, isNot(isA<StadiumBorder>()), reason: 'TextButton must not be StadiumBorder');
      expect(textShape, isA<RoundedSuperellipseBorder>());
    });

    test('VisualEffectBudget theme extension exists and defaults to restrained visual budget', () {
      const VisualThemeSettings settings = VisualThemeSettings(
        seedColor: Color(0xFF6750A4),
        themeMode: ThemeMode.light,
        useSystemDynamic: false,
        predictiveBackEnabled: false,
      );
      final ThemeData theme = AppTheme.themed(settings, Brightness.light);

      final VisualEffectBudget? budget = theme.extension<VisualEffectBudget>();
      expect(budget, isNotNull);
      expect(budget!.allowDecorativeGradient, isFalse);
      expect(budget.allowLiveBlur, isFalse);
      expect(budget.allowColoredShadow, isFalse);
      expect(budget.maxNestedSurfaces, 2);
    });

    test('AppShape semantic tokens match design budget specifications', () {
      expect(AppShape.control, 12.0);
      expect(AppShape.field, 16.0);
      expect(AppShape.card, 20.0);
      expect(AppShape.dialog, 24.0);
      expect(AppShape.media, 16.0);
      expect(AppShape.bubble, 20.0);
      expect(AppShape.pill, isA<StadiumBorder>());
    });
  });
}
