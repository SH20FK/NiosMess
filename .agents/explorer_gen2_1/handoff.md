# Handoff Report: UI, Routing, and Screen Audit of pulse_flutter

## 1. Observation

### 1.1 Authentication & Onboarding Screens (`lib/screens/` & `lib/widgets/`)
- **`lib/screens/login_screen.dart`**:
  - Implements the unified M3 Expressive Nios ID Auth Hub.
  - **Layout constraints**: `ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480))` (line 242) for desktop and mobile responsive centering.
  - **Hero Header**: Brand squircle badge with `Icons.all_inclusive_rounded`, typography using `GoogleFonts.unbounded(fontSize: 32, fontWeight: FontWeight.w800)` and subtitle in `GoogleFonts.inter` (lines 280–335).
  - **Ecosystem Benefits Card**: Elevated `surfaceContainerLow` container with rounded 24dp corners and 3 distinct pillars (lines 338–395):
    1. Unified Nios ID Account (`Icons.badge_outlined`, `primaryContainer`, line 352)
    2. End-to-End E2EE Encryption (`Icons.lock_outline_rounded`, `secondaryContainer`, line 368)
    3. Privacy / Zero Password Transmission (`Icons.shield_outlined`, `tertiaryContainer`, line 384)
  - **Primary Action**: 56dp height pill button with 28dp radius (`FilledButton` with `RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))`) labeled «Войти через Nios ID» with `Icons.vpn_key_rounded` (lines 448–487).
  - **Secondary Action**: «Создать аккаунт Nios ID» text button triggering `OAuthNavigationHelper().openRegistration()` (lines 489–511).
  - **Legal Footer**: Responsive links to `/legal/terms` («Условия использования») and `/legal/privacy` («Политика конфиденциальности») (lines 513–572).
  - **Loading Overlay**: Backdrop blur overlay with `PulseLoadingIndicator` and status text «Авторизация в Nios ID...» (lines 574–618).
  - **Elimination of local credentials**: Zero `TextField` or `TextFormField` widgets exist in `login_screen.dart`.
  - **Identified Defects in `login_screen.dart`**:
    - Line 592: `color: Colors.black.withValues(alpha: 0.1),` uses forbidden hardcoded `Colors.black` token (violates `AGENTS.md` zero `Colors.black` rule; should use `scheme.shadow.withValues(alpha: 0.1)`).
    - Line 184: `final String loginUrl = '/id/login?next=';` forgets to append `Uri.encodeComponent(next)`, causing `next` at line 182 to trigger analyzer warning `unused_local_variable`.
    - Line 156: `AppToast.showError(context, 'Ошибка авторизации: ');` is missing the interpolated exception parameter `$e`.
    - Line 216: `AppToast.showError(context, 'Не удалось открыть Nios ID: ');` is missing the interpolated exception parameter `$e`.
    - Line 2: `import 'package:flutter/foundation.dart';` is unused.

- **`lib/screens/register_screen.dart`**:
  - Consolidated as a direct wrapper returning `const LoginScreen()` (lines 1–13).

- **Legacy Screens and Widgets Still Present**:
  - `lib/screens/reset_password_request_screen.dart`: Contains `M3AuthTextField` for email input and password reset dispatch.
  - `lib/screens/reset_password_confirm_screen.dart`: Contains `_passwordController`, `M3AuthTextField` with `obscureText: _hidePassword`, and password visibility toggle.
  - `lib/screens/verify_email_screen.dart`: Contains `_codeController` and `CodePreview` for 6-digit OTP verification.
  - `lib/screens/two_fa_screen.dart`: Contains `_M3NumericKeypad` and 6-dot PIN shape indicators.
  - `lib/widgets/m3_auth_text_field.dart`: Auth text field widget.
  - `lib/widgets/m3_otp_input_field.dart`: OTP input widget.
  - `lib/widgets/m3_resend_countdown_timer.dart`: Resend countdown timer widget.

- **`lib/screens/onboarding_screen.dart` & `lib/screens/setup_onboarding_screen.dart`**:
  - `OnboardingScreen`: 3-slide carousel using `PageView.builder`, `Lottie` animations, 28dp pill buttons («Создать аккаунт» / «Войти»), routes to `/register` and `/login`.
  - `SetupOnboardingScreen`: 3-step post-auth onboarding (Welcome, Language selection, Timezone configuration). Complies with M3 Expressive tokens and `.withValues(alpha:)`.

