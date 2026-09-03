# Execution Plan — M3 Expressive Auth & Onboarding Overhaul

## Phase 0: Survey & Assessment
- Dispatch 3 Explorers/Spec Miners in parallel to survey:
  1. `lib/screens/onboarding_screen.dart`, `lib/screens/setup_onboarding_screen.dart`, router integration, shared onboarding widgets.
  2. `lib/screens/login_screen.dart`, `lib/screens/register_screen.dart`, auth providers, biometrics, oauth.
  3. `lib/screens/two_fa_screen.dart`, `lib/screens/verify_email_screen.dart`, `lib/screens/reset_password_*.dart`, ARB localization files (`lib/l10n/`), existing test suites.
- Consolidate findings into `PROJECT.md` Feature Inventory & Interface Contracts.

## Phase 1: Dual Track Launch
- **E2E Testing Track**: Build comprehensive test runner and test cases (Tiers 1-4) covering all onboarding & auth flows, publishing `TEST_READY.md`.
- **Implementation Track**: Subdivided into 3 targeted milestones:
  - Milestone 1: Onboarding Carousel & Setup Wizard (M3 Expressive typography, organic squircle badges, expanding pill indicator, haptics, 28dp pill actions).
  - Milestone 2: Expressive Login & Registration (Brand header, organic hero avatar/logo, 20dp squircle inputs with `surfaceContainerHighest`, 56dp bottom pinned pill button with loading state, biometric tile, clean OAuth buttons, high contrast errors).
  - Milestone 3: Verification & Security Flows (2FA OTP with 6-digit squircle focus boxes, auto-fill, auto-submit, countdown timer with progress ring, Email Verification, Password Reset flows, 100% l10n).

## Phase 2: Verification, Adversarial Hardening & Final Gate
- Run 100% E2E test suite across all screens.
- Adversarial Coverage Hardening (Tier 5): Challenger gap audit & edge case stress testing.
- Forensic Auditor integrity review (zero hardcoded colors, zero `withOpacity()`, zero `dart:io`, 100% l10n).
- Static analysis check (`flutter analyze` with 0 issues).
- Version bump in `pubspec.yaml` according to SemVer protocol.
- Deliver Final Completion Report.
