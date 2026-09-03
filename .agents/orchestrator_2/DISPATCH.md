# Dispatch Record

## 2026-09-01T03:54:52Z
You are the Project Orchestrator for the Material 3 Expressive UI/UX overhaul of the authentication and onboarding suite in `pulse_flutter`.

Your working directory is: `f:\Niosmess V2\.agents\orchestrator_2`
The authoritative user request is located at: `f:\Niosmess V2\.agents\ORIGINAL_REQUEST.md`
The Flutter workspace is: `f:\Niosmess V2\pulse_flutter`

Read `f:\Niosmess V2\.agents\ORIGINAL_REQUEST.md` carefully:
The goal is a complete Material 3 Expressive (Google Messages / Android 15 style) UI/UX overhaul of the entire authentication and onboarding suite in `pulse_flutter`:
1. Onboarding Carousel (`lib/screens/onboarding_screen.dart`)
2. Setup Wizard (`lib/screens/setup_onboarding_screen.dart`)
3. Login (`lib/screens/login_screen.dart`)
4. Registration (`lib/screens/register_screen.dart`)
5. 2FA OTP verification (`lib/screens/two_fa_screen.dart`)
6. Email Verification (`lib/screens/verify_email_screen.dart`)
7. Password Reset (`lib/screens/reset_password_request_screen.dart`, `lib/screens/reset_password_confirm_screen.dart`)

Strict AGENTS.md requirements:
- Zero hardcoded colors (`Colors.white`, `Colors.black`, `Colors.grey`). Use `Theme.of(context).colorScheme.*` / semantic M3 color tokens.
- Zero `withOpacity()` — use `.withValues(alpha: ...)`
- Zero `dart:io` — use `package:universal_io/io.dart`
- Riverpod 3.x: `NotifierProvider` / `AsyncNotifierProvider` (no `StateProvider` / `StateNotifierProvider`)
- All user-facing strings must use `context.l10n.*` (update ARB files and run `flutter gen-l10n` as needed)
- 20dp/28dp squircle/pill geometry for auth inputs and buttons
- Ensure `flutter analyze` has 0 errors/warnings and `flutter test` passes 100%
- Inspect all changes and bump version in `pubspec.yaml` (SemVer)
- Maintain `progress.md`, `plan.md`, and `BRIEFING.md` in your working directory.
