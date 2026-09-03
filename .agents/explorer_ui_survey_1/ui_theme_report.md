# UI & Theme Exploration Report: Nios ID Unified Authentication Hub

**Date**: 2026-09-01  
**Project**: NiosMess (`pulse_flutter`)  
**Investigator**: UI & Theme Explorer  
**Specification References**: `NIOSMESS_FRONTEND_LOGIN.md`, `ORIGINAL_REQUEST.md`, `AGENTS.md`, `DESIGN.md`

---

## 1. Executive Summary

This report provides a comprehensive survey and architectural design analysis of the UI, Theme, Component hierarchy, Localization, and Testing infrastructure in `f:\Niosmess V2\pulse_flutter` for transitioning NiosMess from legacy local username/password authentication to the **Unified Nios ID OAuth 2.0 PKCE Authentication Hub** in strict accordance with `NIOSMESS_FRONTEND_LOGIN.md`.

### Core Insights:
1. **Complete Elimination of Local Credentials**: All username, password, email, and separate registration input fields must be eliminated from `/login` and `/register`. The screens are consolidated into a single Material 3 Expressive authentication hub centered around the primary action «Войти через Nios ID».
2. **Material 3 Expressive Visual Language**: The current design system is powered by `dynamic_color`, tonal palettes (`ColorScheme.fromSeed`), `flutter_m3shapes` (`M3Container.c9SidedCookie`), `google_fonts` (`GoogleFonts.unbounded`, `GoogleFonts.inter`), and variable fonts (`PlusJakartaSans`, `Inter`). The new Auth Hub will feature:
   - Responsive centering (`maxWidth: 480dp`) with organic background curves (`M3OrganicBackground` / `M3ResponsiveAuthLayout`).
   - Hero branding combining the NiosMess cookie logo mark and official Nios ID badge.
   - Elevated **Ecosystem Benefits Card** (`surfaceContainerLow`) with 3 highlighted pillars.
   - High-contrast **56dp Pill Button** (`BorderRadius.circular(28)`) with inline loading state.
   - Interactive **Legal Footer** integrating the existing full-featured `LegalViewerScreen` (`/legal/privacy` and `/legal/terms`).
3. **L10n Architecture**: Localization is managed via `AppLocalizations` (`lib/l10n/app_localizations.dart`, `app_localizations_ru.dart`, `app_localizations_en.dart`). All new UI strings have been mapped and fully translated for both Russian and English.
4. **Testing Infrastructure**: Existing tests in `test/screens/login_screen_test.dart` and `test/screens/register_screen_test.dart` test legacy text fields (`login_identifier_field`, `login_password_field`, etc.). These must be overhauled to verify Nios ID button rendering, Ecosystem card pillars, loading overlay, PKCE flow triggers, consent rejection handling, and responsive layouts.

---

## 2. Codebase Architecture & UI Survey

### 2.1 Theme System (`lib/core/theme/`)

The application implements a strict Material 3 Expressive theme system:

- **`lib/core/theme/app_colors.dart`**:
  Defines the baseline static color tokens:
  - `primary`: `0xFF6750A4` (M3 Purple/Violet seed)
  - `onPrimary`: `0xFFFFFFFF`
  - `primaryContainer`: `0xFFD4C3FD`
  - `onPrimaryContainer`: `0xFF493C6C`
  - `surface`: `0xFFFDF7FE`
  - `surfaceContainerLow`: `0xFFF8F1FA`
  - `surfaceContainer`: `0xFFF2ECF5`
  - `surfaceContainerHigh`: `0xFFECE6F0`
  - `surfaceContainerHighest`: `0xFFE7E0EC`
  - `onSurface`: `0xFF34313A`
  - `onSurfaceVariant`: `0xFF615D68`
  - `outlineVariant`: `0xFFB5B0BB`
  - `error`: `0xFFA8364B`
