# OAuth 2.0 PKCE & Nios ID Authentication Specification Report

**Date**: 2026-09-01  
**Author**: OAuth Spec Miner  
**Target Project**: NiosMess (`pulse_flutter`)  
**Authoritative Sources**: 
- `NIOSMESS_FRONTEND_LOGIN.md` (Primary Frontend Integration Spec)
- `.agents/ORIGINAL_REQUEST.md` (User & Project Requirements)
- `AGENTS.md` (Architecture & Coding Guidelines)
- `pulse_flutter/` (Existing Codebase Reference)

---

## 1. Executive Summary

NiosMess is migrating from legacy local credential authentication (login/register with identifier and password) to a unified **OAuth 2.0 Authorization Code Flow with PKCE (S256)** powered by **Nios ID**.

Key Architectural Tenets:
1. **Zero Credential Exposure**: No username, email, or password fields exist inside NiosMess. Passwords and credentials reside strictly on the central Nios ID identity server (`https://ni-os.ru/id`).
2. **Strict Ephemeral State**: PKCE `verifier` and OAuth `state` are stored strictly in ephemeral storage (`sessionStorage` on Web, memory on native) and destroyed immediately upon callback receipt.
3. **No Persistent OAuth Tokens**: The short-lived `oauth_access_token` returned by `POST /oauth/token` is exchanged once via WebSocket (`login_nios_id`) for a local NiosMess session token, then discarded immediately from memory. It is **never** written to persistent storage (`localStorage`, `SharedPreferences`, `FlutterSecureStorage`, or Hive).
4. **Identity Binding**: User identity is bound solely to `nios_id` (`sub`), never to email.
5. **Session Verification on Cold Start**: Application startup verifies the central Nios ID session via `GET /id/api/v1/account`. An HTTP 401 immediately purges local session state and redirects to login, while network errors preserve offline availability.

---

## 2. Features Discovered

