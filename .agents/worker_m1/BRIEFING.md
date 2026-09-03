# BRIEFING — 2026-09-01T00:15:02Z

## Mission
Implement Milestone 1: Onboarding Carousel & Setup Wizard Overhaul (R1) in `pulse_flutter`.

## 🔒 My Identity
- Archetype: worker
- Roles: implementer, qa, specialist
- Working directory: f:\Niosmess V2\.agents\worker_m1
- Original parent: 6d6a9f6c-f8f9-446f-b547-732f49c9092f
- Milestone: Milestone 1: Onboarding Carousel & Setup Wizard Overhaul (R1)

## 🔒 Key Constraints
- Exclusive file write ownership:
  - `pulse_flutter/lib/screens/onboarding_screen.dart`
  - `pulse_flutter/lib/screens/setup_onboarding_screen.dart`
  - `pulse_flutter/test/onboarding_screens_test.dart`
- Zero hardcoded colors (no `Colors.white`, `Colors.black`, `Colors.grey`). Use `Theme.of(context).colorScheme.*`.
- Zero `withOpacity()` — use `.withValues(alpha: ...)`.
- Zero `dart:io` — use `package:universal_io/io.dart`.
- Riverpod 3.x conventions.
- 100% `context.l10n.*` (no raw user-facing strings).
- Maintain genuine logic, no facade/dummy code.
- Flutter analyze 0 errors/warnings and all tests passing.

## Current Parent
- Conversation ID: 6d6a9f6c-f8f9-446f-b547-732f49c9092f
- Updated: not yet

## Task Summary
- **What to build**: Full M3 Expressive overhaul of `onboarding_screen.dart` and `setup_onboarding_screen.dart`, plus comprehensive tests in `test/onboarding_screens_test.dart`.
- **Success criteria**: 
  - Expressive carousel with Lottie organic squircle containers, brand header with `AppLogoMark(size: 88)` spring animation, animated expanding pill indicators, 56dp pill action buttons, Riverpod state integration.
  - Multi-step setup onboarding wizard (Welcome, Language, Timezone) with squircle hero badges, live clock selection cards, pill indicator, smooth step transitions.
  - Tests covering carousel navigation, setup steps, skip/finish callbacks, state modifications.
  - Clean `flutter analyze` and `flutter test`.
- **Interface contracts**: `f:\Niosmess V2\PROJECT.md`, `f:\Niosmess V2\.agents\ORIGINAL_REQUEST.md`

## Key Decisions Made
- [TBD]

## Artifact Index
- `f:\Niosmess V2\.agents\worker_m1\DISPATCH.md` — Dispatch prompt
- `f:\Niosmess V2\.agents\worker_m1\BRIEFING.md` — Situational awareness
- `f:\Niosmess V2\.agents\worker_m1\progress.md` — Liveness and task progress

## Change Tracker
- **Files modified**: none yet
- **Build status**: unknown
- **Pending issues**: none

## Quality Status
- **Build/test result**: pending
- **Lint status**: pending
- **Tests added/modified**: pending

## Loaded Skills
- None
