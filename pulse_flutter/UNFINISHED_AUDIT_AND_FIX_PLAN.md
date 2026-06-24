# NiosMess Unfinished Audit And Fix Plan

Last updated: 2026-04-17 (post-cleanup pass)

Scope: `F:\Niosmess V2\pulse_flutter`
Primary source of truth: `F:\Niosmess V2\API_DOCS.md`

## Goal

Ship a production-usable NiosMess client with:

- no mock/demo/runtime placeholder data in user-facing flows
- no no-op actions disguised as working features
- no UI that promises backend/platform functionality that does not exist
- complete alignment with the documented API where endpoints exist
- honest product behavior where backend support does not exist yet

## Progress Since Last Audit

### Completed fixes

- **Phase 4 — Calls honestly scoped**: Removed fake mute/speaker/dialpad from `active_call_screen.dart`. Added honest "Signaling-only" label. Removed fake quality rating from `call_history_detail_screen.dart`.
- **Phase 5 — Messaging correctness**: Channel composer disabled for non-admin/owner members. Delete permission now role-based (own messages OR admin/owner). Forward relabeled as "Resend" (no API forward endpoint). Search message results deep-link to exact message. Chat member invite uses searchable user picker instead of raw user ID.
- **Phase 6 — Cleanup**: Removed orphaned settings screens (blocked-contacts, data-storage, language, notifications, privacy-permissions) from router and deleted source files. Updated TASKS.md.

### Still outstanding

1. **WebRTC audio/video** — Calls are signaling-only. Real media requires WebRTC + TURN/STUN. Currently honest about scope.
2. **Voice/circle media pipeline** — No in-app recorder or circle capture for `voice`/`circle` media subtypes.
3. **Message forwarding** — No native API forward endpoint. "Resend" copies text with attribution. True forwarding requires backend support.
4. **Search deep-link precision** — Scrolls to estimated position, not exact message widget.
5. **Share/invite polish** — Basic copy/share flows exist but lack polished UX.
6. **Loading/empty/error/skeleton states** — Not standardized across screens.
7. **Localization** — No localization pipeline; all strings are hardcoded English.

## Original Findings (archived)

- Searched codebase for placeholder markers and no-op language.
- Cross-checked implemented UI against `API_DOCS.md`.
- Compared current state against `TASKS.md` and `API_DOCS_FULL_IMPLEMENTATION_PLAN.md`.
- Reviewed recently added Stitch-based screens for hardcoded/demo content.

## Executive Summary

The app is not yet free of unfinished work.

Main risk areas:

1. Web/media/file flows are not production-ready.
2. Calls are signaling/status UI, not a real call feature.
3. Several new settings/detail screens are visual mockups with local state or hardcoded data.
4. Chat detail/manage models do not yet represent important server fields.
5. Some completed items in `TASKS.md` are only partially complete in practice.

## Findings

### Critical

1. Web/platform media support is still incomplete.
   Files:
   - `lib/core/network/api_client.dart`
   - `lib/repositories/chat_repository.dart`
   - `lib/widgets/m3_file_picker_bottom_sheet.dart`
   - `lib/widgets/m3_file_preview_bottom_sheet.dart`
   - `lib/core/utils/file_opener.dart`
   Why unfinished:
   - multiple flows still depend on `dart:io`, local file paths, or `Platform.*`
   - remote media URLs from backend are not handled as first-class web-safe inputs

2. Calls are not a full product feature yet.
   Files:
   - `lib/screens/active_call_screen.dart`
   - `lib/screens/calls_screen.dart`
   - `lib/screens/call_history_detail_screen.dart`
   Why unfinished:
   - mute/speaker are local UI toggles only
   - dialpad is a no-op
   - no real audio/video stream handling
   - call detail is reconstructed from route params, not real call history data

3. Remote attachment preview/open is not really wired.
   Files:
   - `lib/screens/chat_detail_screen.dart`
   - `lib/widgets/m3_file_preview_bottom_sheet.dart`
   Why unfinished:
   - preview/open/install flow expects local `filePath`
   - chat media coming from API URLs do not get a full working preview/open flow
   - share action is explicitly unfinished

4. Chat detail/manage does not model important documented server fields.
   Files:
   - `lib/models/api/chat_summary_model.dart`
   - `lib/repositories/chat_repository.dart`
   - `lib/screens/chat_manage_screen.dart`
   API drift:
   - `description`
   - `comments_enabled`
   - `comments_chat_id`
   - `invite_link`
   - `share_link`
   - partner metadata for direct chats
   Why unfinished:
   - manage UI cannot preload or reliably edit true server state

