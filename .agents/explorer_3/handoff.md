# Handoff Report: Verification & Security Screens Investigation (R3)

**Author:** explorer_3  
**Target Milestone:** R3 — Verification & Security Flows (`two_fa_screen.dart`, `verify_email_screen.dart`, `reset_password_request_screen.dart`, `reset_password_confirm_screen.dart`)  
**Workspace:** `f:\Niosmess V2\pulse_flutter`  

---

## 1. Observation

### 1.1 Existing Screen Implementations & Deficiencies
1. **`TwoFaScreen` (`pulse_flutter/lib/screens/two_fa_screen.dart:14-224`)**:
   - **Current Layout & Interaction**: Uses custom `_M3NumericKeypad` (lines 226–297) and static geometric shape dots `_dotShapes` / `_dotColors` (lines 28–45, 154–195).
   - **Deficiencies**:
     - No native system keyboard or SMS/email autofill (`AutofillHints.oneTimeCode`).
     - No paste support (despite hint text on line 172 of `app_localizations_en.dart`: *"Tip: paste the code directly"*).
     - No dynamic resend countdown timer with animated circular progress ring or expiry haptics.
     - Rigid on-screen keypad takes up excessive vertical viewport space and differs from modern Android 15 / Google Messages OTP input conventions.

2. **`VerifyEmailScreen` (`pulse_flutter/lib/screens/verify_email_screen.dart:16-245`)**:
   - **Current Layout & Interaction**: Uses `CodePreview(code: code)` stacked under a transparent `TextFormField` (lines 163–202).
   - **Deficiencies**:
     - `CodePreview` (`pulse_flutter/lib/widgets/code_preview.dart:19-54`) displays basic rectangular boxes with static borders, without animated squircle focus transitions (no active scale, no glowing border highlight, no cursor pulse).
     - No resend countdown timer widget with progress ring or expiry pulse haptics.
     - Stacked text field uses `Colors.transparent` directly (lines 173, 175, 184).
     - Does not auto-submit immediately on 6th digit input.

3. **`ResetPasswordRequestScreen` (`pulse_flutter/lib/screens/reset_password_request_screen.dart:16-177`)**:
   - **Current Layout & Interaction**: Uses `M3OrganicBackground`, `M3Container(Shapes.c9_sided_cookie)` icon badge (lines 87–98), `M3AuthTextField` for email input (lines 121–134), and pill submit button (lines 138–167).
   - **Deficiencies**:
     - Needs alignment with 20dp squircle input radius and 28dp pill action button geometry.
     - Needs strong high-contrast feedback states and haptics on submission.

4. **`ResetPasswordConfirmScreen` (`pulse_flutter/lib/screens/reset_password_confirm_screen.dart:17-278`)**:
   - **Current Layout & Interaction**: Uses read-only email box (lines 143–167), legacy `CodePreview` stacked under transparent `TextFormField` (lines 171–207), and new password `M3AuthTextField` (lines 211–235).
   - **Deficiencies**:
     - Lacks animated 6-digit squircle OTP input boxes with focus states, autofill, and auto-submit.
     - Lacks dynamic resend countdown timer with animated progress ring.
     - Needs full M3 20dp/28dp squircle geometry and strong feedback states.

### 1.2 Localization (`lib/l10n/`)
- Abstract declarations in `lib/l10n/app_localizations.dart` and implementations in `lib/l10n/app_localizations_en.dart` & `app_localizations_ru.dart`.
- Existing verification keys: `twoFaTitle`, `twoFaHeroTitle`, `twoFaHeroSubtitle`, `twoFaCodeLabel`, `twoFaCodeError`, `twoFaVerify`, `twoFaFailed`, `verifyEmailTitle`, `verifyEmailCodeLabel`, `verifyEmailSubmit`, `verifyEmailDone`, `resetPasswordRequestTitle`, `resetPasswordRequestSubmit`, `resetPasswordConfirmTitle`, `resetPasswordConfirmSubmit`, etc.
- **Missing L10n Keys**:
  - `authResendCode`: "Resend code" (EN) / "Отправить код повторно" (RU)
  - `authResendCountdown`: "Resend in {seconds}s" (EN) / "Повтор через {seconds} с" (RU)
  - `authCodeSent`: "Verification code resent" (EN) / "Код подтверждения отправлен повторно" (RU)
  - `authPasteCode`: "Paste code" (EN) / "Вставить код" (RU)