- **`lib/screens/legal_viewer_screen.dart`**:
  - Implements M3 Expressive Legal Reader for `LegalDocType.privacy`, `LegalDocType.tos`, and `LegalDocType.consent`.
  - Responsive header, reading time estimation, section quick-jump chips, search bar, and GDPR/E2EE badges.
  - Strict compliance with `colorScheme.*`, zero `Colors.white`/`Colors.black`, zero `withOpacity()`.

### 1.2 Router Configuration (`lib/router/app_router.dart`)
- **Route Definitions**:
  - `/login`: Maps to `LoginScreen` (extracts query params: `code`, `state`, `error`, `error_description`).
  - `/web`: Maps to `LoginScreen` (extracts query params: `code`, `state`, `error`, `error_description`).
  - `/register`: Maps to `LoginScreen` (extracts query params).
  - `/legal/privacy`, `/legal/terms`, `/legal/tos`, `/legal/consent`: Map to `LegalViewerScreen`.
- **Legacy Route Registrations**:
  - `/verify-email` (line 132), `/2fa` (line 136), `/reset-password/request` (line 140), `/reset-password/confirm` (line 144) are currently defined as distinct `GoRoute`s rendering the legacy screens rather than redirecting to `/login`.
  - In `redirect` guard (line 76), public paths list still contains `path.startsWith('/reset-password') || path.startsWith('/verify-email') || path.startsWith('/2fa')`.
- **Address Bar Query Parameter Interception & Sanitization**:
  - `LoginScreen._checkOAuthReturn()` calls `OAuthNavigationHelper().sanitizeAddressBar()` immediately upon detecting query parameters before token exchange.
  - In `lib/core/network/oauth_navigation_helper_web.dart:17`: Calls `html.window.history.replaceState(null, html.document.title ?? '', path)`.
  - Static analysis warning on line 17: `dead_null_aware_expression` on `html.document.title ?? ''` because `html.document.title` is non-nullable `String`.
- **Unused Import**:
  - `lib/router/app_router.dart:21`: `import 'package:pulse_flutter/screens/register_screen.dart';` is unused because `/register` instantiates `LoginScreen` directly.

### 1.3 Strict Style & Design System Audit
- **`Colors.white` & `Colors.black`**:
  - Zero `Colors.white` in `login_screen.dart` and `legal_viewer_screen.dart`.
  - 1 violation in `login_screen.dart:592` (`Colors.black.withValues(alpha: 0.1)`).
- **`.withOpacity()`**:
  - Exactly 0 instances found across all `lib/` Dart files. All transparency uses modern `.withValues(alpha:)`.
- **`dart:io` Imports**:
  - Exactly 0 imports of `dart:io` found in `lib/`. (Only referenced in string literal in `ws_stub.dart`).

### 1.4 Test Suite & Static Analysis Audit
- **`flutter test` execution**:
  - Output: `00:42 +299: All tests passed!` (299 unit, widget, and integration tests passed).
  - Key suites verified:
    - `test/screens/login_screen_test.dart` (5 tests passing: M3 hero, 3 pillars, pill button, 480dp width, error handling, legal links, zero credential text fields).
    - `test/screens/register_screen_test.dart` (1 test passing: delegates to Auth Hub).
    - `test/onboarding_screens_test.dart` (8 tests passing: carousel & setup wizard).
    - `test/legal_viewer_screen_test.dart` (5 tests passing: Privacy, Terms, Consent).
    - `test/integration/e2e_auth_flow_test.dart` & `test/integration/e2e_cold_start_and_logout_test.dart` (250+ tests passing).
    - `test/verification_screens_test.dart` (4 tests passing, but tests legacy 2FA, Verify Email, and Reset Password screens).
- **`flutter analyze` execution**:
  - Exited with 8 warnings:
    1. `lib/core/network/oauth_navigation_helper_web.dart:17` — dead_code / dead_null_aware_expression on `html.document.title ?? ''`
    2. `lib/router/app_router.dart:21` — unused_import `register_screen.dart`
    3. `lib/screens/login_screen.dart:2` — unused_import `flutter/foundation.dart`
    4. `lib/screens/login_screen.dart:182` — unused_local_variable `next`
    5. `test/screens/login_screen_test.dart:7` — unused_import `auth_provider.dart`
    6. `test/stress/pkce_stress_test.dart:2` — unused_import `dart:math`
    7. `test/verification_screens_test.dart:127` — unused_local_variable `submittedCode`

