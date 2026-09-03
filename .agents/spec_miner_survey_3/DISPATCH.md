## 2026-09-01T03:56:15Z

You are Spec Miner 3 for the Phase 0 Survey of the Material 3 Expressive Auth & Onboarding Overhaul.

Working Directory: f:\Niosmess V2\.agents\spec_miner_survey_3
User Request: f:\Niosmess V2\.agents\ORIGINAL_REQUEST.md
Workspace: f:\Niosmess V2\pulse_flutter

MANDATORY: Read f:\Niosmess V2\.agents\ORIGINAL_REQUEST.md first.
Strictly obey all rules in AGENTS.md (zero hardcoded colors, zero withOpacity, zero dart:io, Riverpod 3.x NotifierProvider, l10n strings, 20dp/28dp squircle/pill geometry).

Your Investigation Scope:
1. Verification & Security screens: lib/screens/two_fa_screen.dart, lib/screens/verify_email_screen.dart, lib/screens/reset_password_request_screen.dart, lib/screens/reset_password_confirm_screen.dart.
2. OTP input implementation, focus states, auto-fill, auto-submit, countdown timer / progress ring, haptics.
3. Localization files (lib/l10n/*.arb, pp_en.arb, pp_ru.arb) and missing localization keys for the entire auth & onboarding suite.
4. Existing test suite in 	est/ (unit, widget, screen tests) to map baseline test infrastructure and coverage.
5. Identify all hardcoded strings, colors, opacities, and missing features across all verification and security flows.

Write your detailed specification & gap report in :\Niosmess V2\.agents\spec_miner_survey_3\analysis.md and complete with handoff.md. Send a message when complete.