### 1.3 Static Analysis & Test Baseline
- `flutter test`: 129 test cases executed across 5 test suites. **100% Passed**.
- `flutter analyze`: **0 errors, 0 warnings, 0 issues found**.

---

## 2. Logic Chain

1. **User Requirement R3**:
   - Requires 6-digit OTP code input boxes with animated squircle focus states, auto-fill support, and auto-submit on completion.
   - Requires dynamic resend countdown timer with animated progress ring and pulse haptics on code expiry.
   - Requires password reset request and confirmation forms with M3 20dp/28dp squircle geometry and strong feedback states.
   - Requires 100% compliance with AGENTS.md rules (no `Colors.white`/`Colors.black`, no `withOpacity()`, Riverpod 3.x, 100% `context.l10n`).

2. **Component Architecture Decision**:
   - Create a shared, highly reusable **`M3OtpInputField`** widget in `lib/widgets/m3_otp_input_field.dart`:
     - 6 discrete squircle boxes (`BorderRadius.circular(18)`).
     - 4 visual states per cell: Inactive Empty, Focused (scaled 1.06x, `scheme.primary` border 2px, shadow glow), Filled (`scheme.primaryContainer` background, bold headlineMedium typography), and Error (`scheme.error` border + shake animation).
     - Integrated invisible text field capturing system keyboard and OS autofill (`AutofillHints.oneTimeCode`).
     - Automatic clipboard paste handling & auto-submit callback when 6th digit is entered.
   - Create a shared **`M3ResendCountdownTimer`** widget in `lib/widgets/m3_resend_countdown_timer.dart`:
     - Circular progress ring (`CircularProgressIndicator` with `value: remaining / totalDuration`, `strokeWidth: 2.5`).
     - Countdown label ("Resend in 45s" / "Повтор через 45 с").
     - On expiry (0s): Triggers `HapticService.selection()` / pulse haptic and renders an interactive "Resend code" button.
     - On tap: calls `onResend` callback, displays feedback toast, and restarts the countdown.

3. **Screen Modernization**:
   - Refactor `TwoFaScreen`: Replace custom keypad with `M3OtpInputField` + `M3ResendCountdownTimer` + hero badge + auto-submit.
   - Refactor `VerifyEmailScreen`: Replace `CodePreview` with `M3OtpInputField` + `M3ResendCountdownTimer` + read-only email card + pill button.
   - Refactor `ResetPasswordRequestScreen`: M3 20dp squircle email field + 28dp pill submit button + hero badge + high-contrast validation feedback.
   - Refactor `ResetPasswordConfirmScreen`: Read-only email card + `M3OtpInputField` + `M3ResendCountdownTimer` + new password field (20dp squircle) + pill submit button + auto-submit.

4. **Localization & Rule Compliance**:
   - Add missing resend and paste keys to `app_localizations.dart`, `app_localizations_en.dart`, and `app_localizations_ru.dart`.
   - Ensure all colors use `colorScheme.*`, alpha uses `.withValues(alpha: ...)`, and no hardcoded strings exist.

---

## 3. Caveats

1. **Keypad vs Keyboard on 2FA**:
   - Previous `TwoFaScreen` had a custom in-app numeric keypad. Replacing it with `M3OtpInputField` enables the standard native keyboard, SMS/email autofill, and paste support, which is the standard Android 15 / M3 Expressive UX.
2. **Backend Resend Endpoint**:
   - For `TwoFaScreen`, resending invokes `authProvider.notifier.login` or dedicated resend logic if available.
   - For `VerifyEmailScreen`, resending re-invokes registration or resend endpoint.
   - For `ResetPasswordConfirmScreen`, resending re-invokes `authProvider.notifier.requestPasswordReset`.
3. **No arb Code Generator Required**:
   - Localization is directly maintained in `lib/l10n/app_localizations*.dart` files without external build tools.

---

## 4. Conclusion & Concrete Specification

### 4.1 New Reusable Components

