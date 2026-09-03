# Material 3 Expressive Auth & Onboarding Survey Report (Explorer 2)

## Executive Summary
This survey provides an in-depth architectural and visual investigation of the authentication subsystem within `pulse_flutter`, focusing specifically on `login_screen.dart`, `register_screen.dart`, supporting providers, form validation, biometric authentication triggers, OAuth quick-access tiles, router transitions in `app_router.dart`, and alignment with Android 15 / Google Messages Material 3 Expressive design specifications.

---

## 1. Investigation of `login_screen.dart` & `register_screen.dart`

### 1.1 `LoginScreen` (`lib/screens/login_screen.dart`)
- **Structure & Lifecycle**:
  - `ConsumerStatefulWidget` managing form state with `_formKey = GlobalKey<FormState>()`.
  - Controllers: `_identifierController` (Username/Email) and `_passwordController`.
  - State flags: `_hidePassword` (visibility toggle), `_isBiometricSupported`, and `_isBiometricEnabled`.
  - `initState()` asynchronously queries `BiometricService` via `ref.read(biometricServiceProvider)` to dynamically enable/disable the Biometric Quick Login tile.
  - Proper lifecycle disposal of both text controllers in `dispose()`.
- **Form Submission Flow (`_submit()`)**:
  - Triggers `_formKey.currentState!.validate()`.
  - Emits light impact haptic feedback (`HapticFeedback.lightImpact()`).
  - Trims identifier (`_identifierController.text.trim()`).
  - Calls `ref.read(authProvider.notifier).login(...)`.
  - Handles results:
    - `result.success`: Emits `HapticService.confirm()`, navigates with `context.go('/main/chats')`.
    - `result.requiresTwoFa`: Emits `HapticService.tap()`, navigates with `context.go('/2fa?identifier=${Uri.encodeComponent(identifier)}')`.
    - Failure: Emits `HapticService.destructive()`, presents error toast via `AppToast.showError(...)`.
- **Biometric Quick Login (`_handleBiometricLogin()`)**:
  - Emits `HapticService.tap()`.
  - Invokes `biometricService.authenticate(reason: context.l10n.biometricAuthReason)`.
  - On success (`authenticated == true`):
    - If already authenticated: `context.go('/main/chats')`.
    - If input fields are filled: auto-submits form via `_submit()`.
    - Otherwise: displays success toast indicating biometrics ready.
  - On cancel/failure: emits `HapticService.destructive()`.
- **Visual Composition**:
  - Top: `M3OrganicBackground` with back button (`context.pop()` or `/onboarding`) and theme mode toggle.
  - Hero Header: `AppLogoMark(size: 80)` (using `flutter_m3shapes` 9-sided cookie container) animated with 400ms fade and 0.85 -> 1.0 cubic scale.
  - Typography: `headlineMedium` (boldness `FontWeight.w900`, `letterSpacing: -0.5`), `bodyMedium` subtitle in `scheme.onSurfaceVariant`.
  - Biometric Tile (conditional): 20dp rounded squircle card with `scheme.primaryContainer.withValues(alpha: 0.5)` and 40dp icon badge.
  - Text Fields: `M3AuthTextField` with 20dp squircle outline, `surfaceContainerHighest` fill, and autofill hints.
  - OAuth Row: 3 squircle buttons (Passkey, Shield SSO, Fingerprint Biometric).
  - Submit Button: `_M3AuthSubmitButton` (56dp height, 28dp pill radius, `scheme.primary`, integrated `AppLoadingIndicator`).
  - Secondary Links: Create Account (`/register`) and Forgot Password (`/reset-password/request`).

### 1.2 `RegisterScreen` (`lib/screens/register_screen.dart`)
- **Structure & State**:
  - `ConsumerStatefulWidget` with 4 controllers: `_nameController`, `_usernameController`, `_emailController`, `_passwordController`.
  - Consent booleans: `_consentPrivacy` and `_consentToS`.
  - Password visibility state: `_hidePassword`.
- **Validation Rules**:
  - Display Name: Required (`registerNameRequired`), min length 2 (`registerDisplayNameError`).
  - Username: Required (`registerUsernameError`), min length 3 (`registerUsernameTooShort`).
  - Email: Required and must contain `@` (`registerEmailError`).
  - Password: Min length 8 (`registerPasswordError`).
  - Consents: Both `_consentPrivacy` and `_consentToS` are mandatory; failure triggers `HapticService.destructive()` and `AppToast.showError(context.l10n.registerConsentRequired)`.
- **Registration Submission Flow (`_submit()`)**:
  - Trims inputs and calls `ref.read(authProvider.notifier).register(...)`.
  - On success: Emits `HapticService.confirm()`, navigates to `/verify-email?email=${Uri.encodeComponent(email)}`.
  - On failure: Emits `HapticService.destructive()`, presents error toast.
- **Visual Composition**:
  - 4 `M3AuthTextField` inputs in vertical stack with 12dp spacing.
  - 2 `_ConsentRow` widgets featuring 28x28 checkboxes with 6dp rounded radius and clickable legal links.
  - 56dp height / 28dp radius submit pill button (`register_submit_button`).
  - Secondary link (`register_login_link`) navigating to `/login`.

