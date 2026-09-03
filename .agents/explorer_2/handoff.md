# Handoff Report — Explorer 2: Login & Registration Material 3 Expressive Investigation (R2)

## 1. Observation

### Codebase & File Locations
- **Login Screen**: `f:\Niosmess V2\pulse_flutter\lib\screens\login_screen.dart` (314 lines)
- **Registration Screen**: `f:\Niosmess V2\pulse_flutter\lib\screens\register_screen.dart` (433 lines)
- **Auth Text Field Widget**: `f:\Niosmess V2\pulse_flutter\lib\widgets\m3_auth_text_field.dart` (178 lines)
- **Auth State & Notifier**: `f:\Niosmess V2\pulse_flutter\lib\providers\auth_provider.dart` (520 lines)
- **Auth Repository**: `f:\Niosmess V2\pulse_flutter\lib\repositories\auth_repository.dart` (262 lines)
- **Biometric Service**: `f:\Niosmess V2\pulse_flutter\lib\core\services\biometric_service.dart` (67 lines)
- **App Router**: `f:\Niosmess V2\pulse_flutter\lib\router\app_router.dart` (306 lines)
- **Theme & Tokens**: `f:\Niosmess V2\pulse_flutter\lib\core\theme\app_theme.dart` (287 lines)
- **App Logo Mark**: `f:\Niosmess V2\pulse_flutter\lib\widgets\app_logo_mark.dart` (38 lines)
- **M3 Background**: `f:\Niosmess V2\pulse_flutter\lib\widgets\m3_organic_background.dart` (225 lines)
- **Localization Files**: `f:\Niosmess V2\pulse_flutter\lib\l10n\app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_ru.dart`

### Key Observations & Code Findings

1. **Brand Header & Title**:
   - `login_screen.dart` (lines 105–140): Uses hardcoded Cyrillic string splitting for title styling:
     ```dart
     Row(
       children: [
         Text('В', ...),
         M3Container(Shapes.c9_sided_cookie, width: 26, height: 26, ...),
         Text('йти', ...),
       ],
     )
     ```
     *Problem*: When running with English locale, the title still displays Cyrillic "Вйти".
   - `register_screen.dart` (lines 116–150): Uses similar hardcoded Cyrillic string splitting:
     ```dart
     Row(
       children: [
         Text('С', ...),
         M3Container(Shapes.c9_sided_cookie, width: 26, height: 26, ...),
         Text('здать', ...),
       ],
     )
     ```
   - Neither screen currently integrates the brand hero icon/logo container (`AppLogoMark` or organic hero badge).

2. **Hardcoded Strings Violating 100% L10n Rule**:
   - `login_screen.dart` line 155: `label: 'Имя пользователя'` (instead of `context.l10n.loginIdentifierLabel`).
   - `login_screen.dart` line 156: `hintText: 'Введите имя пользователя'` (instead of localized hint).
   - `login_screen.dart` line 209: `Text('Нет аккаунта?')`.
   - `register_screen.dart` line 273: `Text('Уже есть аккаунт?')`.

3. **Text Field Styling (`M3AuthTextField`)**:
   - `m3_auth_text_field.dart` uses `scheme.surfaceContainerHigh.withValues(alpha: 0.65)` and `BorderRadius.circular(20)` with custom `FormField<String>`.
   - Line 147 contains `fillColor: Colors.transparent` which is redundant/disallowed under strict AGENTS.md zero `Colors.*` rule.
   - Text inputs need tonal `surfaceContainerHighest` fill and clean high-contrast error states with `scheme.error`.

4. **Action Button & Layout Structure**:
   - `_M3AuthSubmitButton` in `login_screen.dart` (lines 258–313) and `register_screen.dart` (lines 305–360) is currently inline inside `SingleChildScrollView` with `height: 54` instead of a bottom-pinned / floating action bar with `height: 56dp` and `borderRadius: BorderRadius.circular(28)`.
   - Loading indicator currently renders inline `AppLoadingIndicator(size: 24, color: scheme.onPrimary)`.

5. **Biometric Authentication State**:
   - `BiometricService` exists in `lib/core/services/biometric_service.dart` providing `isBiometricEnabled`, `isDeviceSupported`, and `authenticate()`.
   - `login_screen.dart` currently has **no** biometric trigger tile or button.

