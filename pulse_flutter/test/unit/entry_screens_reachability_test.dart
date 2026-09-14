import 'dart:io';
// ignore: depend_on_referenced_packages
import 'package:test/test.dart';

void main() {
  group('Entry Screens Reachability Baseline (Phase 0)', () {
    final File routerFile = File('lib/router/app_router.dart');

    test('verifies router file exists', () {
      expect(routerFile.existsSync(), isTrue);
    });

    test('documents dead entry screens are not imported in app_router.dart', () {
      final String routerContent = routerFile.readAsStringSync();

      const List<String> deadScreenFiles = <String>[
        'verify_email_screen.dart',
        'two_fa_screen.dart',
        'reset_password_request_screen.dart',
        'reset_password_confirm_screen.dart',
        'register_screen.dart',
      ];

      for (final String fileName in deadScreenFiles) {
        expect(
          routerContent.contains(fileName),
          isFalse,
          reason: '$fileName should not be imported in app_router.dart',
        );
      }
    });

    test('documents redirect stubs to /login exist in app_router.dart', () {
      final String routerContent = routerFile.readAsStringSync();

      const List<String> stubRoutes = <String>[
        '/verify-email',
        '/2fa',
        '/reset-password/request',
        '/reset-password/confirm',
      ];

      for (final String route in stubRoutes) {
        expect(
          routerContent.contains("path: '$route'"),
          isTrue,
          reason: 'Expected stub route $route in app_router.dart before Phase 1 cleanup',
        );
      }
    });
  });
}
