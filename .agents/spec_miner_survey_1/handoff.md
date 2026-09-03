# Handoff Report — OAuth & Nios ID Specification Survey

**Agent**: OAuth Spec Miner (`spec_miner_survey_1`)  
**Recipient**: Project Orchestrator (`65ff2a5d-b51f-4b8f-9b41-07119b4e87c7`)  
**Date**: 2026-09-01T16:35:00+05:00  
**Handoff Type**: Hard (Task Complete)

---

## 1. Observation

Authoritative specification sources inspected:
1. `f:\Niosmess V2\NIOSMESS_FRONTEND_LOGIN.md` (Lines 1–330):
   - Registered public client: `client_id: niosmess_web`, `redirect_uri: https://ni-os.ru/web`, `scopes: openid profile email`.
   - PKCE S256 verifier: 64 random bytes, base64url unpadded; challenge: SHA-256 digest, base64url unpadded; state and nonce: 24 random bytes each.
   - Pre-auth session check: `GET /id/api/v1/account` (credentials: same-origin). Only 401 indicates absent session; network errors do not abort.
   - Callback processing: URL sanitized immediately (`history.replaceState`), state checked against ephemeral storage, `POST /oauth/token` (grant_type: `authorization_code`).
   - WebSocket login action: `login_nios_id` on `wss://ni-os.ru/ws` with payload `{ oauth_access_token, device_info }` returning `{ access_token, user_id, nios_id, username, display_name }`.
   - Temporary `oauth_access_token` must never be stored persistently.
   - Logout: `POST /id/api/v1/logout` followed by WebSocket disconnect, local storage wipe, and redirect to `/id/login?next=/web`.
2. `f:\Niosmess V2\.agents\ORIGINAL_REQUEST.md` (Lines 1–75):
   - R1: Eliminate local password/username inputs; consolidate auth into single Material 3 Expressive screen centered around «Войти через Nios ID» (maxWidth 480dp).
   - R2: Visual hierarchy: Hero Header, Ecosystem Benefits Card (3 pillars: Unified Account, E2EE, Zero Password), Primary 56dp pill button (28dp radius), Legal Footer (`/legal/privacy`, `/legal/terms`).
   - R3–R6: PKCE exchange flow, WebSocket action, loading states & consent rejection toast (`AppToast.showError`), cold-start verification (`GET /id/api/v1/account`), clean logout without polling timers.
3. `f:\Niosmess V2\AGENTS.md`:
   - Riverpod 3.x NotifierProvider pattern, `package:universal_io/io.dart`, Material 3 semantic color tokens (no `Colors.white`/`black` or `withOpacity()`), explicit `WidgetStatePropertyAll<Color>`, and automated SemVer bumping.
4. Existing codebase files inspected:
   - `pulse_flutter/lib/models/api/auth_models.dart`: `AuthSession`, `AuthLoginResult`.
   - `pulse_flutter/lib/repositories/auth_repository.dart`: currently has legacy `login`, `register`, `verifyEmail`, etc.
   - `pulse_flutter/lib/providers/auth_provider.dart`: `AuthNotifier`, `FlutterSecureStorage` under key `auth.session`.
   - `pulse_flutter/lib/screens/login_screen.dart`: currently contains username/password text fields.
   - `pulse_flutter/lib/screens/legal_viewer_screen.dart` & `app_router.dart`: fully functioning legal reader for `/legal/privacy`, `/legal/terms`, `/legal/tos`, `/legal/consent`.

---

## 2. Logic Chain

1. **Elimination of Password Surface Area**:
   Because `NIOSMESS_FRONTEND_LOGIN.md` explicitly mandates that password entry occurs solely on `ni-os.ru/id` and the client must have no username/password fields, `LoginScreen` and `RegisterScreen` must be unified into a single authentication screen featuring the «Войти через Nios ID» action.
2. **PKCE & Ephemeral State Security**:
   The authorization request requires `code_verifier` (64 random bytes base64url) and `code_challenge` (SHA-256 base64url). To prevent token interception and meet specification constraints, `verifier` and `state` must reside solely in `sessionStorage` (or memory on native) and be cleared immediately upon callback validation.
3. **Address Bar Sanitization**:
   Before initiating token exchange, the browser address bar must be cleaned to remove `code` and `state` query parameters, preventing accidental leakage via browser history or HTTP referrer headers.
4. **Single-Use In-Memory OAuth Token**:
   `POST /oauth/token` yields a short-lived `access_token`. This token is passed strictly in-memory into WebSocket `login_nios_id` to establish the authenticated messaging session. The resulting local NiosMess token and user metadata are saved to `FlutterSecureStorage`, while the OAuth token is immediately dropped.
5. **Cold-Start Session Integrity & Clean Logout**:
   On app initialization, if a stored session exists, `GET /id/api/v1/account` verifies that the central Nios ID session has not been revoked elsewhere. An HTTP 401 triggers an immediate local logout and toast notification. On manual logout, `POST /id/api/v1/logout` terminates the central session, followed by wiping local session/cache and redirecting to login.

---

## 3. Caveats

- **Web vs Native Platforms**: On Web, authorization is performed via direct browser redirects (`window.location.assign`) and `sessionStorage`. On mobile/desktop platforms, browser launch via system custom tabs or deep links (`app_links`) is used for the OAuth callback.
- **Network Resilience on Cold Start**: Only an explicit HTTP status 401 indicates session revocation. Network timeouts or connectivity interruptions must NOT log the user out, preserving offline capabilities.
- **No Background Polling**: Central session checks occur on cold start / resume and logout, without continuous background interval polling timers (per user specifications).

---

## 4. Conclusion

All exact technical specifications, protocol definitions, storage constraints, cryptographic algorithms, edge cases, error behaviors, and UI contracts have been mined, verified against the authoritative sources, and compiled into:
`f:\Niosmess V2\.agents\spec_miner_survey_1\spec_report.md`

The specification is complete, unambiguous, and ready to guide implementation and test engineering.

---

## 5. Verification Method

To verify these findings against the source documents and codebase:
1. Inspect `f:\Niosmess V2\.agents\spec_miner_survey_1\spec_report.md` for full requirements coverage.
2. Inspect `f:\Niosmess V2\NIOSMESS_FRONTEND_LOGIN.md` lines 1–330 to verify PKCE parameters, HTTP endpoints, WebSocket payload, and storage rules.
3. Inspect `f:\Niosmess V2\.agents\ORIGINAL_REQUEST.md` to verify all requirements R1–R6 and acceptance criteria.
4. Check existing Flutter architecture in `f:\Niosmess V2\pulse_flutter\lib\`.
