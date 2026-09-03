# Handoff Report: Investigation of Onboarding & Setup Wizard Flow (R1)

## 1. Observation

### 1.1 Existing Files & Architecture
- **Onboarding Carousel Screen**: `pulse_flutter/lib/screens/onboarding_screen.dart` (358 lines)
  - Uses `M3OrganicBackground` (lines 94-97).
  - Brand Header (lines 103-157): Uses `AppLogoMark(size: 88)` with `.animate().scale().fade()`, followed by a `Row` with hardcoded strings `'Ni'` and `'s Mess'` flanking a `M3Container(Shapes.c9_sided_cookie, width: 22, height: 22, ...)` with `Icons.bolt_rounded`.
  - Carousel PageView (lines 161-214): `PageView.builder` rendering 3 slides (`onboardingSlide1Title`, `onboardingSlide2Title`, `onboardingSlide3Title`).
    - Currently renders raw `Lottie.asset(slide.lottiePath, width: 130, height: 130, fit: BoxFit.contain)` without squircle container/badge wrapping (lines 182-188).
    - Slide titles use `textTheme.titleLarge` (18sp, font weight w800, line 194) rather than expressive `displaySmall` (40sp) or `headlineMedium` (24sp).
    - Descriptions use `textTheme.bodyMedium` (line 203).
  - Page Indicators (lines 217-235): Basic `AnimatedContainer` with fixed height `8` and width `active ? 24 : 8` with `BorderRadius.circular(4)`.
  - Action Buttons (lines 239-272): Uses private `_M3AuthPillButton` (lines 279-342) implementing custom `InkWell` + `Material` with 28dp radius instead of standard M3 `FilledButton` / `FilledButton.tonal`.
  - Haptics: `onPageChanged` checks `ref.read(uiSettingsProvider).haptics` and calls `HapticService.tap()`.

- **Setup Wizard Screen**: `pulse_flutter/lib/screens/setup_onboarding_screen.dart` (682 lines)
  - Uses `PopScope(canPop: false)` with `Scaffold` wrapped in `Container(decoration: BoxDecoration(gradient: AppTheme.heroGradient(scheme)))` (lines 130-136).
  - Step 0 (Welcome, lines 212-263): Icon `Icons.waving_hand_rounded` wrapped in `Container(width: 120, height: 120, decoration: BoxDecoration(borderRadius: BorderRadius.circular(36)))`.
  - Step 1 (Language Selection, lines 265-378): Icon `Icons.language_rounded` wrapped in `Container(width: 88, height: 88, decoration: BoxDecoration(borderRadius: BorderRadius.circular(28)))`. Selection tiles use `borderRadius: BorderRadius.circular(20)`.
  - Step 2 (Timezone Selection, lines 380-551): Icon `Icons.schedule_rounded` wrapped in `Container(width: 88, height: 88, decoration: BoxDecoration(borderRadius: BorderRadius.circular(28)))`. Live clock container formatted with `formatFullDateTime(_now)`.
  - Page Indicators (lines 176-193): `Row` with 3 `AnimatedContainer` with height `10` and width `active ? 26 : 10` with `BorderRadius.circular(999)`.
  - Action Button (lines 195-201): Uses `PulseButton` with `context.l10n.commonContinue` or `context.l10n.setupStartMessaging`.

- **Routing & Navigation**:
  - `lib/screens/splash_screen.dart` (lines 54-58): If `!session.onboardingCompleted`, routes to `/onboarding`.
  - `lib/screens/verify_email_screen.dart` (line 61): Newly verified registered users are routed via `context.go('/setup')`.
  - `lib/router/app_router.dart` (lines 76-80): `/onboarding` and `/setup` are public routes; authenticated users visiting them are redirected to `/main/chats`.
  - `OnboardingScreen` actions (lines 63-85):
    - `_handleGetStarted()` completes onboarding (`sessionProvider.notifier.completeOnboarding()`) and navigates to `/register` (or `/main/chats` if authenticated).
    - `_handleLogin()` completes onboarding and navigates to `/login` (or `/main/chats` if authenticated).
  - `SetupOnboardingScreen` actions (lines 101-123):
    - `_skip()`: resets language to system default, sets timezone to auto, calls `completeOnboarding()`, and navigates `context.go('/main/chats')`.
    - `_finish()`: saves selected language & timezone in `uiSettingsProvider`, calls `completeOnboarding()`, and navigates `context.go('/main/chats')`.