| # | Category | Feature | Description | Inputs | Outputs | Error Behavior | Discovered Via |
|---|----------|---------|-------------|--------|---------|----------------|----------------|
| 1 | OAuth / PKCE | PKCE Verifier Generation | Generate 64-byte cryptographically secure random bytes encoded as unpadded Base64URL (512-bit entropy). | Cryptographic RNG (64 random bytes) | Base64URL string (approx 86 chars, no `+`, `/`, `=`) | Throws if CSPRNG is unavailable. | `NIOSMESS_FRONTEND_LOGIN.md` §1 |
| 2 | OAuth / PKCE | PKCE Challenge (S256) | Computes SHA-256 digest of verifier and Base64URL encodes without padding. | `code_verifier` string | `code_challenge` string | Throws on invalid crypto digest. | `NIOSMESS_FRONTEND_LOGIN.md` §1 |
| 3 | OAuth / PKCE | State & Nonce Generation | Generates 24-byte cryptographically secure random Base64URL strings for CSRF and replay protection. | Cryptographic RNG (24 random bytes each) | `state` (32 chars), `nonce` (32 chars) | Throws if CSPRNG is unavailable. | `NIOSMESS_FRONTEND_LOGIN.md` §1, §3 |
| 4 | OAuth / PKCE | Pre-auth Central Session Probe | Calls `GET /id/api/v1/account` before initiating OAuth. If 401, directs to `/id/login?next=/web?nios_oauth=start`. | HTTP GET credentials: `same-origin` | `true` if active session (status != 401), `false` if 401 | Network exceptions return `true` (do not abort flow). | `NIOSMESS_FRONTEND_LOGIN.md` §3 |
| 5 | OAuth / PKCE | Authorization Redirect | Constructs `/oauth/authorize` URI with PKCE params and redirects browser / custom tab. | `client_id=niosmess_web`, `redirect_uri=https://ni-os.ru/web`, `scope=openid profile email`, `state`, `nonce`, `code_challenge`, `code_challenge_method=S256` | Browser redirect to Nios ID consent screen | Missing/mismatched redirect URI causes OAuth error on server. | `NIOSMESS_FRONTEND_LOGIN.md` §3 |
| 6 | OAuth / PKCE | Address Bar Sanitization | Strips `code`, `state`, and `error` parameters from address bar via `history.replaceState` or GoRouter redirect upon callback. | Current URL with query params | Clean URL (e.g. `/web` or `/login`) | Prevents token/code leakage via referrer headers or browser history. | `NIOSMESS_FRONTEND_LOGIN.md` §4 |
| 7 | OAuth / PKCE | State Validation | Compares callback `state` against ephemeral stored `state`. Purges stored verifier/state. | `params.get("state")` vs `sessionStorage.getItem("nios_oauth_state")` | Boolean validity | If mismatch, aborts flow, shows error toast, stays on auth screen. | `NIOSMESS_FRONTEND_LOGIN.md` §4 |
| 8 | HTTP API | Token Exchange (`POST /oauth/token`) | Exchanges authorization code + PKCE verifier for short-lived OAuth access token. | `POST /oauth/token` with `grant_type=authorization_code`, `code`, `client_id`, `redirect_uri`, `code_verifier` (x-www-form-urlencoded) | JSON `{ "access_token": "...", "token_type": "Bearer", ... }` | Returns HTTP 400 `invalid_grant` if code is expired/reused; raises exception and shows toast. | `NIOSMESS_FRONTEND_LOGIN.md` §4 |
| 9 | WebSocket | Action `login_nios_id` | Sends temporary `oauth_access_token` and `device_info` over encrypted WebSocket to obtain local NiosMess session. | WebSocket connected to `wss://ni-os.ru/ws`, payload: `{ "oauth_access_token": "...", "device_info": "..." }` | JSON payload: `{ "access_token": "...", "user_id": 123, "nios_id": "...", "username": "...", "display_name": "..." }` | Throws error if token rejected or expired; prompts user to re-login. | `NIOSMESS_FRONTEND_LOGIN.md` §5 |
| 10 | Security / Storage | Ephemeral Storage Constraint | Stores PKCE verifier and state strictly in ephemeral storage (`sessionStorage`), never in persistent storage. | Verifier, State strings | Ephemeral session storage keys | Deleted immediately upon callback processing. | `NIOSMESS_FRONTEND_LOGIN.md` §1, §4 |
| 11 | Security / Storage | OAuth Token Discard Constraint | `oauth_access_token` is used in-memory for `login_nios_id` and immediately dropped. Never written to persistent storage. | `oauth_access_token` | In-memory exchange only | Never saved to `FlutterSecureStorage` or `localStorage`. | `NIOSMESS_FRONTEND_LOGIN.md` §5 |
| 12 | Security / Storage | Persistent Session Storage | Stores local NiosMess session token, `user_id`, `username`, `display_name`, and `nios_id` in secure storage. | `AuthSession` data | Persistent secure storage | Encrypted by `FlutterSecureStorage`. | `pulse_flutter` auth models & `NIOSMESS_FRONTEND_LOGIN.md` §5 |
| 13 | Lifecycle | E2EE Key Initialization | Automatically derives or generates X25519/Ed25519 keypair and uploads public key via `set_public_key` action post-login. | Local key store & WebSocket connection | Initialized E2EE session & uploaded public key | Fallback gracefully if key already present. | `NIOSMESS_FRONTEND_LOGIN.md` §5, `pulse_flutter/lib/services/e2ee_service.dart` |
| 14 | Lifecycle | Cold Start Session Verification | On app launch, probes `GET /id/api/v1/account`. If 401, clears local session and displays re-auth prompt. | App init / refresh | Resumed session or clean logout + auth screen | 401 purges session; network errors preserve session. | `NIOSMESS_FRONTEND_LOGIN.md` §6 |
| 15 | Lifecycle | Clean Logout Flow | Calls `POST /id/api/v1/logout`, unregisters FCM tokens, closes WebSocket, clears local storage, redirects to `/id/login?next=/web`. | User tap on «Выйти» | Terminated central and local sessions | Handled in `finally` block to ensure local cleanup even if network fails. | `NIOSMESS_FRONTEND_LOGIN.md` §7 |
| 16 | Central API | Session Management API | Query and revoke remote active sessions via central endpoints. | `GET /id/api/v1/sessions`, `DELETE /id/api/v1/sessions/{id}`, `POST /id/api/v1/sessions/revoke-others` | Sessions list, confirmation | Handled via HTTP or bridged WebSocket. | `NIOSMESS_FRONTEND_LOGIN.md` §7 |
| 17 | UI / Expressive | Unified Auth Screen | Replaces password/register screens with a single Material 3 Expressive hub centered on «Войти через Nios ID». | Responsive layout (max 480dp width) | Hero branding, Benefits Card, Pill Button (56dp/28dp radius), Legal Footer | Responsive for mobile, tablet, and desktop. | `ORIGINAL_REQUEST.md` R1, R2 |
| 18 | UI / Expressive | Ecosystem Benefits Card | Displays 3 key pillars in `surfaceContainerLow` container: Unified Account, E2EE Encryption, Zero Password Transmission. | Material 3 ColorScheme & typography | Visual card with icons (`badge_outlined`, `lock_outline_rounded`, `shield_outlined`) | Adapts to light/dark tonal palettes. | `ORIGINAL_REQUEST.md` R2 |
| 19 | UI / Expressive | Inline Loading & Overlay State | Disables button and displays inline progress indicator during authorization / callback processing. | Async operation state | Visual spinner / status banner | Recovers to interactive state on error or cancellation. | `ORIGINAL_REQUEST.md` R5 |
| 20 | Legal | Material 3 Legal Reader | In-app viewer for Privacy Policy (`/legal/privacy`), Terms of Service (`/legal/terms`, `/legal/tos`), and Consent. | Route path / docType | Rich markdown/text reader with search, section jump chips, reading time badge | Fallback error screen if document asset missing. | `pulse_flutter/lib/screens/legal_viewer_screen.dart`, `ORIGINAL_REQUEST.md` R2 |

