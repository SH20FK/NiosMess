## 2026-09-01T00:15:02Z
You are a Worker implementing Milestone 2: Login & Registration Suite Overhaul (R2) in `pulse_flutter`.

Authoritative User Request: `f:\Niosmess V2\.agents\ORIGINAL_REQUEST.md`
Project Specification: `f:\Niosmess V2\PROJECT.md`
Explorer 2 Findings: `f:\Niosmess V2\.agents\explorer_2\handoff.md`
Project Workspace: `f:\Niosmess V2\pulse_flutter`
Your Working Directory: `f:\Niosmess V2\.agents\worker_m2`

Your Exclusive File Write Ownership:
- `pulse_flutter/lib/widgets/m3_auth_text_field.dart`
- `pulse_flutter/lib/screens/login_screen.dart`
- `pulse_flutter/lib/screens/register_screen.dart`
- `pulse_flutter/test/screens/login_screen_test.dart`
- `pulse_flutter/test/screens/register_screen_test.dart`
(Do NOT edit files owned by other workers).

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Key Requirements:
1. `m3_auth_text_field.dart`:
   - 20dp squircle radius (`BorderRadius.circular(20)`).
   - Fill: `scheme.surfaceContainerHighest.withValues(alpha: 0.7)`.
   - Border: normal `scheme.outlineVariant.withValues(alpha: 0.25)`, focused `scheme.primary` 1.6dp, error `scheme.error` 1.6dp.
   - State-colored prefix icons, clear password toggle icons.
   - Zero `Colors.transparent` / `Colors.*` usage.
2. `login_screen.dart`:
   - Hero header: Center `AppLogoMark(size: 80)` with entrance animation.
   - Remove broken Cyrillic glyph splitting ("В-cookie-йти") -> internationalized `context.l10n.loginTitle` & `loginSubtitle` in `headlineMedium` / `bodyMedium`.
   - M3Expressive inputs for identifier (`Icons.alternate_email_rounded`) and password (`Icons.lock_outline_rounded`).
   - Biometric login trigger card tile (`Icons.fingerprint_rounded`, `scheme.primaryContainer`) when `biometric.isDeviceSupported && biometric.isBiometricEnabled`.
   - OAuth / Quick access icon row with 16dp squircle buttons.
   - Bottom-pinned / sticky 56dp height, 28dp radius `FilledButton` pill submit button with integrated loading state.
   - Links for forgot password and create account.
3. `register_screen.dart`:
   - Hero header with `AppLogoMark(size: 80)`, internationalized `context.l10n.registerTitle` & `registerSubtitle`.
   - Inputs for Display Name, Username, Email, and Password with 20dp squircle styling.
   - Styled consent checkboxes for terms and privacy.
   - Bottom-pinned 56dp height, 28dp radius `FilledButton` pill submit button with integrated loading state.
4. Guardrails:
   - ZERO `Colors.white`, `Colors.black`, or `Colors.grey`. Use `Theme.of(context).colorScheme.*` tokens.
   - ZERO `withOpacity()` — use `.withValues(alpha: ...)`
   - 100% `context.l10n.*` (no raw user-facing strings).
5. Tests & Verification:
   - Create `test/screens/login_screen_test.dart` and `test/screens/register_screen_test.dart`.
   - Run `flutter analyze` (must be 0 errors/warnings).
   - Run `flutter test test/screens/login_screen_test.dart test/screens/register_screen_test.dart` and `flutter test`.
6. Write your complete handoff report to `f:\Niosmess V2\.agents\worker_m2\handoff.md` and message your parent when complete.