- **`lib/core/theme/app_theme.dart`**:
  - Implements `AppTheme.themed(VisualThemeSettings, Brightness, {ColorScheme? dynamicScheme})`.
  - Generates `ColorScheme.fromSeed(seedColor, brightness, dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot)`.
  - Integrates system dynamic wallpaper colors via `dynamic_color` (`DynamicColorBuilder` in `main.dart`).
  - Configures M3 component themes:
    - `cardTheme`: `color: scheme.surfaceContainer`, `elevation: 0`, `shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))`
    - `dialogTheme`: `backgroundColor: scheme.surfaceContainerHigh`, `shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))`
    - `bottomSheetTheme`: `backgroundColor: scheme.surfaceContainerHigh`, `shape: RoundedRectangleBorder(top: Radius.circular(28))`
    - `snackBarTheme`: `behavior: SnackBarBehavior.floating`, `shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))`
- **`lib/core/theme/app_typography.dart`**:
  - Builds typography scale on top of `GoogleFonts.interTextTheme(baseTextTheme)`:
    - `displayLarge`: 36sp, w800, -0.5 letter spacing
    - `headlineLarge`: 28sp, w700, -0.4 letter spacing
    - `headlineMedium`: 22sp, w700, -0.3 letter spacing
    - `headlineSmall`: 20sp, w600, -0.2 letter spacing
    - `titleLarge`: 18sp, w700, -0.2 letter spacing
    - `titleMedium`: 16sp, w600, -0.1 letter spacing
    - `bodyLarge`: 16sp, w400, 1.45 line height
    - `bodyMedium`: 14sp, w400, 1.45 line height
    - `labelLarge`: 15sp, w600, -0.1 letter spacing
    - `labelMedium`: 12sp, w600
    - `labelSmall`: 11sp, w500

### 2.2 Fonts & Typography Configuration (`pubspec.yaml`)

- **Dependencies**: `google_fonts: ^6.2.1` is imported and active.
- **Local Asset Variable Fonts**:
  - `PlusJakartaSans` (`assets/fonts/plus_jakarta_sans/PlusJakartaSans-Variable.ttf`, weights 400..800).
  - `Inter` (`assets/fonts/inter/Inter-Variable.ttf`, weights 400..700).
- **Typography Guidelines**:
  - Expressive Headers / Brand titles: Use `GoogleFonts.unbounded(...)` (as seen in `onboarding_screen.dart:122`) or `PlusJakartaSans`.
  - Body / Subtitles / Pillar items: Use `GoogleFonts.inter(...)` or `Theme.of(context).textTheme` derived styles.

### 2.3 Existing Auth Screens & Transition Targets

| File | Current Role | Target State under Nios ID |
|---|---|---|
| `lib/screens/login_screen.dart` | Local login with username/password inputs, 2FA prompt, password visibility toggle | **Unified Auth Hub**: Expressive Hero Header + Ecosystem Benefits Card + 56dp Pill Button + Legal Reader footer. Zero local input fields. |
| `lib/screens/register_screen.dart` | Local registration with 4 text fields and consent checkboxes | **Consolidated / Replaced**: Route `/register` can alias or redirect directly to the unified Auth Hub or Nios ID web registration link. |
| `lib/screens/two_fa_screen.dart` | 6-digit OTP code verification | Retained for backend fallback / 2FA when applicable or managed entirely within central Nios ID. |
| `lib/screens/verify_email_screen.dart` | Email verification code | Managed in central Nios ID flow; screen preserved for standalone operations. |
| `lib/screens/reset_password_request_screen.dart` | Local password reset | Retained or redirected to `https://ni-os.ru/id/reset-password`. |
| `lib/screens/splash_screen.dart` | 2.2s animated splash with mesh background | Checks NiosMess local session + verifies central Nios ID session via `GET /id/api/v1/account`. |
| `lib/screens/onboarding_screen.dart` | 3-slide carousel with Lottie animations | Action buttons route to `/login` (Unified Auth Hub). |
| `lib/screens/legal_viewer_screen.dart` | High-fidelity legal document viewer for Privacy, ToS, Consent | Invoked directly by the Legal Footer links in Auth Hub. |

### 2.4 Existing Reusable Widgets