---

## 3. Edge Cases & Observed Behaviors

| # | Feature | Input / Condition | Observed / Required Behavior |
|---|---------|-------------------|-----------------------------|
| 1 | OAuth Callback | User clicks «Отмена» (consent denied) on Nios ID consent screen | Nios ID redirects to `/web?error=access_denied&error_description=...`. Client captures `error`, strips URL params, cleans sessionStorage, remains on Auth Screen, re-enables login button, and displays error toast via `AppToast.showError(...)`. No unhandled exceptions. |
| 2 | OAuth Callback | Attacker tampers with `state` in URL callback | `params.get("state") !== expectedState`. Client immediately aborts token exchange, cleans sessionStorage, displays toast «Не удалось проверить ответ Nios ID.», and leaves user on Auth Screen. |
| 3 | OAuth Callback | Missing `code_verifier` in ephemeral storage (e.g. user opened callback in new incognito tab) | Client detects missing verifier, cleans storage, displays error toast «Не удалось проверить ответ Nios ID.», stays on Auth Screen. |
| 4 | Token Exchange | Reused or expired authorization code | `POST /oauth/token` returns HTTP 400 with body `{"error": "invalid_grant"}`. Client catches error, shows `error_description` via `AppToast.showError(...)`, and remains in ready state on Auth Screen. |
| 5 | Token Exchange | Network failure / offline during `POST /oauth/token` | HTTP request throws `SocketException` / `ClientException`. Client catches exception, displays «Не удалось войти через Nios ID», resets busy state to allow retry. |
| 6 | WebSocket Login | `login_nios_id` rejected (e.g. revoked OAuth access token) | WebSocket returns error response (`response.payload.access_token` missing or error set). Client throws `ApiException`, shows error toast «NiosMess не принял вход Nios ID», stays on Auth Screen without partial session state. |
| 7 | Cold Start | Central Nios ID session revoked on another device (`GET /id/api/v1/account` returns 401) | Client clears local `AuthSession` from `FlutterSecureStorage`, disconnects WebSocket, shows Auth Screen, and displays toast: «Сессия Nios ID завершена. Войдите снова.». |
| 8 | Cold Start | Network is offline on startup (`GET /id/api/v1/account` fails with network timeout / error) | Client does NOT treat network error as 401. Stored session is retained, allowing offline cached message viewing and automatic reconnect when online. |
| 9 | Pre-auth Check | User not logged in to Nios ID (`GET /id/api/v1/account` returns 401) | Client redirects to `/id/login?next=%2Fweb%3Fnios_oauth%3Dstart`. Once logged into Nios ID, user is redirected back to `/web?nios_oauth=start`, which automatically initiates `beginNiosIdAuthorization()`. |
| 10 | Logout | User taps «Выйти» while offline (network drops before `POST /id/api/v1/logout` completes) | Handled in `try ... finally` block: even if HTTP logout fails, local WebSocket is closed, local secure storage is wiped, cache cleared, and user is routed to Auth Screen / Nios ID login. |
| 11 | URL Encoding | Base64 standard characters (`+`, `/`, `=`) in PKCE verifier/challenge | Standard Base64 causes OAuth 2.0 PKCE failures. Encoding MUST replace `+` with `-`, `/` with `_`, and strip all trailing `=` padding characters. |
| 12 | Redirect URI Matching | Minor mismatch in redirect URI (e.g. `https://ni-os.ru/web/` vs `https://ni-os.ru/web` or added fragments) | Strict exact match required: `https://ni-os.ru/web`. Any trailing slash or query string in redirect URI will cause Nios ID OAuth server to reject authorization. |
| 13 | Address Bar Leakage | Browser history or referrer header capturing authorization code | Immediately upon callback entry, `history.replaceState({}, document.title, window.location.pathname || "/web")` (or GoRouter replace) is called before triggering network operations. |
| 14 | Responsive Layout | Viewport width < 480dp (mobile) vs >= 840dp (desktop) | Mobile: single centered card with max width 480dp. Desktop: split or centered hero layout with brand card and interactive action block. Zero horizontal overflow. |

