# Handoff Report: Auth & Routing Architecture Survey

**Agent:** Auth & Routing Explorer  
**Working Directory:** `f:\Niosmess V2\.agents\explorer_auth_survey_1`  
**Timestamp:** 2026-09-01T11:37:00Z  
**Type:** Hard (Task Complete)

---

## 1. Observation

1. **Auth Notifier & Current Session Persistence (`lib/providers/auth_provider.dart:83-141`)**:
   - `AuthNotifier` uses `FlutterSecureStorage` with key `'auth.session'` to store serialized `AuthSession` JSON.
   - Currently implements legacy actions: `login(...)` (lines 142-197), `register(...)` (lines 248-275), `verifyEmail(...)` (lines 277-332), `verifyTwoFa(...)` (lines 199-246).
   - In `_load()` (lines 104-129), `auth.session` is read and immediately assumed valid without verifying against central Nios ID account endpoint `GET /id/api/v1/account`.

2. **WebSocket Client & Requests (`lib/core/network/web_socket_client.dart:48-103, 301-367` & `lib/repositories/auth_repository.dart:49-63`)**:
   - `WebSocketClient` connects to `wss://ni-os.ru/ws` and performs an unencrypted `key_exchange` to derive an AES-256-GCM session key (`_secretKey`).
   - `AuthRepository.login()` currently dispatches the WebSocket action `'login'` with `{ 'identifier': identifier, 'password': password }`.
   - The new specification `NIOSMESS_FRONTEND_LOGIN.md:209-231` requires WebSocket action `'login_nios_id'` with payload `{ "oauth_access_token": oauthAccessToken, "device_info": deviceInfo }`.

3. **GoRouter Routing & Redirects (`lib/router/app_router.dart:56-119`)**:
   - Public paths in redirect guard (line 76): `'/'`, `'/login'`, `'/register'`, `'/onboarding'`, `'/reset-password/*'`, `'/verify-email'`, `'/2fa'`, `'/setup'`, `'/legal/*'`.
   - Direct routes exist for separate login (`LoginScreen`, lines 92-94) and registration (`RegisterScreen`, lines 96-98).
   - `DeepLinkService` (`lib/core/services/deep_link_service.dart:9-51`) listens to `app_links` on non-web platforms and parses deep links to app routes.

4. **UI Forms & Password Fields (`lib/screens/login_screen.dart:153-195` & `lib/screens/register_screen.dart:163-240`)**:
   - `LoginScreen` contains text fields for username (`Key('login_identifier_field')`) and password (`Key('login_password_field')`).
   - `RegisterScreen` contains separate text inputs for display name, username, email, and password.
   - `NIOSMESS_FRONTEND_LOGIN.md:12-14` strictly mandates: *"Фронтенд NiosMess не должен иметь полей пароля, собственного логина или прямого доступа к cookie nios_session."*

5. **Static Analysis & Test Baseline (`flutter analyze`, `flutter test`)**:
   - `flutter analyze` completed with 0 errors and 0 warnings.
   - `flutter test` baseline shows existing widget tests (`test/screens/login_screen_test.dart` and `test/screens/register_screen_test.dart`) were asserting previous UI form widgets and need replacement with unified Nios ID OAuth PKCE widget tests.

---

## 2. Logic Chain

1. **From Observation 1 & 4 to Auth Hub Redesign**:
   - Because `NIOSMESS_FRONTEND_LOGIN.md` and `ORIGINAL_REQUEST.md` (R1 & Acceptance Criteria) require zero password or username inputs in the NiosMess client, all credential fields in `LoginScreen` and the standalone `RegisterScreen` must be decommissioned.
   - They must be replaced by a single responsive Material 3 Expressive Auth Hub at `/login` centered around «Войти через Nios ID» with maxWidth 480dp, hero header, 3 ecosystem pillars, and secondary link to Nios ID account registration.

2. **From Observation 2 to WebSocket Protocol Update**:
   - The legacy `login` action transmitting plaintext passwords over WebSocket must be replaced with `login_nios_id`.
   - The token flow is: (1) PKCE S256 verifier/state generation -> (2) `/oauth/authorize` redirect -> (3) Callback interception -> (4) `POST /oauth/token` exchange -> (5) WS `login_nios_id` -> (6) Local `AuthSession` creation + E2EE initialization.
   - The temporary `oauth_access_token` must be discarded immediately after WS authentication and never persisted to long-term storage.

