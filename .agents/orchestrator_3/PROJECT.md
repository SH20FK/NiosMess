# Project: Material 3 Expressive Auth & Onboarding Overhaul

## Architecture
- **Framework & State**: Flutter 3.x, Riverpod 3.x (`NotifierProvider`), `go_router` v17.x.
- **Visual Design**: Material 3 Expressive (Android 15 / Google Messages design system).
- **Geometric Design Tokens**: 20dp squircles for input fields, text fields, cards; 28dp pill radius for primary action buttons (56dp height), 8dp/28dp expanding pill indicators.
- **Color System**: Semantic M3 color tokens (`colorScheme.surface`, `colorScheme.surfaceContainerHighest`, `colorScheme.primaryContainer`, `colorScheme.onPrimaryContainer`, `colorScheme.error`). Zero hardcoded colors (`Colors.white`/`Colors.black`/`Colors.grey`), zero `withOpacity()` (all `withValues(alpha:)`).
- **Platform & I/O**: `package:universal_io/io.dart` (zero `dart:io`).
- **Localization**: 100% `context.l10n.*` (English and Russian full parity).

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Onboarding Carousel | 3-slide M3 Expressive carousel with Lottie animations, 36dp squircle container, 28dp pill expanding indicator, haptics, theme toggle, and 28dp pill action buttons | M1 | ORIGINAL_REQUEST §R1 |
| 2 | Setup Wizard | Multi-step setup flow with breathing hero squircle, language selection (EN/RU/System), automatic/manual timezone selector with bottom sheet picker, and live 1Hz ticking clock | M1 | ORIGINAL_REQUEST §R1 |
| 3 | M3 Expressive Login | Brand hero header (`AppLogoMark`), 20dp squircle text inputs with `surfaceContainerHighest` fill, biometric login trigger tile, OAuth buttons, and 56dp/28dp pinned action button with loading spinner | M2 | ORIGINAL_REQUEST §R2 |
| 4 | M3 Expressive Registration | 4-field registration (display name, username, email, password), consent checkboxes with Terms/Privacy links, password strength/visibility, and 56dp/28dp action button | M2 | ORIGINAL_REQUEST §R2 |
| 5 | Route Alignment | Route aliasing in `app_router.dart` ensuring `/legal/terms` and `/legal/tos` both route seamlessly to Terms of Service | M2 | Explorer 2 Survey |
| 6 | 2FA OTP Verification | 6-digit OTP input boxes with squircle focus states, active bounce, cursor pulse, error shake, OS autofill, auto-submit on completion, and 28dp pill submit button | M3 | ORIGINAL_REQUEST §R3 |
| 7 | Email Verification Flow | Read-only email squircle container, 6-digit OTP input, 60s countdown timer with progress ring, haptics, and 28dp pill action button | M3 | ORIGINAL_REQUEST §R3 |
| 8 | Password Reset Request | Email input with 20dp squircle geometry, input validation, loading indicator, and transition to confirmation | M3 | ORIGINAL_REQUEST §R3 |
| 9 | Password Reset Confirmation | Read-only email card, 6-digit OTP input, resend countdown timer, new password field with visibility toggle, and 28dp pill reset button | M3 | ORIGINAL_REQUEST §R3 |
| 10 | Resend Countdown Timer | 60-second animated circular progress indicator, remaining time formatting, pulse haptics on code expiry, and reactive resend button | M3 | ORIGINAL_REQUEST §R3 |
| 11 | Comprehensive E2E Testing Suite | Tier 1 (Feature Coverage), Tier 2 (Boundary & Corner), Tier 3 (Cross-Feature Combinations), Tier 4 (Real-World Application Scenarios) in `test/auth_e2e_flow_test.dart` | Test Track | ORIGINAL_REQUEST Acceptance |
| 12 | SemVer Versioning & Audit | Automatic version bump in `pubspec.yaml` (SemVer) and forensic integrity validation | M4 / Audit | AGENTS.md |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Onboarding & Setup Wizard Suite | `onboarding_screen.dart`, `setup_onboarding_screen.dart`, page indicators, hero badges, live clock, localization, widget tests | none | DONE |
| M2 | Login, Registration & Route Alignment | `login_screen.dart`, `register_screen.dart`, `m3_auth_text_field.dart`, biometric auth, `/legal/terms` route alias, widget tests | none | DONE |
| M3 | Verification & Security Flows | `two_fa_screen.dart`, `verify_email_screen.dart`, `reset_password_*.dart`, `m3_otp_input_field.dart`, `m3_resend_countdown_timer.dart`, widget tests | none | DONE |
| E2E | E2E Testing Suite Track | Comprehensive 4-tier E2E test suite in `test/auth_e2e_flow_test.dart` | M1, M2, M3 | DONE |
| M4 | Final E2E Pass, SemVer & Victory Gate | Pass 100% test suite (`flutter test`), 0 analysis warnings (`flutter analyze`), SemVer bump in `pubspec.yaml`, 2 Reviewers + 2 Challengers + Forensic Auditor, victory handoff | E2E, M1, M2, M3 | IN_PROGRESS |

## Interface Contracts
### `app_router.dart` ↔ Screens
- `/onboarding` -> `OnboardingScreen()`
- `/setup` -> `SetupOnboardingScreen()`
- `/login` -> `LoginScreen()`
- `/register` -> `RegisterScreen()`
- `/2fa?identifier=<id>` -> `TwoFaScreen(identifier: ...)`
- `/verify-email?email=<email>` -> `VerifyEmailScreen(email: ...)`
- `/reset-password` -> `ResetPasswordRequestScreen()`
- `/reset-password/confirm?email=<email>` -> `ResetPasswordConfirmScreen(email: ...)`
- `/legal/tos` & `/legal/terms` -> `TermsOfServiceScreen()`
- `/legal/privacy` -> `PrivacyPolicyScreen()`

## Code Layout
- `lib/screens/onboarding_screen.dart`
- `lib/screens/setup_onboarding_screen.dart`
- `lib/screens/login_screen.dart`
- `lib/screens/register_screen.dart`
- `lib/screens/two_fa_screen.dart`
- `lib/screens/verify_email_screen.dart`
- `lib/screens/reset_password_request_screen.dart`
- `lib/screens/reset_password_confirm_screen.dart`
- `lib/widgets/m3_auth_text_field.dart`
- `lib/widgets/m3_otp_input_field.dart`
- `lib/widgets/m3_resend_countdown_timer.dart`
- `lib/widgets/m3_organic_background.dart`
- `lib/widgets/app_logo_mark.dart`
- `lib/core/theme/app_theme.dart`
- `lib/router/app_router.dart`
- `test/screens/login_screen_test.dart`
- `test/screens/register_screen_test.dart`
- `test/onboarding_screens_test.dart`
- `test/verification_screens_test.dart`
- `test/auth_e2e_flow_test.dart`