- **State Management**:
  - `sessionProvider` (`lib/providers/session_provider.dart`): Riverpod 3.x `Notifier<SessionState>` storing `onboardingCompleted` backed by `SharedPreferences` (`session.onboardingCompleted`).
  - `uiSettingsProvider` (`lib/providers/ui_settings_provider.dart`): Stores `localeCode`, `timeZoneMode`, `timeZoneId`, `haptics`, `themeMode`, etc.
  - `authProvider` (`lib/providers/auth_provider.dart`): Stores `isAuthenticated`, `profile`, `session`.

- **Localization Strings**:
  - All essential keys already exist in `lib/l10n/app_localizations.dart`, `app_localizations_en.dart`, and `app_localizations_ru.dart`:
    - `onboardingSlide1Title`, `onboardingSlide1Desc`
    - `onboardingSlide2Title`, `onboardingSlide2Desc`
    - `onboardingSlide3Title`, `onboardingSlide3Desc`
    - `onboardingGetStarted`, `onboardingNext`
    - `registerTitle`, `loginTitle`, `appName`
    - `setupWelcomeTitle`, `setupWelcomeBody`
    - `setupLanguageTitle`, `setupTimezoneTitle`
    - `setupTimezoneUseDevice`, `setupTimezoneChooseManual`, `setupStartMessaging`
    - `commonContinue`, `commonSkip`
    - `languageRegionUseSystemLanguage`, `languageEnglish`, `languageRussian`, `languageRussianNative`, `languageRegionCurrentTime`, `languageRegionSearchTimeZones`

- **Verification Tools Execution**:
  - `flutter test`: 129/129 tests passed cleanly across the existing codebase.
  - `flutter analyze`: 0 issues found (static analysis clean).
  - Existing tests in `test/`: 0 tests currently exist for onboarding and setup wizard flows.

---

## 2. Logic Chain

1. **R1 Visual & Geometric Alignment**:
   - *Requirement*: Full-bleed M3 Expressive layout with organic squircle icon/illustration badges, large expressive typography (`displaySmall`/`headlineMedium`).
   - *From Observation 1.1*: `OnboardingScreen` renders Lottie animations without an organic squircle container, and slide titles use `textTheme.titleLarge` (18sp) instead of expressive typography (`displaySmall`/`headlineMedium`).
   - *Deduction*: Wrapping Lottie assets in a stylized squircle container (`M3Container(Shapes.c9_sided_cookie)` or `Container` with squircle geometry, tonal fill `scheme.primaryContainer`/`secondaryContainer`/`tertiaryContainer`, subtle border, and soft ambient drop shadows) and upgrading slide titles to `textTheme.headlineMedium` (or `displaySmall` in hero header) satisfies the visual hierarchy of M3 Expressive.

2. **R1 Expanding Pill Page Indicators**:
   - *Requirement*: Smooth animated page indicators (expanding pill indicator) with haptic feedback on swipe.
   - *From Observation 1.1*: Indicator in `OnboardingScreen` uses simple 8dp/24dp rect with linear container, and `SetupOnboardingScreen` uses 10dp/26dp.
   - *Deduction*: Unifying both into an animated expanding pill indicator widget (`_ExpandingPillIndicator` or component) with spring/cubic curve transitions (`Curves.easeOutCubic`), active width of 28-32dp, inactive width of 8-10dp, height of 8-10dp, pill border radius 999dp, and dynamic tonal color transitions (`scheme.primary` active, `scheme.outlineVariant.withValues(alpha: 0.4)` inactive) provides smooth, responsive swipe feedback.

3. **R1 Tonal Pill Action Buttons & Routing**:
   - *Requirement*: Primary full-width tonal pill action buttons (`FilledButton` with 28dp radius) and seamless routing into login/registration.
   - *From Observation 1.1*: `OnboardingScreen` uses private `_M3AuthPillButton` with raw `InkWell` instead of semantic Flutter `FilledButton` / `FilledButton.tonal` with `shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))` and `minimumSize: const Size.fromHeight(56)`.
   - *Deduction*: Refactoring buttons to standard `FilledButton` (Primary: `colorScheme.primary` with `colorScheme.onPrimary`) and `FilledButton.tonal` / secondary filled (Secondary: `colorScheme.surfaceContainerHighest` with `colorScheme.onSurface`) maintains full accessibility, semantic button states, and adheres to 28dp pill radius. Routing through `sessionProvider.completeOnboarding()` followed by `context.push('/register')` / `context.push('/login')` (or `context.go('/main/chats')` when authenticated) guarantees seamless navigation.