---

## 4. Detailed Technical Protocol Specifications

### 4.1. PKCE S256 Cryptographic Algorithm
1. **Verifier Entropy**:
   - 64 raw random bytes generated from CSPRNG (`Random.secure()` in Dart / `crypto.getRandomValues()` in JS).
   - Base64URL encoded without padding:
     $$\text{code\_verifier} = \text{Base64UrlEncode}(\text{randomBytes}(64))$$
2. **Challenge Computation**:
   - SHA-256 hash of the ASCII bytes of `code_verifier`:
     $$\text{digest} = \text{SHA256}(\text{utf8.encode}(\text{code\_verifier}))$$
   - Base64URL encode the 32-byte digest without padding:
     $$\text{code\_challenge} = \text{Base64UrlEncode}(\text{digest})$$
3. **State & Nonce**:
   - `state`: 24 raw random bytes, Base64URL encoded without padding.
   - `nonce`: 24 raw random bytes, Base64URL encoded without padding.

### 4.2. OAuth 2.0 Endpoints & Parameters

#### 1) Authorization Endpoint
- **URL**: `https://ni-os.ru/oauth/authorize`
- **Method**: HTTP GET (Browser redirect)
- **Parameters**:
  - `response_type`: `code`
  - `client_id`: `niosmess_web`
  - `redirect_uri`: `https://ni-os.ru/web` (or platform equivalent)
  - `scope`: `openid profile email`
  - `state`: `<base64url-state>`
  - `nonce`: `<base64url-nonce>`
  - `code_challenge`: `<base64url-challenge>`
  - `code_challenge_method`: `S256`

#### 2) Token Exchange Endpoint
- **URL**: `https://ni-os.ru/oauth/token`
- **Method**: HTTP POST
- **Headers**:
  - `Content-Type`: `application/x-www-form-urlencoded`
- **Credentials**: `same-origin`
- **Body**:
  - `grant_type`: `authorization_code`
  - `code`: `<authorization-code>`
  - `client_id`: `niosmess_web`
  - `redirect_uri`: `https://ni-os.ru/web`
  - `code_verifier`: `<base64url-verifier>`
- **Response Structure (200 OK)**:
  ```json
  {
    "access_token": "eyJhbGciOi...",
    "token_type": "Bearer",
    "expires_in": 3600,
    "scope": "openid profile email"
  }
  ```

#### 3) Session Check Endpoint
- **URL**: `https://ni-os.ru/id/api/v1/account`
- **Method**: HTTP GET
- **Credentials**: `same-origin`
- **Responses**:
  - `200 OK`: Account active
  - `401 Unauthorized`: Session expired / revoked
  - Other / Connection error: Preserve local state

#### 4) Central Logout Endpoint
- **URL**: `https://ni-os.ru/id/api/v1/logout`
- **Method**: HTTP POST
- **Credentials**: `same-origin`

---

### 4.3. WebSocket Exchange Protocol

