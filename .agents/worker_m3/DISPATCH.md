## 2026-09-01T00:15:02Z
You are a Worker implementing Milestone 3: Verification & Security Screens Overhaul (R3) in `pulse_flutter`.

Authoritative User Request: `f:\Niosmess V2\.agents\ORIGINAL_REQUEST.md`
Project Specification: `f:\Niosmess V2\PROJECT.md`
Explorer 3 Findings: `f:\Niosmess V2\.agents\explorer_3\handoff.md`
Project Workspace: `f:\Niosmess V2\pulse_flutter`
Your Working Directory: `f:\Niosmess V2\.agents\worker_m3`

Your Exclusive File Write Ownership:
- `pulse_flutter/lib/widgets/m3_otp_input_field.dart`
- `pulse_flutter/lib/widgets/m3_resend_countdown_timer.dart`
- `pulse_flutter/lib/screens/two_fa_screen.dart`
- `pulse_flutter/lib/screens/verify_email_screen.dart`
- `pulse_flutter/lib/screens/reset_password_request_screen.dart`
- `pulse_flutter/lib/screens/reset_password_confirm_screen.dart`
- `pulse_flutter/lib/l10n/app_localizations.dart`
- `pulse_flutter/lib/l10n/app_localizations_en.dart`
- `pulse_flutter/lib/l10n/app_localizations_ru.dart`
- `pulse_flutter/test/verification_screens_test.dart`
(Do NOT edit files owned by other workers).

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Key Requirements:
1. Create `lib/widgets/m3_otp_input_field.dart`:
   - 6 discrete squircle boxes (`BorderRadius.circular(18)`).
   - 4 states: Inactive Empty, Focused (1.06x scale, `scheme.primary` 2px border, shadow glow), Filled (`scheme.primaryContainer` bg, `headlineMedium`), Error (`scheme.error` border + shake animation).
   - Captures system keyboard & OS autofill (`AutofillHints.oneTimeCode`).
   - Supports clipboard paste and auto-triggers `onCompleted(code)` on 6th digit.
2. Create `lib/widgets/m3_resend_countdown_timer.dart`:
   - Animated `CircularProgressIndicator` progress ring (`value: remaining / totalDuration`, `strokeWidth: 2.5`).
   - Countdown text (`context.l10n.authResendCountdown(remaining)`).
   - Expiry haptics (`HapticFeedback.mediumImpact()` / `HapticService`) on 0s and switch to active "Resend code" button.
   - Resend tap triggers `onResend()` and restarts timer.
3. Localization:
   - Add `authResendCode`, `authResendCountdown`, `authCodeSent`, `authPasteCode` to `app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_ru.dart`.
4. Overhaul Screens:
   - `two_fa_screen.dart`: Replace custom keypad with `M3OtpInputField`, `M3ResendCountdownTimer`, hero badge, auto-submit on 6th digit, and 28dp pill button.
   - `verify_email_screen.dart`: Read-only email card, `M3OtpInputField`, `M3ResendCountdownTimer`, auto-submit, and 28dp pill button.
   - `reset_password_request_screen.dart`: 20dp squircle email field + 28dp pill button + hero badge.
   - `reset_password_confirm_screen.dart`: Read-only email + `M3OtpInputField` + `M3ResendCountdownTimer` + 20dp squircle new password field + 28dp pill button.
5. Guardrails:
   - ZERO `Colors.white`, `Colors.black`, or `Colors.grey`. Use `Theme.of(context).colorScheme.*` tokens.
   - ZERO `withOpacity()` — use `.withValues(alpha: ...)`
   - 100% `context.l10n.*`.
6. Tests & Verification:
   - Create `test/verification_screens_test.dart` covering OTP component, resend timer, 2FA screen, verify email screen, and password reset screens.
   - Run `flutter analyze` (must be 0 errors/warnings).
   - Run `flutter test test/verification_screens_test.dart` and `flutter test`.
7. Write your complete handoff report to `f:\Niosmess V2\.agents\worker_m3\handoff.md` and message your parent when complete.
