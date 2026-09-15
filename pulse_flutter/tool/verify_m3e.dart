// ignore_for_file: avoid_print
import 'dart:io';

void main() {
  int passed = 0;
  int failed = 0;

  void check(String description, bool condition) {
    if (condition) {
      print('  [PASS] $description');
      passed++;
    } else {
      print('  [FAIL] $description');
      failed++;
    }
  }

  print('=== Running Material 3 Expressive Design Audit Verification ===\n');

  // Gate 1: Check pubspec.yaml version
  final pubspec = File('pubspec.yaml').readAsStringSync();
  check('pubspec.yaml version bumped to >= 3.62.0+145', RegExp(r'version: 3\.6[2-9]\.\d+\+\d+').hasMatch(pubspec));

  // Gate 2: Check build_info.dart version
  final buildInfo = File('lib/core/constants/build_info.dart').readAsStringSync();
  check('build_info.dart version is >= 3.62.0+145', RegExp(r"version = '3\.6[2-9]\.\d+'").hasMatch(buildInfo));

  // Gate 3: Shimmer eradication
  final libFiles = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList();
  bool hasShimmer = false;
  for (final f in libFiles) {
    if (f.readAsStringSync().contains('package:shimmer')) {
      hasShimmer = true;
      print('Found shimmer in ${f.path}');
    }
  }
  check('lib/ has 0 imports of package:shimmer', !hasShimmer);

  // Gate 4: PulseLoadingIndicator eradication
  bool hasPulseLoadingIndicator = false;
  for (final f in libFiles) {
    if (f.readAsStringSync().contains('PulseLoadingIndicator')) {
      hasPulseLoadingIndicator = true;
      print('Found PulseLoadingIndicator in ${f.path}');
    }
  }
  check('lib/ has 0 usages of PulseLoadingIndicator', !hasPulseLoadingIndicator);

  // Gate 5: elevatedButtonTheme eradication in theme
  final themeContent = File('lib/core/theme/app_theme.dart').readAsStringSync();
  check('app_theme.dart has 0 elevatedButtonTheme (M3 buttons are flat)', !themeContent.contains('elevatedButtonTheme:'));
  check('app_theme.dart has filledButtonTheme', themeContent.contains('filledButtonTheme:'));
  check('app_theme.dart has outlinedButtonTheme', themeContent.contains('outlinedButtonTheme:'));
  check('app_theme.dart has textButtonTheme', themeContent.contains('textButtonTheme:'));

  // Gate 6: Breakpoints check - zero hardcoded 760 breakpoints in screens
  final screenFiles = Directory('lib/screens').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList();
  bool has760Breakpoint = false;
  for (final f in screenFiles) {
    final text = f.readAsStringSync();
    if (text.contains('>= 760') || text.contains('> 760')) {
      has760Breakpoint = true;
      print('Found 760 breakpoint in ${f.path}');
    }
  }
  check('lib/screens/ has 0 non-constant 760 layout breakpoints', !has760Breakpoint);

  // Gate 7: Dead files eradication
  check('lib/widgets/centered_note.dart is deleted', !File('lib/widgets/centered_note.dart').existsSync());
  check('lib/widgets/chat/md3_squiggle_progress.dart is deleted', !File('lib/widgets/chat/md3_squiggle_progress.dart').existsSync());
  check('lib/widgets/animated_background_blobs.dart is deleted', !File('lib/widgets/animated_background_blobs.dart').existsSync());
  check('lib/widgets/animated_mesh_background.dart is deleted', !File('lib/widgets/animated_mesh_background.dart').existsSync());
  check('lib/widgets/adaptive/adaptive_mesh_background.dart is deleted', !File('lib/widgets/adaptive/adaptive_mesh_background.dart').existsSync());
  check('lib/widgets/adaptive/adaptive_organic_background.dart is deleted', !File('lib/widgets/adaptive/adaptive_organic_background.dart').existsSync());

  // Gate 8: Clean dialog elevation in chat_creation_surfaces.dart
  final chatCreationContent = File('lib/widgets/chat_creation_surfaces.dart').readAsStringSync();
  check('chat_creation_surfaces.dart dialog has elevation 0', chatCreationContent.contains('elevation: 0'));

  // Gate 9: Clean box shadow in main_shell_screen.dart
  final mainShellContent = File('lib/screens/main_shell_screen.dart').readAsStringSync();
  check('main_shell_screen.dart chat bubble icon has no BoxShadow', !mainShellContent.contains('BoxShadow('));

  // Gate 10: AppRadii 7 steps verified in expressive_tokens.dart
  final tokensContent = File('lib/core/theme/expressive_tokens.dart').readAsStringSync();
  check('AppRadii has none (0.0)', tokensContent.contains('static const double none = 0.0;'));
  check('AppRadii has xs (4.0)', tokensContent.contains('static const double xs = 4.0;'));
  check('AppRadii has sm (8.0)', tokensContent.contains('static const double sm = 8.0;'));
  check('AppRadii has md (12.0)', tokensContent.contains('static const double md = 12.0;'));
  check('AppRadii has lg (16.0)', tokensContent.contains('static const double lg = 16.0;'));
  check('AppRadii has xl (28.0)', tokensContent.contains('static const double xl = 28.0;'));
  check('AppRadii has full (999.0)', tokensContent.contains('static const double full = 999.0;'));

  // Gate 11: Breakpoints class in expressive_tokens.dart
  check('Breakpoints has compact 600.0', tokensContent.contains('static const double compact = 600.0;'));
  check('Breakpoints has medium 840.0', tokensContent.contains('static const double medium = 840.0;'));
  check('Breakpoints has expanded 1200.0', tokensContent.contains('static const double expanded = 1200.0;'));
  check('Breakpoints has large 1600.0', tokensContent.contains('static const double large = 1600.0;'));

  // Gate 12: AppTypography scale 57sp in app_typography.dart
  final typoContent = File('lib/core/theme/app_typography.dart').readAsStringSync();
  check('AppTypography displayLarge is 57sp', typoContent.contains('fontSize: 57'));
  check('AppTypography bodyLarge is 16sp', typoContent.contains('fontSize: 16'));

  print('\n=== Summary: $passed passed, $failed failed ===');
  if (failed > 0) {
    exit(1);
  } else {
    print('ALL MATERIAL 3 EXPRESSIVE AUDIT GATES PASSED! ✅');
  }
}