- **`lib/widgets/m3_responsive_auth_layout.dart`**:
  - Provides dual-mode responsive layout: centered card (`maxWidth: 480`) on mobile, split brand illustration + card layout on desktop (`width >= 840`).
  - Uses `M3OrganicBackground` with smooth animated canvas blobs.
- **`lib/widgets/app_logo_mark.dart`**:
  - Renders the brand logo squircle (`M3Container.c9SidedCookie`, size 88) with `assets/svg/niosmess_logo_tintable.svg`.
- **`lib/widgets/pulse_loading_indicator.dart`**:
  - M3-compliant smooth circular progress indicator with theme awareness.
- **`lib/core/utils/app_toast.dart`**:
  - `AppToast.showError(context, message)`, `AppToast.showSuccess()`, `AppToast.showInfo()`.
- **`lib/core/utils/haptic_service.dart`**:
  - `HapticService.tap()`, `HapticService.confirm()`, `HapticService.destructive()`.

---

## 3. Material 3 Expressive Design Specification for Auth Hub

```
┌─────────────────────────────────────────────────────────────┐
│                    M3OrganicBackground                     │
│  ┌───────────────────────────────────────────────────────┐  │
│  │               Auth Hub Container                      │  │
│  │               (maxWidth: 480dp)                       │  │
│  │                                                       │  │
│  │  [ 🧁 NiosMess Logo ]  x  [ 🛡️ Nios ID Badge ]        │  │
│  │  Title: "NiosMess" (GoogleFonts.unbounded, 26sp)       │  │
│  │  Subtitle: "Единый безопасный вход в экосистему Nios"  │  │
│  │                                                       │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │ 🌟 Ecosystem Benefits Card (surfaceContainerLow)│  │  │
│  │  │                                                 │  │  │
│  │  │  [🪪] Единый аккаунт Nios ID                    │  │  │
│  │  │      Один профиль для всех сервисов             │  │  │
│  │  │                                                 │  │  │
│  │  │  [🔒] Сквозное E2EE шифрование                  │  │  │
│  │  │      Ключи хранятся только на устройствах       │  │  │
│  │  │                                                 │  │  │
│  │  │  [🛡️] Нулевая передача паролей                  │  │  │
│  │  │      Пароль вводится только в Nios ID           │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  │                                                       │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │  [🔑]  Войти через Nios ID       (56dp Pill)   │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  │                                                       │  │
│  │  [ Создать Nios ID ]  (Secondary Tonal/Text Action)   │  │
│  │                                                       │  │
│  │  ───────────────────────────────────────────────────  │  │
│  │  Legal Footer:                                        │  │
│  │  Политика конфиденциальности  •  Условия использования│  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 3.1 Layout & Responsive Constraints

- **Container Constraint**: `ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480))`
- **Padding**: Horizontal `24dp` (mobile) / `32dp` (tablet/desktop), vertical `24dp`.
- **Card Styling**:
  - `color`: `scheme.surfaceContainerHigh.withValues(alpha: isDark ? 0.92 : 0.98)`
  - `borderRadius`: `BorderRadius.circular(32)`
  - `border`: `Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35), width: 1.2)`
  - Elevation / Ambient Shadow: `scheme.shadow.withValues(alpha: 0.08)` blur `24`, offset `(0, 8)`.

### 3.2 Hero Header & Expressive Typography

- **Branding Composition**:
  - Dual badge header:
    1. NiosMess brand squircle: `M3Container.c9SidedCookie(width: 56, height: 56, color: scheme.primary, child: SvgPicture.asset('assets/svg/niosmess_logo_tintable.svg', colorFilter: ColorFilter.mode(scheme.onPrimary, BlendMode.srcIn)))`.
    2. Connection glyph: `Icon(Icons.sync_alt_rounded, size: 20, color: scheme.primary.withValues(alpha: 0.6))`.
    3. Nios ID official badge: `Container(width: 56, height: 56, decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(18)), child: Icon(Icons.badge_outlined, size: 28, color: scheme.primary))`.
- **Typography**:
  - Header: `GoogleFonts.unbounded(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: scheme.onSurface)`.
  - Subtitle: `textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.4)`.

### 3.3 Ecosystem Benefits Card

- **Container**:
  - Background: `scheme.surfaceContainerLow`
  - Border: `Border.all(color: scheme.outlineVariant.withValues(alpha: 0.25))`
  - Radius: `BorderRadius.circular(24)`
  - Padding: `const EdgeInsets.all(18)`
- **Three Core Pillars**:
  1. **Unified Nios ID Account** (`Icons.badge_outlined` / `Icons.person_pin_rounded`):
     - Icon Tile: 36x36 container in `scheme.primaryContainer` with 12dp radius, icon color `scheme.primary`.
     - Title: `context.l10n.authBenefitAccountTitle` (w700, 14sp, `scheme.onSurface`).
     - Description: `context.l10n.authBenefitAccountDesc` (w400, 12sp, `scheme.onSurfaceVariant`).
  2. **End-to-End E2EE Encryption** (`Icons.lock_outline_rounded`):
     - Icon Tile: 36x36 container in `scheme.tertiaryContainer` with 12dp radius, icon color `scheme.tertiary`.
     - Title: `context.l10n.authBenefitE2eeTitle` (w700, 14sp, `scheme.onSurface`).
     - Description: `context.l10n.authBenefitE2eeDesc` (w400, 12sp, `scheme.onSurfaceVariant`).
  3. **Zero Password Transmission** (`Icons.shield_outlined`):
     - Icon Tile: 36x36 container in `scheme.secondaryContainer` with 12dp radius, icon color `scheme.secondary`.
     - Title: `context.l10n.authBenefitZeroPasswordTitle` (w700, 14sp, `scheme.onSurface`).
     - Description: `context.l10n.authBenefitZeroPasswordDesc` (w400, 12sp, `scheme.onSurfaceVariant`).

### 3.4 Primary 56dp Pill Action Button

- **Geometry**: Height `56.0` dp, Width `double.infinity`, `BorderRadius.circular(28)`.
- **Implementation**:
  ```dart
  SizedBox(
    width: double.infinity,
    height: 56,
    child: FilledButton.icon(
      key: const Key('nios_id_login_button'),
      onPressed: isLoading ? null : _onLoginPressed,
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: const StadiumBorder(),
        elevation: 0,
      ),
      icon: isLoading
          ? const SizedBox.shrink()
          : const Icon(Icons.login_rounded, size: 22),
      label: isLoading
          ? SizedBox(
              width: 24,
              height: 24,
              child: AppLoadingIndicator(size: 24, color: scheme.onPrimary),
            )
          : Text(
              context.l10n.authLoginNiosId,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onPrimary,
                letterSpacing: -0.2,
              ),
            ),
    ),
  );
  ```
- **Haptic Feedback**: Triggers `HapticService.tap()` on press.

### 3.5 Secondary Action: «Создать Nios ID»

- TextButton or OutlinedButton centered below the pill button:
  - Label: `context.l10n.authCreateNiosId` («Создать Nios ID» / "Create Nios ID").
  - Target URL: `https://ni-os.ru/id/register?next=/web` (or deep link / browser launch).
  - Style: `textTheme.labelLarge?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700)`.

