# Orchestrator Execution Plan: Nios ID Unified Auth Flow & M3 Expressive Auth Hub

## Phase 0: Survey & Scope Mapping (Parallel Explorers & Spec Miner)
- [ ] 0.1 Spawn Spec Miner on NIOSMESS_FRONTEND_LOGIN.md and OAuth/API specifications.
- [ ] 0.2 Spawn Explorer 1 on current `pulse_flutter` authentication, routing, models, and repositories.
- [ ] 0.3 Spawn Explorer 2 on `pulse_flutter` UI screens, theme system, M3 Expressive components, l10n, and existing tests.
- [ ] 0.4 Aggregate survey findings into `PROJECT.md` (Feature Inventory, Architecture, Milestones, Interface Contracts, Code Layout).

## Phase 1: Milestone Decomposition & Track Setup
- [ ] 1.1 Finalize milestone scopes and contracts in `PROJECT.md`.
- [ ] 1.2 Initialize E2E Testing Track with `TEST_INFRA.md`.
- [ ] 1.3 Dispatch sub-orchestrators for milestones and testing track.

## Phase 2: Execution & Milestone Iterations (Explorer -> Worker -> Reviewer -> Challenger -> Auditor -> Gate)
- [ ] 2.1 **Milestone M1**: Core PKCE Generator, Ephemeral State Storage, OAuth URL builder & Callback Parser, Token Exchange Service.
- [ ] 2.2 **Milestone M2**: WebSocket `login_nios_id` Action, NiosMess Session Models, Storage & Riverpod AuthNotifier/State.
- [ ] 2.3 **Milestone M3**: Material 3 Expressive Unified Auth Hub UI (`/login` & `/register` consolidation), Ecosystem Card, Responsive Pill Action, Legal Reader.
- [ ] 2.4 **Milestone M4**: GoRouter Shell Integration, Cold-Start Nios ID Session Check (`/id/api/v1/account`), Clean Logout Flow (`/id/api/v1/logout`), Consent Rejection UX.
- [ ] 2.5 **E2E Testing Track**: Comprehensive test harness, Tiers 1-4 test suites, `TEST_READY.md`.

## Phase 3: Final Integration, E2E Verification & Adversarial Hardening
- [ ] 3.1 Run 100% E2E test suite (Tiers 1-4).
- [ ] 3.2 Tier 5 Adversarial Coverage Hardening (Challenger -> Worker -> Reviewer).
- [ ] 3.3 Static Analysis check (`flutter analyze` -> 0 errors, 0 warnings).
- [ ] 3.4 Automated SemVer Bump in `pulse_flutter/pubspec.yaml`.

## Phase 4: Final Victory Reporting
- [ ] 4.1 Compile full audit, test reports, and changes.
- [ ] 4.2 Send victory report to parent (Sentinel) via `send_message`.