6. **OAuth & Quick Access**:
   - `login_screen.dart` currently has **no** OAuth / quick access buttons.

7. **Test Suite Status**:
   - Total existing tests: 129 tests in `test/` (`flutter test` output: 129 passed).
   - `pulse_flutter/test/` has **zero** test files covering `LoginScreen` or `RegisterScreen`.
   - `flutter analyze` passes cleanly (0 issues found).

---

## 2. Logic Chain

1. **Visual & Structural Alignment (R2 Requirement)**:
   - *Observation*: R2 demands a clean, focused layout with brand header, organic hero avatar/logo container, M3 Expressive text inputs (`OutlineInputBorder` with 20dp squircles, tonal `surfaceContainerHighest` fill), and bottom pinned pill button (`height: 56dp`, `borderRadius: 28dp`).
   - *Reasoning*: Removing the fragmented hardcoded Cyrillic glyphs ("В-cookie-йти") and replacing them with a centered `AppLogoMark` (80–88dp squircle/c9-cookie mark), followed by `context.l10n.loginTitle` / `registerTitle` and subtitles in `textTheme.headlineMedium` / `bodyMedium`, produces a clean, internationalized hero section.
   - *Reasoning*: Panning the action button to a bottom pinned bar (`bottomNavigationBar` or sticky footer in `SafeArea`) guarantees accessibility across all viewport heights and keyboard states while preserving the 56dp pill geometry.

2. **Localization & Rule Compliance**:
   - *Observation*: Hardcoded Cyrillic strings exist in both screens, violating AGENTS.md rule ("100% localization via context.l10n").
   - *Reasoning*: All strings must map to `context.l10n.*`. Where specific sub-phrases like "No account?" or "Already have an account?" are needed, they can be composed cleanly or mapped to existing l10n keys (`loginCreateAccount`, `registerTitle`, etc.).

3. **Biometrics & Quick Access Architecture**:
   - *Observation*: `BiometricService` is injected via Riverpod `biometricServiceProvider`.
   - *Reasoning*: In `LoginScreen`, checking `biometric.isDeviceSupported` and `biometric.isBiometricEnabled` on mount allows rendering an expressive biometric tile (`Icons.fingerprint_rounded`, tonal primary container). Tapping prompts biometrics and executes fast-path authentication.
   - *Reasoning*: A clean OAuth/Quick access row (Google / Passkey / Quick Access) with squircle icon buttons (`16dp` radius, `surfaceContainerHigh`) offers standard Android 15 auth parity.

4. **Testing Strategy**:
   - *Observation*: No auth widget tests exist in `pulse_flutter/test/`.
   - *Reasoning*: Adding comprehensive widget tests (`test/auth/login_screen_test.dart` and `test/auth/register_screen_test.dart`) using `buildTestHarness()` will verify validation rules, password visibility toggles, loading states, biometric interactions, and router transitions.

---

## 3. Caveats

1. **Biometric Credential Retrieval**:
   - `BiometricService` authenticates via OS biometric prompts (`LocalAuthentication`). If a previously authenticated user's session token is preserved or quick-login token is supported, biometric success can resume the session; otherwise, it can be used for biometric confirmation before submitting stored credentials.
2. **Keyboard Insets**:
   - When pinning the submit button to the bottom, `Scaffold.resizeToAvoidBottomInset: true` or responsive insetting (`MediaQuery.viewInsetsOf(context)`) must be respected so the submit button remains visible when the virtual keyboard expands.
3. **M3 Text Field Package Dependency**:
   - `flutter_m3shapes: ^1.0.0+2` is available and already imported in the project. `AppLogoMark` and custom shapes integrate seamlessly.

---

## 4. Conclusion & Actionable Blueprint for R2

To implement R2, the implementer should follow this concrete plan:

### A. Polished Input Component: `lib/widgets/m3_auth_text_field.dart`
- Set background to `scheme.surfaceContainerHighest.withValues(alpha: 0.7)`.
- Use 20dp squircle radius (`BorderRadius.circular(20)`).
- Normal border: `scheme.outlineVariant.withValues(alpha: 0.25)`.
- Focus border: `scheme.primary` with width `1.6dp`.
- Error border: `scheme.error` with width `1.6dp`.
- Dynamic prefix icon color matching state (`scheme.primary` when focused, `scheme.error` when error, `scheme.onSurfaceVariant` when idle).
- Eliminate any `Colors.transparent` / `Colors.*` usage.

