# Handoff Report — UI & Theme Survey for Nios ID Unified Auth Hub

**Agent**: UI & Theme Explorer (`explorer_ui_survey_1`)  
**Recipient**: Project Orchestrator (`65ff2a5d-b51f-4b8f-9b41-07119b4e87c7`)  
**Working Directory**: `f:\Niosmess V2\.agents\explorer_ui_survey_1`  
**Date**: 2026-09-01  

---

## 1. Observation

1. **Theme System & Typography**:
   - `lib/core/theme/app_theme.dart:14-20`: Theme is generated via `ColorScheme.fromSeed(seedColor: settings.seedColor, brightness: brightness, dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot)`.
   - `lib/core/theme/app_colors.dart:6-27`: Color palette tokens define `surface: Color(0xFFFDF7FE)`, `surfaceContainerLow: Color(0xFFF8F1FA)`, `surfaceContainerHigh: Color(0xFFECE6F0)`, `primary: Color(0xFF6750A4)`, `onPrimary: Color(0xFFFFFFFF)`, `outlineVariant: Color(0xFFB5B0BB)`.
   - `lib/core/theme/app_typography.dart:8-85`: Typography builds `GoogleFonts.interTextTheme(baseTextTheme)` for MD3 scales (`displayLarge`, `headlineLarge`, `titleLarge`, `bodyLarge`, etc.).
   - `lib/screens/onboarding_screen.dart:122-127`: Uses `GoogleFonts.unbounded(...)` for expressive headers. Local variable fonts `PlusJakartaSans` and `Inter` are declared in `pubspec.yaml:129-152`.

2. **Existing Auth Screens & Legacy Inputs**:
   - `lib/screens/login_screen.dart:153-195`: Currently contains legacy form fields (`M3AuthTextField` with keys `login_identifier_field` and `login_password_field`).
   - `lib/screens/register_screen.dart:163-239`: Contains 4 legacy text fields (`register_name_field`, `register_username_field`, `register_email_field`, `register_password_field`) and consent checkboxes.
   - `lib/screens/legal_viewer_screen.dart:1-365`: Implements a fully-featured Material 3 Expressive legal reader with section navigation, search, and reading time calculation for `/legal/privacy`, `/legal/tos`, `/legal/terms`.
   - `lib/router/app_router.dart:70-80`: Redirect logic handles `/login`, `/register`, `/main/chats`, `/legal/*`.

3. **Existing Tests in `test/`**:
   - `test/screens/login_screen_test.dart:141-398`: Tests obsolete input fields (`Key('login_identifier_field')`, `Key('login_password_field')`, password visibility toggling, empty validation errors).
   - `test/screens/register_screen_test.dart:118-356`: Tests legacy 4-field registration form inputs.
   - `test/legal_viewer_screen_test.dart:49-130`: Tests `LegalViewerScreen` rendering, section chips, search toggling, and asynchronous loading.
   - `test/onboarding_screens_test.dart:111-325`: Tests onboarding slides, setup wizard steps, and navigation.

4. **Localization Structure**:
   - `lib/l10n/app_localizations.dart`, `app_localizations_ru.dart`, `app_localizations_en.dart`: Pure Dart classes implementing all app strings.
   - Missing Nios ID specific strings: `authLoginNiosId`, `authCreateNiosId`, `authHubSubtitle`, `authBenefitAccountTitle`, `authBenefitAccountDesc`, `authBenefitE2eeTitle`, `authBenefitE2eeDesc`, `authBenefitZeroPasswordTitle`, `authBenefitZeroPasswordDesc`, `authNiosIdProcessing`, `authConsentDenied`, `authInvalidState`, `authExchangeFailed`.

---

## 2. Logic Chain

1. **Step 1 — Zero Local Input Requirement**:
   - From *Observation 2* (`login_screen.dart` and `register_screen.dart`), the current codebase uses local username/password forms.
   - According to `NIOSMESS_FRONTEND_LOGIN.md:12-14` and `ORIGINAL_REQUEST.md:58-60`, client-side password/username inputs and separate registration screens must be completely eliminated.
   - Therefore, `login_screen.dart` must be rewritten as a unified Auth Hub and `register_screen.dart` / `/register` consolidated or aliased.

2. **Step 2 — Material 3 Expressive Component Hierarchy**:
   - Using tokens from *Observation 1* (`surfaceContainerLow`, `primary`, `onPrimary`, `BorderRadius.circular(28)`), the Auth Hub layout maps cleanly to:
     a. **Hero Header**: NiosMess cookie logo mark (`AppLogoMark`) + Nios ID official badge + `GoogleFonts.unbounded` title.
     b. **Ecosystem Benefits Card**: `surfaceContainerLow` container with 3 pillars (Unified Account, End-to-End E2EE, Zero Password Transmission).
     c. **Primary Action**: 56dp Pill Button (`FilledButton.icon`, height 56, radius 28dp, `scheme.primary`) with inline loading state.
     d. **Secondary Action**: «Создать Nios ID» link.
     e. **Legal Footer**: Responsive links opening the existing `LegalViewerScreen` (`/legal/privacy` & `/legal/terms`).
     f. **Exchange Overlay**: Full-screen tonal overlay with status «Авторизация в Nios ID...» during callback processing.

3. **Step 3 — L10n Parity**:
   - From *Observation 4*, the missing strings must be added to both `app_localizations_ru.dart` and `app_localizations_en.dart` (and declared in `app_localizations.dart`) to ensure no hardcoded strings exist in UI code per `AGENTS.md`.

4. **Step 4 — Test Suite Alignment**:
   - From *Observation 3*, `login_screen_test.dart` currently asserts legacy input fields which will be absent in the new Auth Hub.
   - The test suite must be updated to test the new components (Pill button, Ecosystem Card, inline loading, PKCE trigger, error toast on `access_denied`, legal navigation) to prevent CI failures.

---

## 3. Caveats

- **Web vs. Mobile/Desktop OAuth Launch**: On Flutter Web, redirection uses `window.location.assign` / GoRouter; on Mobile/Desktop, external browser or Custom Tabs (`app_links` / `url_launcher`) is used. The UI layer should handle both via a unified service interface.
- **Biometrics on Login**: With central Nios ID OAuth PKCE, local password-based biometrics are superseded by central session management; app-lock biometrics remain available in security settings.
- No other caveats.

---

## 4. Conclusion

The pulse_flutter codebase is well-structured for the Nios ID M3 Expressive redesign:
- Existing theme architecture, responsive layout helpers (`M3OrganicBackground`, `M3ResponsiveAuthLayout`), and legal reader (`LegalViewerScreen`) can be directly utilized.
- All required UI tokens, components, Russian/English localization keys, and test specifications are documented in `f:\Niosmess V2\.agents\explorer_ui_survey_1\ui_theme_report.md`.
- Implementation can proceed directly with zero architectural roadblocks.

---

## 5. Verification Method

1. **Inspect Artifacts**:
   - View report: `f:\Niosmess V2\.agents\explorer_ui_survey_1\ui_theme_report.md`
   - View dispatch & briefing logs in `.agents/explorer_ui_survey_1/`
2. **Post-Implementation Verification Commands**:
   - `flutter analyze` — Must report 0 errors and 0 warnings.
   - `flutter test test/screens/login_screen_test.dart` — Verify new widget tests pass.
   - `flutter test test/legal_viewer_screen_test.dart` — Verify legal viewer tests pass.
   - `flutter test` — Verify entire test suite passes without regression.