4. **Integrity & AGENTS.md Rule Compliance**:
   - *Rule*: Zero `Colors.white` / `Colors.black`, zero `withOpacity()`, use `withValues(alpha:)`, 100% `context.l10n`.
   - *From Observation 1.1*: Onboarding brand text had raw strings `'Ni'` and `'s Mess'`.
   - *Deduction*: Eliminating raw strings and ensuring all colors use `scheme.surface`, `scheme.onSurface`, `scheme.primaryContainer`, etc., with `.withValues(alpha:)` satisfies all AGENTS.md guardrails.

5. **Test Coverage Strategy**:
   - *From Observation 1.1*: No existing unit/widget tests exist for onboarding.
   - *Deduction*: Creating `test/onboarding_screens_test.dart` with unit and widget tests for `OnboardingScreen` and `SetupOnboardingScreen` (carousel swiping, indicator expansion, button triggers, locale/timezone updates, skip/finish flows, routing) will ensure complete regression protection.

---

## 3. Caveats

1. **Lottie Asset Loading in Tests**: In Flutter widget tests, `Lottie.asset` and SVG rendering may encounter mock asset loader behavior if unbundled; standard test helpers or `TestWidgetsFlutterBinding` asset bundle mocks should be used to avoid missing asset exceptions during test pump.
2. **Setup Wizard Invocations**: Setup Wizard (`/setup`) is triggered both after registration email verification (`verify_email_screen.dart`) and can be reached directly; tests should verify both initial entry and completion flows.
3. **No Caveats on Architecture**: Riverpod 3.x providers (`sessionProvider`, `uiSettingsProvider`) and `go_router` setup are already in place and operate cleanly.

---

## 4. Conclusion & Concrete Proposal

### 4.1 Proposed Blueprint for `onboarding_screen.dart` (R1)
1. **Expressive Organic Background**:
   - Retain `M3OrganicBackground(showBackButton: false, showThemeToggle: true)` with dynamic geometric blobs.
2. **Hero Header**:
   - `AppLogoMark(size: 88)` with spring scale and fade entrance animations.
   - Localized App Name (`context.l10n.appName` / expressive typography with `headlineMedium` and `M3Container(Shapes.c9_sided_cookie)` bolt icon).
3. **Carousel Slides (`_SlideData`)**:
   - Slide 1: Fast calls (`onboardingSlide1Title`, `onboardingSlide1Desc`, `onboarding_calls.json`, `scheme.primary`, `scheme.primaryContainer`).
   - Slide 2: Organized chats (`onboardingSlide2Title`, `onboardingSlide2Desc`, `onboarding_chat.json`, `scheme.secondary`, `scheme.secondaryContainer`).
   - Slide 3: Speed & performance (`onboardingSlide3Title`, `onboardingSlide3Desc`, `onboarding_speed.json`, `scheme.tertiary`, `scheme.tertiaryContainer`).
   - **Squircle Illustration Container**:
     ```dart
     Container(
       width: 140,
       height: 140,
       decoration: BoxDecoration(
         color: slide.containerColor.withValues(alpha: 0.65),
         borderRadius: BorderRadius.circular(36),
         border: Border.all(
           color: slide.tintColor.withValues(alpha: 0.25),
           width: 1.5,
         ),
         boxShadow: [
           BoxShadow(
             color: slide.tintColor.withValues(alpha: 0.15),
             blurRadius: 24,
             offset: const Offset(0, 8),
           ),
         ],
       ),
       child: Center(
         child: Lottie.asset(
           slide.lottiePath,
           width: 100,
           height: 100,
           fit: BoxFit.contain,
           repeat: true,
         ),
       ),
     )
     ```
   - **Expressive Typography**:
     - Title: `Text(slide.title, textAlign: TextAlign.center, style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5))`
     - Description: `Text(slide.description, textAlign: TextAlign.center, style: textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant, height: 1.4))`
4. **Expanding Pill Indicator**:
   - Active pill width: 28dp, inactive width: 8dp, height: 8dp, border radius: 4dp / 999dp.
   - Smooth `AnimatedContainer` duration: 300ms, curve: `Curves.easeOutCubic`.
   - Active color: `scheme.primary`, Inactive color: `scheme.outlineVariant.withValues(alpha: 0.4)`.
   - Haptic feedback triggered on `onPageChanged`.
