# DISPATCH — Worker M1: Smart Adaptive Performance Engine

## Mission
Implement Milestone M1 (Requirements F1 through F7) for the Smart Adaptive Performance Engine in `f:\Niosmess V2\pulse_flutter`.

## Mandatory Warning
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

## Authoritative Inputs
- Architecture & Survey Blueprint: `f:\Niosmess V2\.agents\explorer_survey_1_gen2\survey_report.md`
- Explorer 1 Handoff: `f:\Niosmess V2\.agents\explorer_survey_1_gen2\handoff.md`
- Project Index & Contracts: `f:\Niosmess V2\.agents\orchestrator_5\PROJECT.md`
- User Request: `f:\Niosmess V2\.agents\ORIGINAL_REQUEST.md`
- Rules & Conventions: `f:\Niosmess V2\AGENTS.md`

## Scope of Work (Features F1 through F7)
1. **`lib/core/performance/frame_timing_monitor.dart` & `lib/core/performance/adaptive_performance_provider.dart`**:
   - Query display refresh rate via `PlatformDispatcher.views.first.display.refreshRate` (default to 60.0 if <= 0).
   - Set target frame budget: 8.33ms (120Hz), 11.11ms (90Hz), 16.67ms (60Hz).
   - Track frame metrics via `WidgetsBinding.instance.addTimingsCallback` using a 60-frame rolling ring buffer.
   - Implement anti-flapping hysteresis:
     - Degrade tier when 4 consecutive severe drops occur or jank ratio > 15%.
     - Minimum 8-second downgrade cooldown before any upgrade is permitted.
     - Require 180 consecutive smooth frames under budget before upgrading tier.
   - 3-Tier `PerformanceMode`: `flagship` (Tier A), `balanced` (Tier B), `powerSaver` (Tier C).
   - Expose `AdaptivePerformanceState` through Riverpod 3.x `NotifierProvider<AdaptivePerformanceNotifier, AdaptivePerformanceState>` (`adaptivePerformanceProvider`).
   - Honor user override `uiSettingsProvider.optimizeForWeakDevices` (forces `powerSaver` / Tier C).
   - Implement `WidgetsBindingObserver` to pause telemetry when the app is in background (`AppLifecycleState.paused` / `inactive`).
2. **Drop-in Adaptive Widgets**:
   - `lib/widgets/adaptive/adaptive_glass.dart`:
     - Tier A: full `BackdropFilter` (sigma 18-24).
     - Tier B: reduced blur (sigma 6-8).
     - Tier C: solid tonal surface container (`colorScheme.surfaceContainerLow` or `surfaceContainerHighest` with semantic opacity), 0 blur passes.
   - `lib/widgets/adaptive/adaptive_mesh_background.dart`:
     - Replaces unconstrained `AnimatedMeshGradient`. On Tier C or `optimizeForWeakDevices`, renders an ultrafast tonal linear/radial gradient.
   - `lib/widgets/adaptive/adaptive_organic_background.dart`:
     - Adapts `MaskFilter.blur` in `M3OrganicBackground`: full on Tier A, reduced on Tier B, disabled/tonal on Tier C.
3. **Migration of Bottleneck Locations**:
   - `lib/screens/calls/incoming_call_overlay.dart`: Replace raw `BackdropFilter` (sigma 24) with `AdaptiveGlass`.
   - `lib/widgets/calls/call_control_dock.dart`: Replace raw `BackdropFilter` (sigma 24) with `AdaptiveGlass`.
   - `lib/widgets/calls/call_overlay.dart`: Replace raw `BackdropFilter` (sigma 18) with `AdaptiveGlass`.
   - `lib/screens/calls/active_voice_call_screen.dart`: Reduce or conditionally bypass extreme `MaskFilter.blur` (110, 120) based on `adaptivePerformanceProvider`.
   - `lib/screens/settings_appearance_screen.dart`: Check `adaptivePerformanceProvider` and `optimizeForWeakDevices` before running dual `AnimatedMeshGradient` layers.
   - `lib/screens/login_screen.dart`: Replace raw `BackdropFilter` in `_buildLoadingOverlay` with `AdaptiveGlass`.
   - `lib/widgets/profile_header_delegate.dart`: Optimize `MaskFilter.blur` across the 5 clusters during scroll.

## Code Conventions (Strict AGENTS.md Adherence)
- No `Colors.white` or `Colors.black` — use `colorScheme.surface`, `colorScheme.onSurface`, etc.
- No `.withOpacity()` — use `.withValues(alpha: ...)`
- No `dart:io` — use `package:universal_io/io.dart`
- Riverpod 3.x `NotifierProvider` pattern.
- Run `flutter analyze` and `flutter test` from `f:\Niosmess V2\pulse_flutter`. 0 issues required.

## Deliverables
- Write `handoff.md` in `f:\Niosmess V2\.agents\worker_m1` with list of files modified, verification commands run, and test outcomes.
- Notify parent orchestrator when complete.

## 2026-09-04T10:20:25Z
You are Worker M1. Your working directory is f:\Niosmess V2\.agents\worker_m1.
Read your instructions at f:\Niosmess V2\.agents\worker_m1\DISPATCH.md, survey blueprint at f:\Niosmess V2\.agents\explorer_survey_1_gen2\survey_report.md, and conventions at f:\Niosmess V2\AGENTS.md.
Implement Milestone M1 (Smart Adaptive Performance Engine, Features F1-F7) in f:\Niosmess V2\pulse_flutter.
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.
Adhere strictly to AGENTS.md conventions (no Colors.white/black, use withValues(alpha:), Riverpod NotifierProvider, no dart:io).
Run `flutter analyze` and `flutter test` from f:\Niosmess V2\pulse_flutter to verify 0 issues.
Write handoff.md in your working directory and send a completion message to parent.