#### A. `lib/widgets/m3_otp_input_field.dart`
```dart
class M3OtpInputField extends StatefulWidget {
  const M3OtpInputField({
    super.key,
    required this.controller,
    this.length = 6,
    this.focusNode,
    this.onChanged,
    this.onCompleted,
    this.hasError = false,
    this.autoFocus = true,
    this.enabled = true,
  });

  final TextEditingController controller;
  final int length;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;
  final bool hasError;
  final bool autoFocus;
  final bool enabled;
  // ...
}
```
**Key Behavior**:
- Renders `length` (6) squircle boxes with `BorderRadius.circular(18)`.
- Animated scaling (`1.06x`) and `scheme.primary` highlight on active/current box.
- Hidden `TextField` with `TextInputType.number`, `AutofillHints.oneTimeCode`, and digits-only formatter.
- Auto-triggers `onCompleted(code)` when 6 digits are reached, accompanied by `HapticService.tap()`.
- Error state highlights boxes in `scheme.error` and triggers a horizontal shake animation.

#### B. `lib/widgets/m3_resend_countdown_timer.dart`
```dart
class M3ResendCountdownTimer extends StatefulWidget {
  const M3ResendCountdownTimer({
    super.key,
    this.durationSeconds = 60,
    required this.onResend,
    this.autoStart = true,
  });

  final int durationSeconds;
  final Future<void> Function() onResend;
  final bool autoStart;
  // ...
}
```
**Key Behavior**:
- Counts down from `durationSeconds` (default 60s).
- Renders `CircularProgressIndicator` (`value: remaining / durationSeconds`, `strokeWidth: 2.5`, `color: scheme.primary`).
- Displays `context.l10n.authResendCountdown(remaining)`.
- On reaching 0s: invokes `HapticFeedback.mediumImpact()` and switches to an active "Resend code" text button.
- On resend tap: triggers `onResend()`, displays toast, and restarts timer.

### 4.2 Screen Refactoring Specs

| Screen | Hero Shape | Inputs | Timer | Submit Action |
|---|---|---|---|---|
| `two_fa_screen.dart` | `Shapes.c9_sided_cookie` | `M3OtpInputField` (6-digit) | `M3ResendCountdownTimer` | Auto-submit on 6th digit + Pill Button |
| `verify_email_screen.dart` | `Shapes.c9_sided_cookie` | Read-only Email Card + `M3OtpInputField` | `M3ResendCountdownTimer` | Auto-submit + 28dp Pill Button |
| `reset_password_request_screen.dart` | `Shapes.c9_sided_cookie` | `M3AuthTextField` (Email, 20dp squircle) | N/A | 28dp Pill Button → `/reset-password/confirm` |
| `reset_password_confirm_screen.dart` | `Shapes.c9_sided_cookie` | Read-only Email + `M3OtpInputField` + `M3AuthTextField` (Password) | `M3ResendCountdownTimer` | 28dp Pill Button → `/login` |

### 4.3 Required Test Suite
Create `pulse_flutter/test/verification_screens_test.dart` covering:
1. `M3OtpInputField` renders 6 boxes, handles input, triggers `onChanged`, and auto-triggers `onCompleted`.
2. `M3ResendCountdownTimer` counts down, animates progress ring, triggers pulse haptics on expiry, and handles resend click.
3. `TwoFaScreen` widget test: verifies layout, OTP entry, error handling, and navigation on success.
4. `VerifyEmailScreen` widget test: verifies email display, OTP entry, resend timer, and submission.
5. `ResetPasswordRequestScreen` widget test: validates email format, handles loading state, and submits.
6. `ResetPasswordConfirmScreen` widget test: validates OTP + password length, resend timer, and submission.

---

## 5. Verification Method

To independently verify the implementation:

1. **Unit & Widget Test Suite**:
   ```bash
   cd pulse_flutter
   flutter test test/verification_screens_test.dart
   flutter test
   ```
   *Expected: All tests pass with 0 failures.*

2. **Static Analysis & Lint Verification**:
   ```bash
   cd pulse_flutter
   flutter analyze
   ```
   *Expected: 0 errors, 0 warnings, 0 lints.*

3. **Codebase Inspection**:
   - Confirm `lib/widgets/m3_otp_input_field.dart` and `lib/widgets/m3_resend_countdown_timer.dart` exist and contain no `Colors.white`/`Colors.black` or `.withOpacity()`.
   - Confirm `lib/screens/two_fa_screen.dart`, `verify_email_screen.dart`, `reset_password_request_screen.dart`, and `reset_password_confirm_screen.dart` use 20dp/28dp squircle geometry, `M3OtpInputField`, and `M3ResendCountdownTimer`.
   - Confirm all text strings are fetched from `context.l10n.*`.
