## 2026-09-01T00:15:02Z
You are a Worker implementing Milestone 1: Onboarding Carousel & Setup Wizard Overhaul (R1) in `pulse_flutter`.

Authoritative User Request: `f:\Niosmess V2\.agents\ORIGINAL_REQUEST.md`
Project Specification: `f:\Niosmess V2\PROJECT.md`
Explorer 1 Findings: `f:\Niosmess V2\.agents\explorer_1\handoff.md`
Project Workspace: `f:\Niosmess V2\pulse_flutter`
Your Working Directory: `f:\Niosmess V2\.agents\worker_m1`

Your Exclusive File Write Ownership:
- `pulse_flutter/lib/screens/onboarding_screen.dart`
- `pulse_flutter/lib/screens/setup_onboarding_screen.dart`
- `pulse_flutter/test/onboarding_screens_test.dart`
(Do NOT edit files owned by other workers).

Key Requirements:
1. `onboarding_screen.dart`:
   - Full-bleed M3 Expressive layout with `M3OrganicBackground`.
   - Brand Header with `AppLogoMark(size: 88)` with spring entrance animation.
   - Carousel `PageView` with 3 slides: Lottie animations wrapped in organic squircle containers (36dp radius, `slide.containerColor.withValues(alpha: 0.65)`, border, soft drop shadow).
   - Expressive typography (`headlineMedium` with `FontWeight.w800`, `bodyLarge` with `onSurfaceVariant`).
   - Animated expanding pill indicator (28dp active pill, 8dp inactive, `Curves.easeOutCubic`, haptics on page switch).
   - Primary full-width 28dp pill action button (`FilledButton` 56dp height, `registerTitle`, primary/onPrimary) and secondary (`FilledButton.tonal` 56dp height, `loginTitle`, surfaceContainerHigh/onSurface).
   - Completes onboarding via `sessionProvider.notifier.completeOnboarding()` before navigation.
2. `setup_onboarding_screen.dart`:
   - Multi-step wizard (Step 0: Welcome, Step 1: Language, Step 2: Timezone).
   - Organic squircle hero badges (Step 0: 120x120 36dp radius; Steps 1 & 2: 96x96 28dp radius).
   - 20dp squircle selection cards for language and timezone with live clock.
   - Expanding pill step indicator.
   - 56dp height, 28dp radius `FilledButton` continue/finish actions.
   - Skip and finish actions properly update `uiSettingsProvider` and `sessionProvider.completeOnboarding()`.
3. Guardrails:
   - ZERO `Colors.white`, `Colors.black`, or `Colors.grey`. Use `Theme.of(context).colorScheme.*` / semantic M3 color tokens.
   - ZERO `withOpacity()` — use `.withValues(alpha: ...)`
   - ZERO `dart:io` — use `package:universal_io/io.dart`
   - Riverpod 3.x: `NotifierProvider` / `AsyncNotifierProvider`
   - 100% `context.l10n.*` (no raw user-facing strings).
4. Tests & Verification:
   - Create `test/onboarding_screens_test.dart` covering carousel swiping, indicators, buttons, setup steps, language/timezone updates, skip, finish, and routing.
   - Run `flutter analyze` (must be 0 errors/warnings).
   - Run `flutter test test/onboarding_screens_test.dart` and `flutter test`.
5. Write your complete handoff report to `f:\Niosmess V2\.agents\worker_m1\handoff.md` and message your parent when complete.