### 3.6 Interactive Legal Footer

- Compact responsive footer aligned at the bottom of the card:
  - Label prefix: `context.l10n.legalFooterAgreementPrefix` («Нажимая «Войти через Nios ID», вы принимаете»).
  - Links with underline / primary tint:
    - `context.l10n.legalPrivacyTitle` -> triggers `context.push('/legal/privacy')`.
    - `context.l10n.legalToSTitle` -> triggers `context.push('/legal/terms')`.
  - Accessible across all screen form-factors with adequate tap targets.

### 3.7 Loading & OAuth Callback Exchange Overlay

- When OAuth callback parameters (`code`, `state`) are intercepted:
  - Render an animated tonal overlay over the Auth screen:
    - Container background: `scheme.surface.withValues(alpha: 0.94)` with `BackdropFilter` (blur 8px).
    - Centered Column:
      - `AppLogoMark(size: 72)` with repeating pulse scale animation.
      - 24dp spinner: `AppLoadingIndicator(size: 32)`.
      - Text: `context.l10n.authNiosIdProcessing` («Авторизация в Nios ID...» / "Authenticating with Nios ID...") in `textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)`.
- If user rejects consent (`error=access_denied`):
  - Dismiss overlay, re-enable primary button.
  - Display error toast: `AppToast.showError(context, params.get('error_description') ?? context.l10n.authConsentDenied)`.

