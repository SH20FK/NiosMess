// ignore_for_file: avoid_print
import 'dart:io';

void main() {
  int passed = 0;
  int failed = 0;

  void report(String title, bool condition, [String? errorDetails]) {
    if (condition) {
      print('  [PASS] $title');
      passed++;
    } else {
      print('  [FAIL] $title');
      if (errorDetails != null && errorDetails.isNotEmpty) {
        print(errorDetails);
      }
      failed++;
    }
  }

  print('=== Running NiosMess UI Architecture & Modal Guard Verification ===\n');

  final Directory libDir = Directory('lib');
  if (!libDir.existsSync()) {
    print('Error: lib/ directory not found. Please run from pulse_flutter root.');
    exit(1);
  }

  final List<File> dartFiles = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  print('Scanned ${dartFiles.length} Dart source files in lib/...\n');

  // 1. Raw Modal Bottom Sheet Check
  final List<String> rawModalSheetViolations = <String>[];
  for (final File file in dartFiles) {
    final String normalized = file.path.replaceAll(r'\', '/');
    if (normalized.contains('/core/modal/') ||
        normalized.endsWith('app_bottom_sheets.dart')) {
      continue;
    }
    final String content = file.readAsStringSync();
    if (content.contains('showModalBottomSheet(')) {
      rawModalSheetViolations.add(file.path);
    }
  }
  report(
    'Zero raw showModalBottomSheet() outside core/modal/',
    rawModalSheetViolations.isEmpty,
    rawModalSheetViolations.map((p) => '    Violation: $p').join('\n'),
  );

  // 2. Raw General Dialog Check
  final List<String> rawGeneralDialogViolations = <String>[];
  for (final File file in dartFiles) {
    final String normalized = file.path.replaceAll(r'\', '/');
    if (normalized.contains('/core/modal/')) {
      continue;
    }
    final String content = file.readAsStringSync();
    if (content.contains('showGeneralDialog(')) {
      rawGeneralDialogViolations.add(file.path);
    }
  }
  report(
    'Zero raw showGeneralDialog() outside core/modal/',
    rawGeneralDialogViolations.isEmpty,
    rawGeneralDialogViolations.map((p) => '    Violation: $p').join('\n'),
  );

  // 3. Raw AlertDialog Check
  final List<String> alertDialogViolations = <String>[];
  for (final File file in dartFiles) {
    final String normalized = file.path.replaceAll(r'\', '/');
    if (normalized.contains('/core/modal/')) {
      continue;
    }
    final String content = file.readAsStringSync();
    if (content.contains('AlertDialog(')) {
      alertDialogViolations.add(file.path);
    }
  }
  report(
    'Zero AlertDialog() in production feature code',
    alertDialogViolations.isEmpty,
    alertDialogViolations.map((p) => '    Violation: $p').join('\n'),
  );

  // 4. Raw showDialog Check
  final List<String> showDialogViolations = <String>[];
  for (final File file in dartFiles) {
    final String normalized = file.path.replaceAll(r'\', '/');
    if (normalized.contains('/core/modal/') ||
        normalized.endsWith('app_dialogs.dart')) {
      continue;
    }
    final String content = file.readAsStringSync();
    if (content.contains('showDialog(')) {
      showDialogViolations.add(file.path);
    }
  }
  report(
    'Zero raw showDialog() outside core/modal/ and app_dialogs.dart',
    showDialogViolations.isEmpty,
    showDialogViolations.map((p) => '    Violation: $p').join('\n'),
  );

  // 5. Live Blur / BackdropFilter Check
  final List<String> backdropFilterViolations = <String>[];
  for (final File file in dartFiles) {
    final String normalized = file.path.replaceAll(r'\', '/');
    // BackdropFilter is forbidden across all repeating UI, tiles, and modals.
    // AdaptiveGlass is the only strictly bounded container for Tier A static panels.
    if (normalized.contains('/widgets/') &&
        !normalized.endsWith('adaptive_glass.dart')) {
      final String content = file.readAsStringSync();
      if (content.contains('BackdropFilter(')) {
        backdropFilterViolations.add(file.path);
      }
    }
  }
  report(
    'Zero BackdropFilter() in widgets/ (except bounded AdaptiveGlass Tier A)',
    backdropFilterViolations.isEmpty,
    backdropFilterViolations.map((p) => '    Violation: $p').join('\n'),
  );

  // 6. AI Layer Unification Check
  final File aiActionFile = File('lib/core/ai/ai_action.dart');
  report(
    'Canonical AiAction model exists in core/ai/',
    aiActionFile.existsSync(),
  );

  final File aiQuotaFile = File('lib/models/api/ai_quota_model.dart');
  report(
    'Canonical AiQuota model exists (characters/letters quota flow)',
    aiQuotaFile.existsSync(),
  );

  // 7. Token Naming Unification Check
  final File tokenProviderFile = File('lib/providers/token_provider.dart');
  final bool hasSessionTokenProvider = tokenProviderFile.existsSync() &&
      tokenProviderFile.readAsStringSync().contains('sessionAccessTokenProvider');
  report(
    'sessionAccessTokenProvider exists to prevent AI token confusion',
    hasSessionTokenProvider,
  );

  // 8. Desktop Split Motion Contract Check
  final File mainShellFile = File('lib/screens/main_shell_screen.dart');
  final String mainShellContent = mainShellFile.readAsStringSync();
  final bool hasDesktopSplitMotion = mainShellContent.contains('AnimatedSwitcher(') &&
      mainShellContent.contains('M3SpringCurves.expressiveDecel');
  report(
    'Desktop split right panel has local AnimatedSwitcher with expressiveDecel',
    hasDesktopSplitMotion,
  );

  // 9. Bottom Nav Motion Contract Check
  final File bottomNavFile = File('lib/widgets/app_bottom_nav.dart');
  final String bottomNavContent = bottomNavFile.readAsStringSync();
  final bool hasMonotonicIndicator = bottomNavContent.contains('M3SpringCurves.expressiveDecel') &&
      !bottomNavContent.contains('math.sin(math.pi * _controller.value');
  report(
    'Bottom nav traveling indicator uses in-phase monotonic expressiveDecel',
    hasMonotonicIndicator,
  );

  // 10. Chat Route Symmetrical Duration Check
  final File appRouterFile = File('lib/router/app_router.dart');
  final String appRouterContent = appRouterFile.readAsStringSync();
  final bool hasSymmetricalChatRoute = appRouterContent.contains('reverseTransitionDuration: const Duration(milliseconds: 240)');
  report(
    'Chat route uses symmetrical 240ms forward and reverse transitions',
    hasSymmetricalChatRoute,
  );

  print('\n=== Summary ===');
  print('Passed: $passed / ${passed + failed}');
  if (failed > 0) {
    print('FAILED: $failed architecture checks failed.');
    exit(1);
  } else {
    print('SUCCESS: All UI architecture checks passed cleanly.');
    exit(0);
  }
}
