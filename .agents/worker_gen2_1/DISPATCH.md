## 2026-09-01T12:02:35Z

Tasks to implement in `f:\Niosmess V2\pulse_flutter`:
1. `lib/screens/login_screen.dart`:
   - Remove unused import `import 'package:flutter/foundation.dart';`.
   - Line 156: In catch block, interpolate error: `AppToast.showError(context, 'Ошибка авторизации: $e');`.
   - Line 184: Fix URL interpolation: `final String loginUrl = '/id/login?next=${Uri.encodeComponent(next)}';`.
   - Line 216: In catch block, interpolate error: `AppToast.showError(context, 'Не удалось открыть Nios ID: $e');`.
   - Line 592: Replace forbidden hardcoded `Colors.black.withValues(alpha: 0.1)` with `scheme.shadow.withValues(alpha: 0.1)` to strictly respect AGENTS.md.
2. `lib/core/network/oauth_navigation_helper_web.dart`:
   - Line 17: Replace `html.window.history.replaceState(null, html.document.title ?? '', path);` with `html.window.history.replaceState(null, html.document.title, path);`.
   - Line 24: Fix `https://ni-os.ru/id/register?next=${Uri.encodeComponent(nextUrl)}`.
3. `lib/core/network/oauth_navigation_helper_stub.dart`:
   - Line 21: Fix `https://ni-os.ru/id/register?next=${Uri.encodeComponent(nextUrl)}`.
4. `lib/router/app_router.dart`:
   - Remove unused import `import 'package:pulse_flutter/screens/register_screen.dart';`.
   - Consolidate legacy routes (`/register`, `/verify-email`, `/2fa`, `/reset-password/*`) so they redirect cleanly to `/login` or render `LoginScreen()`.
5. Test cleanup:
   - `test/screens/login_screen_test.dart:7`: Remove unused import `import 'package:pulse_flutter/providers/auth_provider.dart';`.
   - `test/stress/pkce_stress_test.dart:2`: Remove unused import `import 'dart:math';`.
   - `test/verification_screens_test.dart:127`: Remove unused local variable `submittedCode`.
6. Automated Semantic Versioning:
   - In `pulse_flutter/pubspec.yaml`, bump version from `3.5.0+7` to `3.6.0+8` (MINOR bump for Unified Nios ID OAuth 2.0 PKCE Auth Hub per AGENTS.md).
7. Verification:
   - Run `flutter analyze` from `f:\Niosmess V2\pulse_flutter` and verify 0 issues found.
   - Run `flutter test` from `f:\Niosmess V2\pulse_flutter` and verify 100% tests pass (299+ tests).
