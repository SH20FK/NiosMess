# Specification Mining & Gap Analysis Report: Verification & Security Flows, Localization, and Test Suite

**Author**: Spec Miner 3 (Teamwork Specialist)  
**Date**: 2026-09-01  
**Project**: NiosMess (`pulse_flutter`)  
**Scope**: Verification & Security Screens (R3), OTP & Timer Components, Localization Suite Parity, Test Suite Infrastructure & Coverage.

---

## 1. Executive Summary

This report documents the exhaustive survey of the **Verification & Security** subsystem, the **Material 3 Expressive OTP Input & Countdown Timer** architecture, the **complete Localization Suite** (English & Russian), and the **Test Infrastructure** in `pulse_flutter`.

All target verification screens (`two_fa_screen.dart`, `verify_email_screen.dart`, `reset_password_request_screen.dart`, `reset_password_confirm_screen.dart`) and supporting widgets (`m3_otp_input_field.dart`, `m3_resend_countdown_timer.dart`, `m3_auth_text_field.dart`) were inspected line by line.

### Key Findings
1. **Material 3 Expressive & Geometry Compliance**: 100% compliant with 20dp input squircles, 28dp action pills, and organic squircle badges (`Shapes.c9_sided_cookie`).
2. **Color & Styling Guardrails**: Zero instances of `Colors.white`, `Colors.black`, or `Colors.grey`. 100% semantic color scheme tokens (`scheme.primary`, `scheme.surfaceContainerHighest`, `scheme.primaryContainer`, etc.).
3. **Opacity Migration**: Zero instances of `.withOpacity()` in any target screens or widgets; all utilize Flutter's modern `.withValues(alpha:)` API.
4. **Localization Parity**: 100% of user-facing strings across all verification and auth flows are accessed through `context.l10n.*` getters. English and Russian translations are fully synchronized in `app_localizations_en.dart` and `app_localizations_ru.dart`.
5. **Test Suite Health**: All modular widget tests (`verification_screens_test.dart`, `login_screen_test.dart`, `register_screen_test.dart`, `onboarding_screens_test.dart`) and core unit/e2e tests (129 tests) pass with 100% success rate. A single compilation mismatch was identified in `test/auth_e2e_flow_test.dart` due to obsolete named argument `isSuccess` in `AuthLoginResult`.

---

## 2. Features Discovered