### High

5. Several Stitch-based settings screens are pure mock/local-only UI and must not ship as-is.
   Files:
   - `lib/screens/settings_data_storage_screen.dart`
   - `lib/screens/settings_blocked_contacts_screen.dart`
   - `lib/screens/settings_language_screen.dart`
   - `lib/screens/settings_notifications_screen.dart`
   - `lib/screens/settings_security_screen.dart`
   - `lib/screens/settings_privacy_permissions_screen.dart`
   - `lib/screens/settings_about_screen.dart`
   Why unfinished:
   - hardcoded metrics, demo contacts, fake version/build values, local-only toggles, placeholder SnackBars

6. Help/about/legal/support actions are not fully wired.
   Files:
   - `lib/screens/settings_help_screen.dart`
   - `lib/screens/settings_about_screen.dart`
   Why unfinished:
   - legal links are no-op
   - support/report flows are SnackBar-only

7. Contact detail is only partially real.
   Files:
   - `lib/screens/contact_detail_screen.dart`
   Why unfinished:
   - profile fetch is real, but the second half of the page is placeholder text for missing shared data

8. Search message results do not open the actual found message.
   Files:
   - `lib/models/api/search_models.dart`
   - `lib/screens/contacts_screen.dart`
   Why unfinished:
   - tapping a found message only opens the chat, without deep-link/highlight/jump-to-message behavior

9. Media viewer architecture is inconsistent.
   Files:
   - `lib/router/app_router.dart`
   - `lib/screens/media_viewer_screen.dart`
   - `lib/widgets/m3_file_preview_bottom_sheet.dart`
   Why unfinished:
   - dedicated viewer route exists, but actual attachment flow uses a different preview path

10. Some features in UI imply device/platform integration that is not implemented.
   Files:
   - `lib/screens/settings_language_screen.dart`
   - `lib/screens/settings_notifications_screen.dart`
   - `lib/screens/settings_privacy_permissions_screen.dart`
   - `lib/screens/settings_security_screen.dart`
   Why unfinished:
   - there is no localization pipeline
   - no native push notification settings integration
   - no OS permission management integration
   - no biometric/app-lock implementation

### Medium

11. Message forwarding is still synthetic text injection.
   File:
   - `lib/screens/chat_detail_screen.dart`
   Why unfinished:
   - forward action creates `_fwd from ...` text instead of a real forwarded-message model/flow

12. Channel-specific restrictions are not fully enforced in composer/actions.
   Files:
   - `lib/screens/chat_detail_screen.dart`
   - `lib/models/api/chat_summary_model.dart`
   Why unfinished:
   - channel member posting restrictions are not represented in UI
   - comments action is shown without a true `comments_enabled` field in model

13. Message delete action visibility likely exceeds actual permissions.
   File:
   - `lib/screens/chat_detail_screen.dart`
   Why unfinished:
   - current delete option logic is broader than documented role-based behavior

14. Chat member invite flow is rough and admin-only UX is not product-level.
   File:
   - `lib/screens/chat_members_screen.dart`
   Why unfinished:
   - invite flow asks for raw numeric user ID instead of searchable user picker / username flow

15. Media feature coverage is not at API parity.
   Files:
   - `lib/widgets/m3_file_picker_bottom_sheet.dart`
   - `lib/repositories/chat_repository.dart`
   Why unfinished:
   - API supports `media`, `voice`, `circle`
   - UI does not provide a real recorder / circle capture pipeline

16. Some share/invite flows are still basic and not product-finished.
   Files:
   - `lib/screens/join_chat_screen.dart`
   - `lib/screens/create_chat_screen.dart`
   Why unfinished:
   - no polished copy/share flow for invite/share links
   - success UX is still mostly snackbar-driven

### Low

17. Build metadata is hardcoded.
   File:
   - `lib/screens/settings_about_screen.dart`
   Why unfinished:
   - should come from package/app metadata, not static text

18. Existing task docs drift from real implementation state.
   Files:
   - `F:\Niosmess V2\TASKS.md`
   - `F:\Niosmess V2\API_DOCS_FULL_IMPLEMENTATION_PLAN.md`
   Drift examples:
   - calls marked as mock-removed, but still not product-real
   - in-app attachment opening marked done, but remote preview/open is incomplete
   - smoke route/API check still not complete

## Areas With Hardcoded Or Demo Data

These must be either wired to real data or removed from shipping UI.