---

## 4. Comprehensive Localization (L10n) Mapping

The project's localization is located in `lib/l10n/` (`app_localizations.dart`, `app_localizations_ru.dart`, `app_localizations_en.dart`). Below is the required key mapping:

| Key | Russian Translation (`app_localizations_ru.dart`) | English Translation (`app_localizations_en.dart`) | Context / Component |
|---|---|---|---|
| `authLoginNiosId` | `Войти через Nios ID` | `Sign in with Nios ID` | Primary 56dp Pill Button |
| `authCreateNiosId` | `Создать Nios ID` | `Create Nios ID` | Secondary Action Link |
| `authHubTitle` | `Вход в NiosMess` | `Sign in to NiosMess` | Auth Screen Main Title |
| `authHubSubtitle` | `Единый безопасный вход в экосистему Nios` | `Unified secure sign-in for the Nios ecosystem` | Auth Screen Hero Subtitle |
| `authBenefitAccountTitle` | `Единый аккаунт Nios ID` | `Unified Nios ID Account` | Ecosystem Card Pillar 1 Title |
| `authBenefitAccountDesc` | `Один профиль для всех сервисов экосистемы` | `One profile for all ecosystem services` | Ecosystem Card Pillar 1 Desc |
| `authBenefitE2eeTitle` | `Сквозное E2EE шифрование` | `End-to-End E2EE Encryption` | Ecosystem Card Pillar 2 Title |
| `authBenefitE2eeDesc` | `Ключи шифрования хранятся только на ваших устройствах` | `Encryption keys are stored exclusively on your devices` | Ecosystem Card Pillar 2 Desc |
| `authBenefitZeroPasswordTitle` | `Нулевая передача паролей` | `Zero Password Transmission` | Ecosystem Card Pillar 3 Title |
| `authBenefitZeroPasswordDesc` | `Пароль вводится только в Nios ID и никогда не передаётся приложению` | `Password is only entered in Nios ID and never shared with the client app` | Ecosystem Card Pillar 3 Desc |
| `authNiosIdProcessing` | `Авторизация в Nios ID...` | `Authenticating with Nios ID...` | Exchange Loading Overlay Status |
| `authConsentDenied` | `Доступ Nios ID не предоставлен.` | `Nios ID access was denied.` | OAuth Denial Toast |
| `authInvalidState` | `Не удалось проверить ответ Nios ID.` | `Failed to verify Nios ID response.` | State Mismatch Error Toast |
| `authExchangeFailed` | `Не удалось войти через Nios ID` | `Failed to sign in via Nios ID` | Token Exchange Error Toast |
| `authSessionExpired` | `Сессия Nios ID завершена. Войдите снова.` | `Nios ID session has expired. Please sign in again.` | Cold Start / Token Expiry Toast |
| `authLegalAgreementNotice` | `Нажимая «Войти через Nios ID», вы принимаете` | `By signing in with Nios ID, you agree to` | Legal Footer Agreement Text |
| `legalPrivacyTitle` *(existing)* | `Политика конфиденциальности` | `Privacy Policy` | Legal Viewer / Footer Link |
| `legalToSTitle` *(existing)* | `Условия использования` | `Terms of Service` | Legal Viewer / Footer Link |

---

## 5. Test Suite Analysis & Modernization Strategy

### 5.1 Analysis of Existing Tests (`test/`)