- **Endpoint**: `wss://ni-os.ru/ws`
- **Action**: `login_nios_id`
- **Payload**:
  ```json
  {
    "oauth_access_token": "<oauth_access_token>",
    "device_info": "Linux x86_64 · Mozilla/5.0 (Windows NT 10.0; Win64; x64)..."
  }
  ```
- **Response Payload**:
  ```json
  {
    "access_token": "local-niosmess-session-token-...",
    "user_id": 123,
    "nios_id": "nios_user_abc123",
    "username": "johndoe",
    "display_name": "John Doe"
  }
  ```
- **Security Invariant**:
  - `oauth_access_token` is discarded immediately after sending.
  - `access_token` (local session token) is saved to `FlutterSecureStorage` under key `auth.session`.
  - Trigger `E2eeService.getPublicKeyBase64()` & `set_public_key` WebSocket action.

---

### 4.4. Storage Discipline Matrix

| Data Item | Storage Location | Lifetime | Prohibited Locations |
|-----------|------------------|----------|----------------------|
| `code_verifier` | `sessionStorage` (Web) / Memory (Native) | From redirect start until callback processing | `localStorage`, URLs, Analytics, Logs, `FlutterSecureStorage` |
| `state` | `sessionStorage` (Web) / Memory (Native) | From redirect start until callback processing | `localStorage`, URLs, Analytics, Logs, `FlutterSecureStorage` |
| `oauth_access_token` | In-memory variable only | Duration of WebSocket handshake (milliseconds) | ANY persistent storage (`localStorage`, `FlutterSecureStorage`, Hive, SharedPreferences) |
| Local `AuthSession` (`access_token`, `user_id`, `username`, `displayName`, `nios_id`) | `FlutterSecureStorage` (key: `auth.session`) | Persistent across app restarts until logout | Unencrypted local storage, URLs, Logs |
| Central `nios_session` | HTTP-only Cookie on `ni-os.ru` | Managed by browser/system | Client JavaScript access or transmission to WebSocket |

---

### 4.5. Material 3 Expressive UI & Legal Specifications

1. **Brand Hero & Typography**:
   - Header with NiosMess squircle logo (`AppLogoMark`), official Nios ID badge, and typography using GoogleFonts / Expressive styles.
   - Elimination of all username/password `M3AuthTextField` instances.
2. **Ecosystem Benefits Card**:
   - Container: `Theme.of(context).colorScheme.surfaceContainerLow` with rounded corners (24dp) and subtle border `outlineVariant`.
   - 3 Pillars:
     1. **Единый аккаунт Nios ID** (`Icons.badge_outlined`) — вход в единую экосистему сервисов.
     2. **Сквозное E2EE-шифрование** (`Icons.lock_outline_rounded`) — секретные чаты защищены ключами на устройстве.
     3. **Без передачи пароля** (`Icons.shield_outlined`) — пароль вводится только на защищённой странице Nios ID.
3. **Primary Action**:
   - Height: `56.0` dp
   - Shape: `RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.0))` (Pill shape)
   - Color: `colorScheme.primary` container with `colorScheme.onPrimary` text/icon.
   - Label: «Войти через Nios ID»
   - Haptic: `HapticService.tap()`
4. **Secondary Action**:
   - Text button / Outlined link: «Создать Nios ID» -> navigates to `https://ni-os.ru/id/login?next=/web` or registration portal.
5. **Legal Footer**:
   - High-contrast links to `/legal/privacy` and `/legal/terms` invoking `LegalViewerScreen`.

---

## 5. Architectural Compliance & Code Conventions

Per `AGENTS.md`:
- **Riverpod 3.x**: State managed via `NotifierProvider<AuthNotifier, AuthState>` (no `StateNotifierProvider` or `StateProvider`).
- **Cross-platform I/O**: `package:universal_io/io.dart` (no raw `dart:io`).
- **Color Tokens**: Semantic `Theme.of(context).colorScheme` only (no `Colors.white`, `Colors.black`, or `withOpacity()`; use `withValues(alpha:)`).
- **Buttons**: Explicit `WidgetStatePropertyAll<Color>`.
- **Localization**: User-facing strings in `lib/l10n/app_*.arb` accessed via `context.l10n.*`.
- **SemVer Protocol**: Version bump in `pulse_flutter/pubspec.yaml` upon completion.