1. `settings_data_storage_screen.dart`
   - storage usage
   - network usage
   - clear-cache result text

2. `settings_blocked_contacts_screen.dart`
   - entire blocked contacts list

3. `settings_language_screen.dart`
   - language list is static
   - apply action does not actually switch locale

4. `settings_notifications_screen.dart`
   - all state is local-only

5. `settings_security_screen.dart`
   - biometric/timeout/alert state is local-only

6. `settings_privacy_permissions_screen.dart`
   - privacy values and permissions are local-only

7. `settings_about_screen.dart`
   - version/build values are static

8. `call_history_detail_screen.dart`
   - detail content is route-driven synthetic UI, not backend-driven history

9. `contact_detail_screen.dart`
   - shared context block is placeholder-only

## Existing No-Op Or Placeholder Actions

1. `settings_about_screen.dart`
   - legal links -> `not wired yet`

2. `settings_help_screen.dart`
   - support/report issue -> snackbar-only

3. `settings_data_storage_screen.dart`
   - clear cache -> snackbar-only

4. `settings_blocked_contacts_screen.dart`
   - restore access -> snackbar-only

5. `settings_language_screen.dart`
   - apply language -> snackbar-only

6. `m3_file_preview_bottom_sheet.dart`
   - share -> `coming soon`

7. `active_call_screen.dart`
   - dialpad -> no-op

## Cross-Check Against API_DOCS

Must be closed before claiming no unfinished work remains.

1. Finish full chat detail model from `GET /chats/{chat_id}`.
2. Enforce channel permissions based on true server state.
3. Finish media subtype parity for `voice` and `circle`.
4. Replace synthetic call detail with real backend-driven call data when available.
5. Review whether privacy/notifications/language/security settings have real backend endpoints.
   - If yes: wire them to backend.
   - If no: make them real local platform features or remove/hide them until supported.

## Recommended Execution Order

### Phase 0 - Guardrails

1. Do not add any more purely visual screens without data/platform backing.
2. Any feature with no real implementation must either:
   - be wired properly, or
   - be removed from navigation, or
   - be clearly labeled as unavailable and hidden from primary UX.

### Phase 1 - Core Truth Layer

1. Expand DTOs and repositories to fully match API docs.
2. Split richer profile/chat/message/call/upload domains if current repository boundaries are too weak.
3. Add honest feature capability checks for unsupported server/platform features.

### Phase 2 - Remove Mock And Placeholder Screens

1. Replace local/demo settings data with real backend or platform integrations.
2. Remove static blocked contacts if there is no endpoint.
3. Replace hardcoded version/build with package metadata.
4. Remove snackbar-only fake actions from about/help/data-storage/language screens.

### Phase 3 - Fix Media And Web

1. Remove `dart:io` assumptions from shared web codepaths.
2. Make file picker/upload web-safe.
3. Make remote attachment preview/open/download work for API URLs.
4. Unify attachment viewer architecture.

### Phase 4 - Calls To Production Reality

1. Decide product truth:
   - real RTC now, or
   - honest signaling-only status UI with reduced promise surface.
2. Remove fake mute/speaker/dialpad behaviors unless connected to real media stack.
3. Replace synthetic call details with real data source.

### Phase 5 - Messaging And Chat Correctness

1. Real forwarded-message flow or remove forward affordance.
2. Deep-link search message results into exact message context.
3. Enforce channel/member action permissions correctly.
4. Replace raw user-id invite admin UX with searchable user flow.

### Phase 6 - Final Polish And Readiness

1. Standardize loading/empty/error/skeleton states.
2. Run smoke pass on all routes.
3. Add regression tests for critical API flows.
4. Update `TASKS.md` to match actual implementation state.

## Definition Of Done For This Cleanup Project

The cleanup is complete only when all of the following are true:

1. No runtime demo/mock data remains in shipping user flows.
2. No visible primary action ends in a placeholder snackbar.
3. No screen claims unsupported backend/platform behavior.
4. Web build works for media/file flows without `dart:io` breakage.
5. Calls are either truly functional or honestly scoped in UI.
6. All implemented flows align with `API_DOCS.md`.
7. `flutter analyze`, `flutter test`, and web smoke-check pass.

## Immediate Next Wave

Recommended first implementation wave after this audit:

1. Fix media/web/file pipeline.
2. Expand chat detail DTO/repository/manage screen to real server state.
3. Remove local-only settings mock screens from primary UX or wire them properly.
4. Replace synthetic call/detail placeholders.
5. Reconcile `TASKS.md` with reality and track progress against this file.