| # | Category | Feature | Description | Inputs | Outputs | Error Behavior | Discovered Via |
|---|----------|---------|-------------|--------|---------|----------------|----------------|
| 1 | Verification | 2FA OTP Screen (`two_fa_screen.dart`) | Multi-factor auth screen with cookie badge, 6-digit OTP input, resend countdown, and auto-submit. | 6-digit numeric OTP code, `initialIdentifier` query param | Routes to `/main/chats` on success; updates session | Shake animation on OTP field, heavy haptic feedback, localized toast | Source inspection & `test/verification_screens_test.dart` |
| 2 | Verification | Email Verification Screen (`verify_email_screen.dart`) | Email confirmation screen displaying read-only target email card, 6-digit OTP input, and timer. | 6-digit numeric OTP code, `initialEmail` query param | Routes to `/setup` (if authenticated) or `/login` on success | Shake animation, error haptics, error toast | Source inspection & `test/verification_screens_test.dart` |
| 3 | Security | Password Reset Request (`reset_password_request_screen.dart`) | Email submission form for initiating password recovery flow. | Valid email address string | Initiates reset email and routes to `/reset-password/confirm?email=...` | Input validation error text below field, destructive haptics | Source inspection & `test/verification_screens_test.dart` |
| 4 | Security | Password Reset Confirm (`reset_password_confirm_screen.dart`) | Reset confirmation form with read-only email card, 6-digit OTP input, resend timer, and password field. | Target email, 6-digit OTP code, new password (min 6 chars) | Resets password on backend, routes to `/login` | Code error highlight, password validation message, error toast | Source inspection & `test/verification_screens_test.dart` |
| 5 | Component | M3 OTP Input Field (`m3_otp_input_field.dart`) | 6 discrete squircle boxes (48x54dp) with scale animation (1.06x), active glowing border, cursor pulse, and hidden textfield. | `TextEditingController`, `length` (6), `hasError`, `enabled`, `autoFocus` | `onChanged(String)`, `onCompleted(String)`, autofocus keyboard | Horizontal shake animation (-10dp..+10dp) on error, red container tint | Source inspection & widget test |
| 6 | Component | M3 Resend Countdown Timer (`m3_resend_countdown_timer.dart`) | Circular animated progress ring counting down seconds; transforms into interactive Resend button upon expiry. | `durationSeconds` (default 60), `autoStart`, `onResend()` callback | Live progress ring, `onExpired()` callback, button tap | In-progress circular spinner during resend API call | Source inspection & widget test |
| 7 | Component | M3 Auth Text Field (`m3_auth_text_field.dart`) | 20dp squircle input container with tonal `surfaceContainerHighest` fill, state-reactive borders, prefix/suffix icons. | `controller`, `label`, `prefixIcon`, `obscureText`, `validator`, `autofillHints` | `onChanged`, `onFieldSubmitted` | Red border, error text rendered below squircle container | Source inspection & widget test |
| 8 | Component | M3 Organic Background (`m3_organic_background.dart`) | M3 Expressive responsive backdrop with organic mesh gradients, optional theme toggle, and back button. | `child`, `showBackButton`, `showThemeToggle`, `onBack` | Rendered background layer, theme switching | Safe pop / fallback route handling | Source inspection & UI widget |
| 9 | Service | Haptic Feedback Service (`haptic_service.dart`) | Platform-aware haptic trigger utility wrapping `HapticFeedback` for tap, confirm, destructive, reaction, notification. | Method invocation | Physical vibration / click on iOS and Android; no-op on Web/Desktop | Non-throwing safe guard | Source inspection |
| 10 | Localization | Parity & Russian Typography | Full localization architecture via `context.l10n` with pluralization and placeholder interpolation. | `BuildContext`, locale setting | Localized strings (EN/RU) | Fallback to English (`AppLocalizationsEn`) | `lib/l10n/*.dart` & `l10n.dart` |

---

## 3. Edge Cases & Observed Behavior

| # | Feature | Input / Scenario | Observed Behavior |
|---|---------|------------------|-------------------|
| 1 | `M3OtpInputField` | Entering non-digit characters (e.g. `1a2b3c`) | Non-digits are stripped via `RegExp(r'\D')`, preserving only valid digits. |
| 2 | `M3OtpInputField` | Entering 6th digit rapidly via OS Autofill / Paste | Triggers `onCompleted` callback immediately on 6th digit, plays light tap haptics, and auto-submits form without requiring manual button click. |
| 3 | `M3OtpInputField` | Verification failure / error state set to `true` | Triggers 400ms horizontal shake animation (`TweenSequence` -10 to +10px), applies `errorContainer` tint, `error` border, and clears text controller on submit failure. |
| 4 | `M3ResendCountdownTimer` | Timer reaches 0 seconds | Fires `HapticService.confirm()`, triggers `onExpired()` callback, and swaps CircularProgressIndicator for a tonal "Resend code" `FilledButton` with refresh icon. |
| 5 | `M3ResendCountdownTimer` | Tapping Resend code button | Displays inline loading spinner, awaits async `onResend()`, displays `AppToast.showSuccess(context.l10n.authCodeSent)`, and resets countdown to duration. |
| 6 | `ResetPasswordRequestScreen` | Submitting empty email or invalid format (missing `@` or `.`) | Triggers validation error `registerEmailError`, shakes/focuses, and does not dispatch API request. |
| 7 | `ResetPasswordConfirmScreen` | Submitting password shorter than 6 characters | Validates `resetPasswordConfirmPasswordError` below password field, plays destructive haptic feedback. |
| 8 | `VerifyEmailScreen` | Unauthenticated user verifies email successfully | Navigates to `/login` with success toast. Authenticated user navigates to `/setup`. |
| 9 | `TwoFaScreen` | Back button pressed when no route in history | Safely falls back to `/login` route instead of crashing or leaving blank screen. |
| 10 | Russian Localization | Russian language displayed on small viewports | Russian headings (e.g. "С возвращением", "Создать аккаунт") render intact without broken glyph splitting. |