---

## 2. Auth Providers, Controllers, Validation, Biometrics & OAuth

### 2.1 State Management (`lib/providers/auth_provider.dart`)
- **Architecture**:
  - Built using Riverpod 3.x `NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new)`.
  - Zero deprecated `StateNotifierProvider` or `StateProvider`.
  - Fully cross-platform via `package:universal_io/io.dart`.
- **State Properties (`AuthState`)**:
  - `hydrated: bool`: Session persistence status from `FlutterSecureStorage`.
  - `busy: bool`: Drives loading spinners on buttons and disables duplicate taps.
  - `session: AuthSession?`: Encapsulates `accessToken`, `userId`, `username`, `displayName`.
  - `pendingIdentifier: String?`: Persists context across navigation to `/2fa`.
  - `error: String?`: Last error message.
  - `profile: ApiProfile?`: Cached profile metadata.
  - `isAuthenticated`: Computed getter (`session != null && session!.accessToken.isNotEmpty`).
- **Authentication Flows**:
  - `login()`: Submits credentials over WebSocket client, saves session to secure storage, registers FCM token, and starts background service.
  - `register()`: Submits user details, caches `_pendingEmail` and `_pendingPassword` for automatic seamless sign-in once email is verified.
  - `verifyEmail()`: Verifies OTP code; if `_pendingEmail`/`_pendingPassword` are present, executes automatic login.
  - `verifyTwoFa()`: Submits 6-digit OTP code against `state.pendingIdentifier`.
  - `logout()`: Unregisters FCM token, closes WebSocket client, purges secure storage, and clears cache.

### 2.2 Biometric Service (`lib/core/services/biometric_service.dart`)
- Wraps `local_auth.LocalAuthentication` with secure persistence in `FlutterSecureStorage` under key `biometric.enabled`.
- Methods: `isDeviceSupported`, `canCheckBiometrics`, `getAvailableBiometrics()`, `authenticate()`, `authenticateIfEnabled()`.
- Provides reactive integration with login screen and settings.

### 2.3 OAuth / Quick Access Tiles
- `_OAuthIconButton` renders 52x52 squircle tiles with 16dp radius.
- Icons:
  - `Icons.key_rounded` (Passkey authentication / FIDO2)
  - `Icons.shield_outlined` (Enterprise SSO)
  - `Icons.fingerprint_rounded` (Direct biometric auth trigger)
- Background: `scheme.surfaceContainerHighest.withValues(alpha: 0.7)` with `scheme.outlineVariant.withValues(alpha: 0.25)` border.

---

## 3. Route Definitions & Transitions (`lib/router/app_router.dart`)

### 3.1 Routing Configuration & Redirect Guard
- Uses `go_router: ^17.3.0` with `refreshListenable` listening to `authProvider` state changes.
- **Redirect Guard Logic**:
  - Checks hydration: if `!authState.hydrated`, delays redirect until secure storage finishes loading.
  - Public routes whitelist: `'/'`, `'/login'`, `'/register'`, `'/onboarding'`, `'/reset-password/*'`, `'/verify-email*'`, `'/2fa*'`, `'/setup*'`, `'/legal/*'`.
  - Unauthenticated access to private route -> redirected to `'/login'`.
  - Authenticated access to auth route (`/login`, `/register`, `/onboarding`, `/setup`, `/2fa`) -> redirected to `'/main/chats'`.

### 3.2 Registered Auth & Legal Routes
```
/                   -> SplashScreen
/onboarding         -> OnboardingScreen
/login              -> LoginScreen
/register           -> RegisterScreen
/setup              -> SetupOnboardingScreen
/verify-email       -> VerifyEmailScreen(email: queryParam['email'])
/2fa                -> TwoFaScreen(identifier: queryParam['identifier'])
/reset-password/request -> ResetPasswordRequestScreen
/reset-password/confirm -> ResetPasswordConfirmScreen(email: queryParam['email'])
/legal/privacy      -> LegalViewerScreen(docType: LegalDocType.privacy)
/legal/tos          -> LegalViewerScreen(docType: LegalDocType.tos)
/legal/consent      -> LegalViewerScreen(docType: LegalDocType.consent)
```

### 3.3 Critical Route Discrepancy Found
- **Observation**:
  - In `lib/screens/register_screen.dart` line 246: `onLinkTap: () => context.push('/legal/terms')`.
  - In `lib/router/app_router.dart` line 243: Route is defined as `path: '/legal/tos'`.
  - Tests in `test/screens/register_screen_test.dart` and `test/auth_e2e_flow_test.dart` mock `/legal/terms`.
  - `lib/screens/settings_about_screen.dart` uses `context.push('/legal/tos')`.
- **Impact**: Tapping the Terms of Service link in `RegisterScreen` currently hits the catch-all `/:pathMatch(.*)` -> `Router Not Found` in production!
- **Resolution**:
  - Add alias or dual route in `app_router.dart` (`/legal/terms` redirecting to `/legal/tos` or directly rendering `LegalViewerScreen(docType: LegalDocType.tos)`), or update `register_screen.dart` to use `context.push('/legal/tos')`.