### B. Overhaul `lib/screens/login_screen.dart`
1. **Hero & Header**:
   - Center `AppLogoMark(size: 80)` with entrance fade/scale animation.
   - Title: `Text(context.l10n.loginTitle, style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5, color: scheme.onSurface))`.
   - Subtitle: `Text(context.l10n.loginSubtitle, style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant))`.
2. **Inputs**:
   - Identifier field with `context.l10n.loginIdentifierLabel` (`Icons.alternate_email_rounded`).
   - Password field with `context.l10n.loginPasswordLabel` (`Icons.lock_outline_rounded`), visibility toggle with `Icons.visibility_rounded` / `Icons.visibility_off_rounded`.
3. **Biometric Login Trigger Tile**:
   - If `biometric.isDeviceSupported && biometric.isBiometricEnabled`, show an expressive card with `Icons.fingerprint_rounded`, title `context.l10n.biometricTitle`, and tap handler calling `_handleBiometricLogin()`.
4. **OAuth / Quick Access Row**:
   - Row with subtle divider and quick sign-in icon buttons (Google, Apple, Passkey) with 16dp squircles.
5. **Bottom Pinned Submit Pill Button**:
   - Height: `56dp`, `borderRadius: BorderRadius.circular(28)`.
   - Color: `scheme.primary` (fill) with `scheme.onPrimary` (text/icon).
   - Loading indicator: `AppLoadingIndicator(size: 24, color: scheme.onPrimary)`.
   - Secondary link: "Forgot password?" (`context.l10n.loginForgotPassword`) & "Create account" (`context.l10n.loginCreateAccount` -> `/register`).

### C. Overhaul `lib/screens/register_screen.dart`
1. **Hero & Header**:
   - Center `AppLogoMark(size: 80)` with entrance animation.
   - Title: `Text(context.l10n.registerTitle, style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5, color: scheme.onSurface))`.
   - Subtitle: `Text(context.l10n.registerSubtitle, style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant))`.
2. **Inputs**:
   - Display Name (`context.l10n.registerDisplayNameLabel`, `Icons.badge_outlined`).
   - Username (`context.l10n.registerUsernameLabel`, `Icons.alternate_email_rounded`).
   - Email (`context.l10n.registerEmailLabel`, `Icons.mail_outline_rounded`).
   - Password (`context.l10n.registerPasswordLabel`, `Icons.lock_outline_rounded`, toggle).
3. **Consent Row**:
   - Styled checkboxes with links to `/legal/tos` and `/legal/privacy`.
4. **Bottom Pinned Submit Pill Button**:
   - Height: `56dp`, `borderRadius: BorderRadius.circular(28)`.
   - Loading indicator when `auth.busy`.
   - Secondary link to `/login`.

### D. New Unit & Widget Tests
Create:
- `test/screens/login_screen_test.dart`
- `test/screens/register_screen_test.dart`
Covering:
- UI rendering (hero logo, inputs, 56dp submit button, biometric tile)
- Form validation (empty checks, length checks, email regex format, consent requirement)
- Password visibility toggles
- Loading state handling
- Submission routing (`/main/chats`, `/2fa`, `/verify-email`)

---

## 5. Verification Method

To independently verify after implementation:

1. **Static Analysis**:
   ```bash
   cd pulse_flutter
   flutter analyze
   ```
   *Expected result*: `No issues found! (0 warnings, 0 errors)`.

2. **Automated Test Execution**:
   ```bash
   cd pulse_flutter
   flutter test
   ```
   *Expected result*: All existing 129 tests and new login/register tests pass (100% pass rate).

3. **Code Quality Spot Checks**:
   - Ensure zero instances of `Colors.white`, `Colors.black`, or `withOpacity()` in `login_screen.dart`, `register_screen.dart`, or `m3_auth_text_field.dart`.
   - Ensure all string labels use `context.l10n.*`.