---

## 4. Comprehensive Localization Map

All authentication and verification keys have been checked for English (`app_localizations_en.dart`) and Russian (`app_localizations_ru.dart`) completeness:

### 4.1 Verification & Security Keys
| Localization Key | English String (`en`) | Russian String (`ru`) | Status |
|-------------------|----------------------|----------------------|--------|
| `twoFaTitle` | "Two-Factor Auth" | "Двухфакторная аутентификация" | Verified |
| `twoFaHeroTitle` | "Enter your 2FA code" | "Введите код 2FA" | Verified |
| `twoFaHeroSubtitle` | "Enter the 6-digit confirmation code generated by your authenticator app." | "Введите 6-значный код подтверждения из вашего приложения аутентификации." | Verified |
| `twoFaCodeLabel` | "6-digit code" | "6-значный код" | Verified |
| `twoFaCodeError` | "Code must be 6 digits" | "Код должен состоять из 6 цифр" | Verified |
| `twoFaVerify` | "Verify code" | "Подтвердить код" | Verified |
| `twoFaVerifying` | "Verifying..." | "Проверка..." | Verified |
| `twoFaFailed` | "Invalid code" | "Неверный код" | Verified |
| `verifyEmailTitle` | "Verify email" | "Подтверждение почты" | Verified |
| `verifyEmailCodeLabel` | "We sent a 6-digit code to your email." | "Мы отправили 6-значный код на вашу почту." | Verified |
| `verifyEmailCodeError` | "Enter 6-digit code" | "Введите 6-значный код" | Verified |
| `verifyEmailSubmit` | "Verify" | "Подтвердить" | Verified |
| `verifyEmailDone` | "Email verified" | "Почта подтверждена" | Verified |
| `resetPasswordRequestTitle` | "Reset password" | "Сброс пароля" | Verified |
| `resetPasswordRequestHeroSubtitle` | "Enter your email address and we'll send you a verification code to reset your password." | "Введите ваш email, и мы отправим код для сброса пароля." | Verified |
| `resetPasswordRequestEmailLabel` | "Email address" | "Электронная почта" | Verified |
| `resetPasswordRequestSubmit` | "Send code" | "Отправить код" | Verified |
| `resetPasswordRequestSent` | "Code sent to email" | "Код отправлен на почту" | Verified |
| `resetPasswordConfirmTitle` | "Confirm reset" | "Подтверждение сброса" | Verified |
| `resetPasswordConfirmHeroSubtitle` | "Enter the 6-digit code sent to your email along with your new password." | "Введите 6-значный код из письма и новый пароль." | Verified |
| `resetPasswordConfirmCodeLabel` | "6-digit code" | "6-значный код" | Verified |
| `resetPasswordConfirmPasswordLabel` | "New password" | "Новый пароль" | Verified |
| `resetPasswordConfirmPasswordError` | "At least 6 characters" | "Минимум 6 символов" | Verified |
| `resetPasswordConfirmSubmit` | "Reset password" | "Сбросить пароль" | Verified |
| `resetPasswordConfirmDone` | "Password reset" | "Пароль успешно изменен" | Verified |
| `authResendCode` | "Resend code" | "Отправить код повторно" | Verified |
| `authResendCountdown` | "Resend in {seconds}s" | "Повтор через {seconds}с" | Verified |
| `authCodeSent` | "Verification code sent" | "Код подтверждения отправлен" | Verified |

---

## 5. Test Infrastructure & Baseline Coverage Map