| Test File | Current Coverage | Required Action for Nios ID Refactor |
|---|---|---|
| `test/screens/login_screen_test.dart` | Tests legacy username input, password input, obscure text toggle, empty field validations, biometric tile, legacy OAuth squircle buttons. | **Overhaul**: Remove legacy text field tests. Add comprehensive tests for Nios ID pill button, Ecosystem card pillars, inline loading spinner, OAuth redirection trigger, error toast on consent cancellation, and legal links. |
| `test/screens/register_screen_test.dart` | Tests 4 text fields (name, username, email, password), 2 consent checkboxes, submit button. | **Retire / Consolidate**: Since registration is delegated to Nios ID, replace with tests verifying registration redirection or route aliasing to the unified Auth Hub. |
| `test/legal_viewer_screen_test.dart` | Tests Privacy, ToS, Consent document rendering, search toggle, async asset loading. | **Preserve / Verify**: Fully passes; verify that clicking footer links in Auth Hub correctly routes here. |
| `test/onboarding_screens_test.dart` | Tests Onboarding carousel slides, Setup wizard steps, navigation buttons. | **Update Navigation Targets**: Ensure onboarding "Get Started" and "Login" buttons route cleanly to `/login` (Auth Hub). |
| `test/verification_screens_test.dart` | Tests 2FA OTP input, Resend countdown, Email verification, Password reset. | **Preserve**: Keeps unit coverage intact for OTP inputs and sub-screens. |

### 5.2 Recommended New Widget Test Suite (`test/screens/login_screen_test.dart`)

The updated test suite should contain the following test cases:

1. **`renders hero branding, Nios ID badge, and unbounded typography`**:
   - Verifies presence of `AppLogoMark`, Nios ID badge icon, and localized title/subtitle.
2. **`renders Ecosystem Benefits Card with 3 highlighted pillars`**:
   - Verifies `Icons.badge_outlined`, `Icons.lock_outline_rounded`, `Icons.shield_outlined` and their respective localized strings.
3. **`renders 56dp pill button with stadium border and 28dp radius`**:
   - Verifies `FilledButton.icon`, height 56dp, `StadiumBorder` or `BorderRadius.circular(28)`.
4. **`taps primary button and triggers beginNiosIdAuthorization`**:
   - Verifies auth service / PKCE invocation and loading spinner transition.
5. **`displays exchange transition overlay during callback processing`**:
   - Verifies overlay visibility and status text «Авторизация в Nios ID...».
6. **`handles access_denied error gracefully by showing AppToast and re-enabling button`**:
   - Verifies error toast display on OAuth denial without unhandled exceptions.
7. **`renders legal footer and navigates to /legal/privacy and /legal/terms`**:
   - Verifies both legal links and GoRouter navigation.
8. **`adheres to maxWidth 480dp responsive constraint on tablet/desktop viewports`**:
   - Sets surface size to (1200, 800) and asserts center container width <= 480.

---

## 6. Implementation Action Plan for Engineering Team

1. **L10n Updates**:
   - Add the new Nios ID strings to `lib/l10n/app_localizations.dart`, `app_localizations_ru.dart`, and `app_localizations_en.dart`.
2. **UI Implementation (`lib/screens/login_screen.dart`)**:
   - Replace the legacy form column with the M3 Expressive layout:
     - `_HeroHeader`: NiosMess logo + Nios ID badge + Unbounded title.
     - `_EcosystemCard`: 3 pillars in `surfaceContainerLow`.
     - `_NiosIdLoginButton`: 56dp pill button with inline spinner.
     - `_SecondaryAction`: «Создать Nios ID» link.
     - `_LegalFooter`: Privacy & Terms navigation.
     - `_ExchangeOverlay`: Tonal loading overlay when processing OAuth return.
3. **Route & Redirection Aliasing (`lib/router/app_router.dart`)**:
   - Route `/register` redirects or displays the unified Auth Hub.
   - Public route guards updated accordingly.
4. **OAuth PKCE Integration**:
   - Integrate `NiosOAuthService` (or equivalent provider) for S256 code verifier/challenge generation, sessionStorage persistence, and callback parameter exchange via `/oauth/token` and WS `login_nios_id`.
5. **Test Suite Modernization**:
   - Replace legacy form tests in `test/screens/login_screen_test.dart` with the new Nios ID Auth Hub test suite.
   - Run `flutter test` and `flutter analyze` to ensure 0 errors, 0 warnings.