3. **From Observation 1 & 3 to Cold Start & Lifecycle Safety**:
   - When the app starts with a stored session, `_load()` must query `GET /id/api/v1/account`.
   - If HTTP 401 is received, the session on Nios ID has been revoked/terminated on another device; the client must purge `auth.session` and redirect to `/login`.
   - When the user logs out, the client must unregister FCM tokens (`unregister_fcm_token`), send WS `logout`, POST `/id/api/v1/logout` to terminate the central Nios ID session, clear storage, and redirect to `/id/login?next=/web`.

4. **From Observation 3 to Route Consolidation**:
   - Routes `/register`, `/verify-email`, `/2fa`, and `/reset-password/*` are no longer separate flows within NiosMess because registration, email verification, 2FA, and password management are handled by the central Nios ID service.
   - In `app_router.dart`, these routes can redirect to `/login` or display the unified auth hub.

---

## 3. Caveats

1. **Browser Address Bar Sanitization on Web**:
   - When returning to `/web?code=...&state=...`, `window.history.replaceState` or GoRouter redirect is needed to strip query parameters so that the authorization code does not leak into browser history or bookmarks.
2. **Ephemeral Storage on Web vs. Native**:
   - On Web, `window.sessionStorage` is the standard ephemeral mechanism that survives page reloads during the OAuth redirect but is isolated from permanent storage.
   - On Mobile/Desktop, state and verifier can be held in an in-memory repository/service or ephemeral secure storage cleared on callback reception.
3. **No Periodic Polling**:
   - Per project constraints, background timer polling is avoided; session checks occur strictly on cold start / refresh and upon 401 unauthorized signals.

---

## 4. Conclusion

The pulse_flutter codebase is fully structured and prepared for the Nios ID OAuth 2.0 PKCE transition. The required changes are well-scoped across 6 key areas:
1. **PKCE Crypto & OAuth Token Exchange**: Implement `PkceHelper` (S256 verifier/challenge/state) and HTTP client for `POST /oauth/token`.
2. **Auth Notifier & Repository**: Add `loginNiosId` (WS `login_nios_id`), `checkCentralNiosIdSession` (`GET /id/api/v1/account`), `logoutCentralNiosId` (`POST /id/api/v1/logout`), and remove legacy username/password mutations.
3. **Unified M3 Expressive Auth Screen**: Rewrite `lib/screens/login_screen.dart` to a passwordless hub with 56dp/28dp pill button, 3 ecosystem benefit pillars, responsive layout (maxWidth 480dp), and exchange loading overlay.
4. **Router & Deep Link Guard**: Consolidate routes and sanitize callback URL query parameters.
5. **Cold Start & Logout**: Enforce central session verification on cold start (purge on 401) and full logout cleanup.
6. **Automated Testing**: Rewrite test suites in `test/screens/login_screen_test.dart` to validate PKCE generation, M3 Expressive Hub rendering, callback handling, and error states.

Detailed technical designs and file modifications are documented in `f:\Niosmess V2\.agents\explorer_auth_survey_1\auth_architecture_report.md`.

---

## 5. Verification Method

To independently verify the investigation findings:
1. **Inspect Architecture Report**:
   - View `f:\Niosmess V2\.agents\explorer_auth_survey_1\auth_architecture_report.md`.
2. **Verify Static Analysis Baseline**:
   - Run `flutter analyze` inside `f:\Niosmess V2\pulse_flutter` -> Confirmed 0 errors, 0 warnings.
3. **Verify Auth & WebSocket Code Locations**:
   - `lib/providers/auth_provider.dart` (lines 83-197)
   - `lib/repositories/auth_repository.dart` (lines 49-63)
   - `lib/core/network/web_socket_client.dart` (lines 48-103, 301-367)
   - `lib/router/app_router.dart` (lines 56-119)
   - `lib/screens/login_screen.dart` (lines 153-255)