---

## 2. Logic Chain

1. **OAuth 2.0 PKCE Specification**: Under NIOSMESS_FRONTEND_LOGIN.md and ORIGINAL_REQUEST.md, NiosMess authenticates exclusively through Nios ID PKCE OAuth. All password handling, 2FA, email verification, and registration occur on the central Nios ID portal (`https://ni-os.ru`).
2. **Auth Hub Implementation**: `LoginScreen` accurately realizes the M3 Expressive Auth Hub with responsive 480dp width, 3 ecosystem pillars, 56dp pill button, legal reader links, and parameter sanitization.
3. **Legacy Screen Status**: Because credential management is centralized, `reset_password_request_screen.dart`, `reset_password_confirm_screen.dart`, `two_fa_screen.dart`, and `verify_email_screen.dart` are obsolete. In `app_router.dart`, routes `/verify-email`, `/2fa`, `/reset-password/*` should redirect directly to `/login` per PROJECT.md Feature 25.
4. **Design Token Compliance**: `login_screen.dart:592` contains a single `Colors.black` instance that must be replaced with `scheme.shadow` or `scheme.scrim` to strictly adhere to AGENTS.md.
5. **Static Analysis & Sanitization**: `login_screen.dart` has missing string interpolation on `loginUrl` (`next`), and `oauth_navigation_helper_web.dart` has an unneeded null check on `html.document.title`. Fixing these 8 warnings will achieve the required 0 analyzer issues.

---

## 3. Caveats

- **Legacy Screen Retention**: While the legacy screen files still exist in the file tree, `LoginScreen` and `RegisterScreen` do not import or depend on them.
- **Platform Web Libraries**: `dart:html` in `oauth_navigation_helper_web.dart` is appropriately guarded behind conditional compilation via `oauth_navigation_helper_stub.dart` and `oauth_navigation_helper.dart`.

---

## 4. Conclusion

The UI, routing, and screen architecture in `pulse_flutter` is strongly aligned with the M3 Expressive Nios ID specification:
- The Unified Auth Hub (`LoginScreen`) correctly implements all required visual pillars, responsive centering, 56dp pill button, legal links, and address bar query parameter sanitization.
- The test suite is extensive and functional (299/299 tests passing).
- Actionable polish items identified for downstream implementation:
  1. **Token Fix**: Replace `Colors.black.withValues(alpha: 0.1)` in `login_screen.dart:592` with `scheme.shadow.withValues(alpha: 0.1)`.
  2. **URL Fix in `login_screen.dart:184`**: Interpolate `next` query parameter in `loginUrl = '/id/login?next=${Uri.encodeComponent(next)}'`.
  3. **Toast Strings in `login_screen.dart`**: Add missing `$e` in catch blocks (lines 156, 216).
  4. **Route Consolidation in `app_router.dart`**: Redirect legacy routes (`/register`, `/verify-email`, `/2fa`, `/reset-password/*`) to `/login`.
  5. **Analyzer Cleanup**: Resolve all 8 unused imports/variables across `app_router.dart`, `login_screen.dart`, `oauth_navigation_helper_web.dart`, and test files.

---

## 5. Verification Method

To independently verify these findings:

1. **Run Unit & Widget Tests**:
   ```powershell
   cd 'f:\Niosmess V2\pulse_flutter'
   flutter test
   ```
2. **Run Static Analysis**:
   ```powershell
   cd 'f:\Niosmess V2\pulse_flutter'
   flutter analyze
   ```
3. **Inspect Key Source Locations**:
   - Auth Hub: `f:\Niosmess V2\pulse_flutter\lib\screens\login_screen.dart` (lines 242, 338, 448, 513, 592)
   - Router: `f:\Niosmess V2\pulse_flutter\lib\router\app_router.dart` (lines 76–146)
   - Web Sanitization: `f:\Niosmess V2\pulse_flutter\lib\core\network\oauth_navigation_helper_web.dart` (lines 14–19)