---

## 4. UI/UX Styling, Colors, Tokens & Geometry Audit

| Component | Target Spec (M3 Expressive) | Current Implementation | Status |
|---|---|---|---|
| **Logo / Brand Badge** | Organic squircle / cookie badge, 80dp | `AppLogoMark(size: 80)` using `M3Container.c9SidedCookie` | ✅ Compliant |
| **Input Fields Fill** | `surfaceContainerHighest` | `scheme.surfaceContainerHighest.withValues(alpha: 0.7)` | ✅ Compliant |
| **Input Corner Radius** | 20dp squircle geometry | `BorderRadius.circular(20)` | ✅ Compliant |
| **Input Border Normal** | `outlineVariant` subtle border | `scheme.outlineVariant.withValues(alpha: 0.25)` | ✅ Compliant |
| **Input Border Focused** | `primary` 1.6dp | `scheme.primary`, width: 1.6 | ✅ Compliant |
| **Input Border Error** | `error` 1.6dp | `scheme.error`, width: 1.6 | ✅ Compliant |
| **Submit Button Geometry**| 56dp height, 28dp pill radius | Height 56, `BorderRadius.circular(28)` | ✅ Compliant |
| **Submit Button Color** | `primary` fill, `onPrimary` text/icon | `scheme.primary`, `scheme.onPrimary` | ✅ Compliant |
| **Submit Loading State** | Integrated M3 spinner, no layout shift | `AppLoadingIndicator(size: 24, color: scheme.onPrimary)` | ✅ Compliant |
| **Biometric Quick Card** | 20dp squircle, `primaryContainer` | 20dp squircle, `scheme.primaryContainer.withValues(alpha: 0.5)` | ✅ Compliant |
| **OAuth Quick Access** | 52x52 squircle buttons (16dp radius)| 52x52, `BorderRadius.circular(16)` | ✅ Compliant |
| **Background Art** | Organic dynamic background | `M3OrganicBackground` with `_OrganicBlobsPainter` | ✅ Compliant |
| **Hardcoded Colors** | Zero `Colors.white`/`Colors.black` | Zero hardcoded colors in custom auth components | ✅ Compliant |
| **Modern Opacity** | Zero `withOpacity()` | 100% migrated to `withValues(alpha:)` | ✅ Compliant |
| **Localization** | 100% `context.l10n` strings | All labels, titles, errors use `context.l10n.*` | ✅ Compliant |

---

## 5. Design Gap Analysis vs Android 15 / Google Messages Aesthetic

1. **Brand Header & Hero Logo**:
   - Matches Google Messages expressive branding: Organic 9-sided cookie container (`AppLogoMark`), high-contrast title typography with tight tracking (`letterSpacing: -0.5`), and animated entrance curves (`flutter_animate`).
2. **Squircle Input Fields (`M3AuthTextField`)**:
   - 20dp squircle shape with `surfaceContainerHighest` fill perfectly reflects Android 15 text input guidelines.
   - Dynamic focus transitions tint both the border and prefix icon to `scheme.primary`.
   - Error states tint border and prefix icon to `scheme.error` and render localized error labels below the field.
3. **56dp Stadium Action Button**:
   - `_M3AuthSubmitButton` fulfills the 56dp height and 28dp pill radius requirement, with full width expansion and centered content.
   - Built-in loading state smoothly swaps the forward arrow icon with `AppLoadingIndicator` without layout jumping.
4. **Biometric Integration & OAuth**:
   - Biometric login tile is dynamically displayed based on hardware capability and user preferences.
   - Visual styling matches Android 15 Quick Settings / Material tiles with a dedicated 40dp icon badge and chevron.
   - OAuth row provides clean squircle entry points for Passkeys and SSO.
5. **Route Transition Polish**:
   - Currently uses default `MaterialPage` with theme-level `PredictiveBackPageTransitionsBuilder` / `FadeUpwardsPageTransitionsBuilder`.
   - Opportunity: Adding seamless shared-axis or expressive fade-through page transitions between `/login`, `/register`, `/verify-email`, `/2fa`, and `/setup` will heighten the premium feel.

---

## 6. Test Suite & Static Analysis Results

- **Unit/Widget Tests**:
  - `test/screens/login_screen_test.dart`: 8/8 tests passed ✅
  - `test/screens/register_screen_test.dart`: 8/8 tests passed ✅
  - `test/onboarding_screens_test.dart`: 10/10 tests passed ✅
  - `test/verification_screens_test.dart`: 8/8 tests passed ✅
  - Total: **34/34 tests passed 100%**.
- **Static Analysis**:
  - Zero errors and zero warnings across `lib/` (`pulse_flutter` source code).
  - Note: In legacy `test/auth_e2e_flow_test.dart`, minor constructor parameter adjustments (`isSuccess` is a getter on `AuthLoginResult`) and unused imports in test fixtures can be cleaned up during implementation.