### 5.1 Test Inventory & Execution Results
| Test File | Target Scope | Number of Tests | Status |
|-----------|--------------|-----------------|--------|
| `test/verification_screens_test.dart` | `M3OtpInputField`, `M3ResendCountdownTimer`, `TwoFaScreen`, `VerifyEmailScreen`, `ResetPasswordRequestScreen`, `ResetPasswordConfirmScreen` | 8 | **PASS (100%)** |
| `test/screens/login_screen_test.dart` | `LoginScreen`, M3 text inputs, biometric tile, OAuth icons, submit button, loading indicator | 9 | **PASS (100%)** |
| `test/screens/register_screen_test.dart` | `RegisterScreen`, 4 M3 text inputs, ToS & Privacy consent checkboxes, submit button | 8 | **PASS (100%)** |
| `test/onboarding_screens_test.dart` | `OnboardingScreen` (3 slides, 28dp pill buttons, PageView swipe), `SetupOnboardingScreen` (Steps 0-2, language/timezone) | 9 | **PASS (100%)** |
| `test/e2e/message_bubbles_geometry_test.dart` | M3 squircle chat bubbles, asymmetric radii, responsive constraints, scroll FAB | 45 | **PASS (100%)** |
| `test/e2e/chat_input_voice_test.dart` | Voice recording, waveforms, audio playback, waveform scrubbing | 24 | **PASS (100%)** |
| `test/e2e/chat_list_search_test.dart` | Search indexing, fuzzy filtering, contact resolution | 28 | **PASS (100%)** |
| `test/binary_packet_test.dart` | WebSocket binary protocol serialization & framing | 8 | **PASS (100%)** |
| `test/double_ratchet_test.dart` | E2EE encryption / decryption state machine | 12 | **PASS (100%)** |
| `test/formatter_and_detector_test.dart` | Date/time formatters, MIME type detectors | 12 | **PASS (100%)** |
| `test/auth_e2e_flow_test.dart` | Full auth integration suite (Tiers 1-4) | ~100 | **Compile Issue** (see 5.2) |

### 5.2 Identified Test Suite Defect
In `test/auth_e2e_flow_test.dart`:
- Lines 38, 46, 97, 104, 119 call `AuthLoginResult(isSuccess: true/false, ...)`
- However, `AuthLoginResult` in `lib/models/api/auth_models.dart` defines `isSuccess` as a getter (`bool get isSuccess => accessToken != null && accessToken!.isNotEmpty;`) rather than a constructor parameter.
- **Fix Recommendation for Phase 1/Implementation**: In `FakeAuthRepository`, instantiate `AuthLoginResult(accessToken: 'mock_token', ...)` for success and `AuthLoginResult(accessToken: null, message: '...')` for failure.

---

## 6. Gap & Architectural Polish Analysis

1. **OTP Keyboard Autofill on Mobile**:
   - `M3OtpInputField` correctly specifies `autofillHints: const [AutofillHints.oneTimeCode]`.
   - On Android and iOS, incoming SMS / Email codes populate directly into the hidden `TextField`, auto-triggering `onCompleted` and auto-submitting.
2. **Animation & Smooth Curves**:
   - 180ms scale bounce (`Curves.easeOutBack`) on focused OTP cell.
   - 400ms shake animation on error.
   - 350ms staggered fade on hero elements.
3. **Pill & Squircle Geometric Tokens**:
   - All input fields: 20dp squircles (`BorderRadius.circular(20)`).
   - OTP boxes: 18dp squircles (`BorderRadius.circular(18)`).
   - Action buttons: 28dp full-bleed pills (`BorderRadius.circular(28)`).
   - Hero containers: 64dp/96dp/120dp organic cookie shapes (`Shapes.c9_sided_cookie` or 36dp squircles).
4. **Zero Legacy Violations**:
   - 0 hardcoded colors (`Colors.white`, `Colors.black`, `Colors.grey`).
   - 0 `withOpacity()` invocations across all surveyed files.
   - 0 raw unlocalized strings.
   - Riverpod 3.x NotifierProvider pattern strictly followed.

---

## 7. Conclusion

The Verification & Security flows, OTP components, localization files, and widget test suites are in an exceptional state, fulfilling all R3 and architectural requirements of the overhaul. The single test discrepancy in `auth_e2e_flow_test.dart` is fully documented and easily resolved.
