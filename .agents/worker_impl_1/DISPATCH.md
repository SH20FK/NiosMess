## 2026-09-01T04:11:25Z
You are Worker 1 for the Implementation Track of the Material 3 Expressive Auth & Onboarding Overhaul.

Working Directory: f:\Niosmess V2\.agents\worker_impl_1
User Request: f:\Niosmess V2\.agents\ORIGINAL_REQUEST.md
Scope Document: f:\Niosmess V2\.agents\orchestrator_2\PROJECT.md
Workspace: f:\Niosmess V2\pulse_flutter

MANDATORY: Read f:\Niosmess V2\.agents\ORIGINAL_REQUEST.md and PROJECT.md first.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Strict AGENTS.md requirements:
- Zero hardcoded colors (`Colors.white`, `Colors.black`, `Colors.grey`). Use `Theme.of(context).colorScheme.*` / semantic M3 color tokens.
- Zero `withOpacity()` — use `.withValues(alpha: ...)`
- Zero `dart:io` — use `package:universal_io/io.dart`
- Riverpod 3.x: `NotifierProvider` / `AsyncNotifierProvider` (no `StateProvider` / `StateNotifierProvider`)
- All user-facing strings must use `context.l10n.*` (update ARB files and run `flutter gen-l10n` as needed)
- 20dp/28dp squircle/pill geometry for auth inputs and buttons

Your Task:
1. In `lib/router/app_router.dart`, add a route alias for `/legal/terms` pointing to `TermsOfServiceScreen()` alongside `/legal/tos` so both routes work seamlessly when clicked in `RegisterScreen` (`lib/screens/register_screen.dart:246`).
2. Verify all auth & onboarding screens (`lib/screens/onboarding_screen.dart`, `lib/screens/setup_onboarding_screen.dart`, `lib/screens/login_screen.dart`, `lib/screens/register_screen.dart`, `lib/screens/two_fa_screen.dart`, `lib/screens/verify_email_screen.dart`, `lib/screens/reset_password_request_screen.dart`, `lib/screens/reset_password_confirm_screen.dart`) and widgets (`m3_auth_text_field.dart`, `m3_otp_input_field.dart`, `m3_resend_countdown_timer.dart`).
3. Run `flutter analyze lib/` to ensure 0 errors and 0 warnings.
4. Run all widget test suites:
   `flutter test test/screens/login_screen_test.dart test/screens/register_screen_test.dart test/onboarding_screens_test.dart test/verification_screens_test.dart`
5. Document all changes and test outputs in `f:\Niosmess V2\.agents\worker_impl_1\changes.md` and write `handoff.md`. Send a message when complete.
