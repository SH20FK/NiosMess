import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

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

    test('verifies splash screen optimizations and hygiene (Phase 4)', () {
      final File splashFile = File('lib/screens/splash_screen.dart');
      expect(splashFile.existsSync(), isTrue);
      final String content = splashFile.readAsStringSync();

      // Uses M3OrganicBackground instead of AnimatedMeshBackground
      expect(content.contains('M3OrganicBackground'), isTrue);
      expect(content.contains('AnimatedMeshBackground'), isFalse);

      // Deferred permissions: no PermissionService in splash
      expect(content.contains('PermissionService'), isFalse);

      // Unified Hero logo tag
      expect(content.contains("'app_brand_logo'"), isTrue);

      // No 24-second infinite animation controller or hidden BackdropFilter hack
      expect(content.contains('Duration(seconds: 24)'), isFalse);
      expect(content.contains('ImageFilter.blur'), isFalse);
    });

    test('verifies login screen M3 Expressive modernization (Phase 5)', () {
      final loginFile = File('lib/screens/login_screen.dart');
      expect(loginFile.existsSync(), isTrue);
      final content = loginFile.readAsStringSync();

      // Wrapped in AuthScaffold
      expect(content.contains('AuthScaffold'), isTrue);

      // Unified Hero brand logo
      expect(content.contains("'app_brand_logo'"), isTrue);

      // QrImageView for cross-device authorization
      expect(content.contains('QrImageView'), isTrue);

      // Countdown timer for device code expiration
      expect(content.contains('_countdownTimer'), isTrue);
      expect(content.contains('_remainingSeconds'), isTrue);

      // Offline detection via connectivityProvider
      expect(content.contains('connectivityProvider'), isTrue);

      // Nios ID explainer section
      expect(content.contains('_buildExplainerSection'), isTrue);

      // Strictly NO build version in footer (user requirement)
      expect(content.contains('BuildInfo'), isFalse);

      // Zero legacy boxShadow or MD2 elevation
      expect(content.contains('boxShadow'), isFalse);
      expect(content.contains('BoxShadow'), isFalse);

      // Motion curves: strictly M3SpringCurves, zero legacy Curves
      expect(content.contains('Curves.easeOutBack'), isFalse);
      expect(content.contains('Curves.easeInOut'), isFalse);
      expect(content.contains('M3SpringCurves'), isTrue);
    });

    test('verifies unified Hero logo and M3 Expressive entry transitions (Phase 6)', () {
      final splashContent = File('lib/screens/splash_screen.dart').readAsStringSync();
      final onboardingContent = File('lib/screens/onboarding_screen.dart').readAsStringSync();
      final loginContent = File('lib/screens/login_screen.dart').readAsStringSync();
      final routerContent = File('lib/router/app_router.dart').readAsStringSync();

      // Unified Hero tag across Splash -> Onboarding -> Login
      expect(splashContent.contains("'app_brand_logo'"), isTrue);
      expect(onboardingContent.contains("'app_brand_logo'"), isTrue);
      expect(loginContent.contains("'app_brand_logo'"), isTrue);

      // AppRouter uses M3Expressive transitions for entry pages
      expect(routerContent.contains('_m3eEntryPage'), isTrue);
      expect(routerContent.contains('M3SpringCurves.spatial'), isTrue);
      expect(routerContent.contains("path: '/register'"), isFalse);
    });

    test('verifies M3OrganicBackground tokens, zero elevation, and system theme (Phase 7)', () {
      final bgContent = File('lib/widgets/m3_organic_background.dart').readAsStringSync();

      // Zero legacy elevation or shadowColor
      expect(bgContent.contains('elevation: 8'), isFalse);
      expect(bgContent.contains('shadowColor'), isFalse);

      // Uses AppRadii
      expect(bgContent.contains('AppRadii.lgRadius'), isTrue);
      expect(bgContent.contains('AppRadii.fullRadius'), isTrue);

      // Supports ThemeMode.system
      expect(bgContent.contains('ThemeMode.system'), isTrue);
      expect(bgContent.contains('brightness_auto_rounded'), isTrue);

      // Semantics and Tooltip present
      expect(bgContent.contains('Tooltip('), isTrue);
      expect(bgContent.contains('Semantics('), isTrue);
    });

    test('verifies localization hygiene and zero hardcoded Cyrillic in entry funnel (Phase 8)', () {
      final splashContent = File('lib/screens/splash_screen.dart').readAsStringSync();
      final loginContent = File('lib/screens/login_screen.dart').readAsStringSync();
      final bgContent = File('lib/widgets/m3_organic_background.dart').readAsStringSync();
      final authScaffoldContent = File('lib/widgets/auth/auth_scaffold.dart').readAsStringSync();

      final cyrillicRegex = RegExp(r'[\u0410-\u044F\u0401\u0451]');
      expect(cyrillicRegex.hasMatch(splashContent), isFalse);
      expect(cyrillicRegex.hasMatch(loginContent), isFalse);
      expect(cyrillicRegex.hasMatch(bgContent), isFalse);
      expect(cyrillicRegex.hasMatch(authScaffoldContent), isFalse);

      expect(splashContent.contains('localeName.startsWith'), isFalse);
      expect(loginContent.contains('localeName.startsWith'), isFalse);

      final l10nContent = File('lib/l10n/app_localizations.dart').readAsStringSync();
      expect(l10nContent.contains('splashInitError'), isTrue);
      expect(l10nContent.contains('loginExplainerPillar1Title'), isTrue);
    });

    test('verifies background caching, hoisted platform checks, and Lottie frameRate (Phase 9)', () {
      final bgContent = File('lib/widgets/m3_organic_background.dart').readAsStringSync();
      final onboardingContent = File('lib/screens/onboarding_screen.dart').readAsStringSync();

      // Organic blobs painter caches ui.Picture
      expect(bgContent.contains('_cachedPicture'), isTrue);
      expect(bgContent.contains('ui.PictureRecorder()'), isTrue);
      expect(bgContent.contains('drawPicture'), isTrue);

      // Hoisted desktop platform check outside LayoutBuilder
      expect(bgContent.contains('_isDesktopPlatform'), isTrue);

      // Lottie asset specifies FrameRate.max and errorBuilder
      expect(onboardingContent.contains('frameRate: FrameRate.max'), isTrue);
      expect(onboardingContent.contains('errorBuilder:'), isTrue);
    });

    test('verifies all 5 audit grep-gates and a11y attributes (Phase 10)', () {
      final splashContent = File('lib/screens/splash_screen.dart').readAsStringSync();
      final onboardingContent = File('lib/screens/onboarding_screen.dart').readAsStringSync();
      final loginContent = File('lib/screens/login_screen.dart').readAsStringSync();
      final bgContent = File('lib/widgets/m3_organic_background.dart').readAsStringSync();
      final routerContent = File('lib/router/app_router.dart').readAsStringSync();

      // Gate 1: Curves in funnel are strictly M3SpringCurves
      final legacyCurvesRegex = RegExp(r'Curves\.(easeOutBack|easeInOutCubic|easeInOut|easeOut|easeOutCubic)');
      expect(legacyCurvesRegex.hasMatch(splashContent), isFalse);
      expect(legacyCurvesRegex.hasMatch(onboardingContent), isFalse);
      expect(legacyCurvesRegex.hasMatch(loginContent), isFalse);
      expect(legacyCurvesRegex.hasMatch(bgContent), isFalse);

      // Gate 2: No harsh shadows or M2 elevation
      final elevationShadowRegex = RegExp(r'boxShadow|elevation:\s*[1-9]');
      expect(elevationShadowRegex.hasMatch(loginContent), isFalse);
      expect(elevationShadowRegex.hasMatch(bgContent), isFalse);

      // Gate 3: Zero manual localeName.startsWith
      expect(splashContent.contains('localeName.startsWith'), isFalse);
      expect(loginContent.contains('localeName.startsWith'), isFalse);
      expect(onboardingContent.contains('localeName.startsWith'), isFalse);

      // Gate 4: Zero raw Russian strings in login
      final cyrillicStringRegex = RegExp(r"'[А-Яа-яЁё]");
      expect(cyrillicStringRegex.hasMatch(loginContent), isFalse);

      // Gate 5: Zero redirect stubs in router
      expect(routerContent.contains("redirect: (context, state) => '/login'"), isFalse);

      // a11y Semantics & Tooltips in login and onboarding
      expect(loginContent.contains('Semantics('), isTrue);
      expect(loginContent.contains('Tooltip('), isTrue);
      expect(onboardingContent.contains('Semantics('), isTrue);
      expect(onboardingContent.contains('tooltip:'), isTrue);
    });
  });
}