5. **Full-Width Tonal Action Buttons**:
   - Primary ("Create Account" / `context.l10n.registerTitle`):
     ```dart
     SizedBox(
       width: double.infinity,
       height: 56,
       child: FilledButton.icon(
         onPressed: _handleGetStarted,
         icon: const Icon(Icons.arrow_forward_rounded, size: 20),
         label: Text(
           context.l10n.registerTitle,
           style: textTheme.titleMedium?.copyWith(
             fontWeight: FontWeight.w700,
             letterSpacing: -0.2,
           ),
         ),
         style: FilledButton.styleFrom(
           backgroundColor: scheme.primary,
           foregroundColor: scheme.onPrimary,
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
           elevation: 0,
         ),
       ),
     )
     ```
   - Secondary ("Log In" / `context.l10n.loginTitle`):
     ```dart
     SizedBox(
       width: double.infinity,
       height: 56,
       child: FilledButton.tonal(
         onPressed: _handleLogin,
         label: Text(
           context.l10n.loginTitle,
           style: textTheme.titleMedium?.copyWith(
             fontWeight: FontWeight.w700,
             letterSpacing: -0.2,
           ),
         ),
         style: FilledButton.styleFrom(
           backgroundColor: scheme.surfaceContainerHigh,
           foregroundColor: scheme.onSurface,
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
           elevation: 0,
         ),
       ),
     )
     ```

### 4.2 Proposed Blueprint for `setup_onboarding_screen.dart` (R1)
1. **Background & Layout**:
   - Use `M3OrganicBackground(showBackButton: false, showThemeToggle: true)` or full-bleed M3 surface with organic gradient.
   - Header with skip action `context.l10n.commonSkip`.
2. **Squircle Step Badges**:
   - Step 0 (Welcome): 120x120 container with 36dp squircle radius, `scheme.primaryContainer`, icon `Icons.waving_hand_rounded`, scale pulse animation.
   - Step 1 (Language): 96x96 container with 28dp squircle radius, `scheme.primaryContainer`, icon `Icons.language_rounded`.
   - Step 2 (Timezone): 96x96 container with 28dp squircle radius, `scheme.primaryContainer`, icon `Icons.schedule_rounded`.
3. **Step 1 & 2 Selection Cards**:
   - Squircles with `BorderRadius.circular(20)`, tonal background (`scheme.primaryContainer.withValues(alpha: 0.72)` when selected, `scheme.surfaceContainerLow.withValues(alpha: 0.62)` when unselected).
   - Trailing `Icons.check_circle_rounded` with `scheme.primary`.
4. **Step Indicator & Action Button**:
   - Unified expanding pill indicator.
   - 56dp height, 28dp radius `FilledButton` with `context.l10n.commonContinue` (Step 0, 1) and `context.l10n.setupStartMessaging` (Step 2) with loading indicator.

### 4.3 Proposed Test Suite Blueprint (`test/onboarding_screens_test.dart`)
```dart
void main() {
  group('R1: Onboarding Carousel Tests', () {
    testWidgets('Renders all initial carousel elements, branding, and buttons', (tester) async { ... });
    testWidgets('Swiping carousel advances slide and updates pill indicator', (tester) async { ... });
    testWidgets('Tapping Get Started completes onboarding and navigates to /register', (tester) async { ... });
    testWidgets('Tapping Log In completes onboarding and navigates to /login', (tester) async { ... });
    testWidgets('Buttons use 28dp radius pill geometry and semantic M3 colors', (tester) async { ... });
  });

  group('R1: Setup Wizard Tests', () {
    testWidgets('Renders Step 0 Welcome screen with waving badge and continue button', (tester) async { ... });
    testWidgets('Advances to Step 1 and changes language setting', (tester) async { ... });
    testWidgets('Advances to Step 2 and configures timezone setting', (tester) async { ... });
    testWidgets('Skip button applies defaults, completes onboarding, and navigates', (tester) async { ... });
    testWidgets('Start Messaging button completes onboarding and navigates to /main/chats', (tester) async { ... });
  });
}
```

---

## 5. Verification Method

### 5.1 Static Analysis
Execute static analysis in `pulse_flutter`:
```bash
cd "f:\Niosmess V2\pulse_flutter"
flutter analyze
```
*Expected Result*: `No issues found!` (0 errors, 0 warnings, 0 lints).

### 5.2 Unit & Widget Test Suite
Run the full test suite including the new onboarding test file:
```bash
cd "f:\Niosmess V2\pulse_flutter"
flutter test test/onboarding_screens_test.dart
flutter test
```
*Expected Result*: All tests pass (100% pass rate).

### 5.3 Invalidation Conditions
- Any occurrence of `Colors.white`, `Colors.black`, or `withOpacity()` in the modified files.
- Hardcoded user-facing strings not utilizing `context.l10n`.
- Action buttons not adhering to 28dp pill radius or 56dp standard height.
- Failure of Riverpod state updates in `sessionProvider` or `uiSettingsProvider`.
