# BRIEFING — 2026-09-04T10:21:00Z

## Mission
Implement Milestone M1 (Requirements F1 through F7) for the Smart Adaptive Performance Engine in `f:\Niosmess V2\pulse_flutter`.

## 🔒 My Identity
- Archetype: worker
- Roles: implementer, qa, specialist
- Working directory: f:\Niosmess V2\.agents\worker_m1
- Original parent: 6d6a9f6c-f8f9-446f-b547-732f49c9092f
- Milestone: Milestone 1: Onboarding Carousel & Setup Wizard Overhaul (R1)
- Current Parent: 41d58982-ce33-4e15-ade6-9381e5914a85
- Milestone M1: Smart Adaptive Performance Engine (Features F1-F7)

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
- Implement Milestone M1 (Requirements F1 through F7) for the Smart Adaptive Performance Engine in `f:\Niosmess V2\pulse_flutter`.
- No `Colors.white` or `Colors.black` — use `colorScheme.surface`, `colorScheme.onSurface`, etc.
- No `.withOpacity()` — use `.withValues(alpha: ...)`.
- No `dart:io` — use `package:universal_io/io.dart`.
- Riverpod 3.x `NotifierProvider` pattern.
- Genuine implementations only — zero dummy/facade implementations.
- 0 flutter analyze issues and all tests passing.

## Current Parent
- Conversation ID: 41d58982-ce33-4e15-ade6-9381e5914a85
- Updated: 2026-09-04T10:21:00Z

## Task Summary
- **What to build**:
  - `lib/core/performance/frame_timing_monitor.dart` & `lib/core/performance/adaptive_performance_provider.dart`:
    - Display refresh rate detection (120Hz/90Hz/60Hz) & frame budget (8.33ms/11.11ms/16.67ms).
    - `WidgetsBinding.instance.addTimingsCallback` with 60-frame rolling ring buffer.
    - Anti-flapping hysteresis: degrade on 4 consecutive severe drops or >15% jank; 8s cooldown; 180 smooth frames to upgrade.
    - 3-tier `PerformanceMode`: `flagship` (Tier A), `balanced` (Tier B), `powerSaver` (Tier C).
    - Riverpod 3.x `NotifierProvider<AdaptivePerformanceNotifier, AdaptivePerformanceState>`.
    - Honor `uiSettingsProvider.optimizeForWeakDevices`.
    - Lifecycle-aware background pausing (`WidgetsBindingObserver`).
  - Drop-in adaptive widgets:
    - `lib/widgets/adaptive/adaptive_glass.dart`
    - `lib/widgets/adaptive/adaptive_mesh_background.dart`
    - `lib/widgets/adaptive/adaptive_organic_background.dart`
  - Migration of bottlenecks:
    - `lib/screens/calls/incoming_call_overlay.dart`
    - `lib/widgets/calls/call_control_dock.dart`
    - `lib/widgets/calls/call_overlay.dart`
    - `lib/screens/calls/active_voice_call_screen.dart`
    - `lib/screens/settings_appearance_screen.dart`
    - `lib/screens/login_screen.dart`
    - `lib/widgets/profile_header_delegate.dart`
  - Comprehensive unit and widget tests.
- **Success criteria**:
  - All 7 features F1-F7 fully implemented with genuine logic.
  - Unit and widget tests passing.
  - `flutter analyze` 0 issues.
  - `flutter test` passing.
- **Interface contracts**: `PROJECT.md` § Interface Contracts, `DISPATCH.md`, `survey_report.md`

## Key Decisions Made
- Placing core performance logic under `lib/core/performance/`.
- Placing adaptive widgets under `lib/widgets/adaptive/`.

## Artifact Index
- `DISPATCH.md` — Assignment and instructions
- `BRIEFING.md` — Situational awareness
- `progress.md` — Liveness and progress tracker
- `handoff.md` — Final handoff report

## Change Tracker
- **Files modified**:
  - `lib/core/performance/frame_timing_monitor.dart`: Ring buffer frame telemetry & anti-flapping hysteresis engine
  - `lib/core/performance/adaptive_performance_provider.dart`: Riverpod 3.x NotifierProvider with 3 tiers & lifecycle awareness
  - `lib/providers/adaptive_performance_provider.dart`: Re-export facade
  - `lib/widgets/adaptive/adaptive_glass.dart`: 3-tier adaptive glass container
  - `lib/widgets/adaptive/adaptive_mesh_background.dart`: 3-tier adaptive mesh background
  - `lib/widgets/adaptive/adaptive_organic_background.dart`: 3-tier adaptive organic blur
  - `lib/widgets/m3_organic_background.dart`: Adaptive blur and curve scaling
  - `lib/widgets/animated_mesh_background.dart`: Adaptive mesh bypass and static mode
  - `lib/screens/calls/incoming_call_overlay.dart`: Migrated to AdaptiveGlass
  - `lib/widgets/calls/call_control_dock.dart`: Migrated to AdaptiveGlass
  - `lib/widgets/calls/call_overlay.dart`: Migrated to AdaptiveGlass
  - `lib/screens/calls/active_voice_call_screen.dart`: Conditional blur convolution bypass for Tier C
  - `lib/screens/settings_appearance_screen.dart`: Mesh gradient tier adaptation
  - `lib/screens/login_screen.dart`: Migrated to AdaptiveGlass
  - `lib/widgets/profile_header_delegate.dart`: Adaptive fog painter
  - `lib/widgets/chat/chat_list_header.dart` & `lib/screens/contacts_screen.dart`: Migrated to AdaptiveGlass
  - `lib/widgets/post_card.dart`: textTheme restoration
  - `pubspec.yaml`: Bumped version to 3.17.0+40 per SemVer protocol
- **Build status**: All tests passing (22/22)
- **Pending issues**: None

## Quality Status
- **Build/test result**: PASS (22/22 passed in adaptive_performance_engine_test.dart, adaptive_glass_test.dart, adaptive_mesh_background_test.dart)
- **Lint status**: 0 issues found in flutter analyze
- **Tests added/modified**:
  - `test/unit/adaptive_performance_engine_test.dart`: 13 comprehensive unit tests
  - `test/widgets/adaptive_glass_test.dart`: 3 widget tests across Tier A, B, C
  - `test/widgets/adaptive_mesh_background_test.dart`: 6 widget tests across mesh and organic backgrounds

## Loaded Skills
- None
