import 'dart:io';
// ignore: depend_on_referenced_packages
import 'package:test/test.dart';

void main() {
  group('Entry Screens Reachability (Phase 1)', () {
    final File routerFile = File('lib/router/app_router.dart');
    final File authProviderFile = File('lib/providers/auth_provider.dart');

    test('verifies router and auth provider files exist', () {
      expect(routerFile.existsSync(), isTrue);
      expect(authProviderFile.existsSync(), isTrue);
    });

    test('verifies dead screen files are completely removed from filesystem', () {
      const List<String> deadFiles = <String>[
        'lib/screens/verify_email_screen.dart',
        'lib/screens/two_fa_screen.dart',
        'lib/screens/reset_password_request_screen.dart',
        'lib/screens/reset_password_confirm_screen.dart',
        'lib/screens/register_screen.dart',
        'lib/screens/setup_onboarding_screen.dart',
      ];

      for (final String path in deadFiles) {
        expect(
          File(path).existsSync(),
          isFalse,
          reason: '$path should be deleted in Phase 1',
        );
      }
    });

    test('verifies redirect stubs are removed from app_router.dart', () {
      final String routerContent = routerFile.readAsStringSync();

      const List<String> stubRoutes = <String>[
        '/verify-email',
        '/2fa',
        '/reset-password/request',
        '/reset-password/confirm',
        '/setup',
      ];

      for (final String route in stubRoutes) {
        expect(
          routerContent.contains("path: '$route'"),
          isFalse,
          reason: 'Stub route $route must not exist in app_router.dart',
        );
      }
    });

    test('verifies insecure _pendingPassword and requiresTwoFa are removed from auth_provider', () {
      final String content = authProviderFile.readAsStringSync();
      expect(content.contains('_pendingPassword'), isFalse);
      expect(content.contains('_pendingEmail'), isFalse);
      expect(content.contains('requiresTwoFa'), isFalse);
    });

    test('verifies unified AuthScaffold and AuthPrimaryButton exist with 440dp width token (Phase 3)', () {
      final File scaffoldFile = File('lib/widgets/auth/auth_scaffold.dart');
      expect(scaffoldFile.existsSync(), isTrue);
      final String content = scaffoldFile.readAsStringSync();
      expect(content.contains('kAuthFormMaxWidth = 440.0'), isTrue);
      expect(content.contains('class AuthPrimaryButton'), isTrue);
      expect(content.contains('class AuthScaffold'), isTrue);
    });
  });
}
