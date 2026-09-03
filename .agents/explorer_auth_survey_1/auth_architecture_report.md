# NiosMess (pulse_flutter) — Authentication & Routing Architecture Report
**Author:** Auth & Routing Explorer  
**Date:** 2026-09-01  
**Target:** Unified Nios ID OAuth 2.0 PKCE Authentication & Material 3 Expressive Auth Hub

---

## Executive Summary

This investigation analyzes the existing authentication, routing, WebSocket lifecycle, session storage, and deep link mechanisms in `pulse_flutter` (`f:\Niosmess V2\pulse_flutter`). It defines the exact architectural transformations required to replace legacy username/password authentication with the unified **Nios ID OAuth 2.0 PKCE** flow and implement the **Material 3 Expressive Authentication Hub** according to `NIOSMESS_FRONTEND_LOGIN.md` and `ORIGINAL_REQUEST.md`.

---

## 1. Inventory of Current Authentication & Routing Architecture

### 1.1 State Management & Providers
- **`AuthNotifier` (`lib/providers/auth_provider.dart`)**:
  - Inherits from `Notifier<AuthState>` (Riverpod 3.x NotifierProvider).
  - State model `AuthState`:
    - `hydrated`: `bool` (session loaded from storage).
    - `busy`: `bool` (operation in progress).
    - `session`: `AuthSession?` (active session data).
    - `pendingIdentifier`: `String?` (legacy 2FA temp state).
    - `error`: `String?` (error message).
    - `profile`: `ApiProfile?` (user profile).
    - `isAuthenticated`: getter `session != null && session!.accessToken.isNotEmpty`.
  - Methods currently implemented:
    - `_load()` / `ensureLoaded()`: reads `auth.session` key from `FlutterSecureStorage`, parses JSON into `AuthSession`, sets `authTokenProvider`, and calls `refreshProfile()`.
    - `login({identifier, password})`: calls `AuthRepository.login()` via WebSocket `'login'`.
    - `register(...)`: calls `AuthRepository.register()` via WebSocket `'register'`.
    - `verifyEmail(...)`: calls `AuthRepository.verifyEmail()` via WebSocket `'verify_email'`.
    - `verifyTwoFa(...)`: calls `AuthRepository.verifyTwoFa()` via WebSocket `'verify_2fa'`.
    - `requestPasswordReset(...)` / `confirmPasswordReset(...)`: WebSocket `'reset_password_request'` / `'reset_password_confirm'`.
    - `refreshProfile()`: fetches `me_info` from WebSocket, caches to `CacheService`.
    - `logout()`: calls `unregisterFcmToken()`, WebSocket `'logout'`, terminates background service, closes WebSocket client, deletes `auth.session` from `FlutterSecureStorage`, clears `CacheService`.

- **`AuthTokenNotifier` (`lib/providers/token_provider.dart`)**:
  - Holds in-memory access token string (`_cachedToken`) and exposes `cachedAuthHeaders()` (`Authorization: Bearer <token>`).

- **`SessionNotifier` (`lib/providers/session_provider.dart`)**:
  - Manages `onboardingCompleted` boolean flag stored in `SharedPreferences` (`session.onboardingCompleted`).

### 1.2 Data Models
- **`AuthSession` (`lib/models/api/auth_models.dart`)**:
  - Fields: `accessToken` (`String`), `userId` (`int`), `username` (`String`), `displayName` (`String`).
  - Serialized to/from JSON in `FlutterSecureStorage` under key `'auth.session'`.
- **`AuthLoginResult` (`lib/models/api/auth_models.dart`)**:
  - Fields: `accessToken`, `tokenType`, `userId`, `username`, `displayName`, `twoFaRequired`, `message`.
- **`ApiProfile` (`lib/models/api/profile_model.dart`)**:
  - User identity attributes, badges, bio, avatar, 2FA status.
- **`ApiSession` (`lib/models/api/session_model.dart`)**:
  - Active session descriptors (`id`, `deviceInfo`, `ipAddress`, `createdAt`, `lastActive`).

### 1.3 Networking & WebSocket Layer
- **`WebSocketClient` (`lib/core/network/web_socket_client.dart`)**:
  - Base URL resolved from `ApiConstants.baseUrl` (`https://ni-os.ru/api/v1` -> `wss://ni-os.ru/ws`).
  - Encryption: Automatic initial unencrypted handshake -> server sends `key_exchange` with 32-byte key -> initializes AES-256-GCM (`AesGcm.with256bits()`). All subsequent traffic is encrypted with `{ encrypted: true, data: { ciphertext, iv, tag } }`.
  - Request/Response correlation: `request_id` counter + `Completer`.
  - Automatic reconnect with exponential backoff & jitter + 25-second heartbeat ping.
  - Dispatches `onUnauthorized` callback on unauthorized errors (triggers `authNotifier.logout()`).

- **`AuthRepository` (`lib/repositories/auth_repository.dart`)**:
  - Currently executes auth actions via `webSocketClientProvider.request(...)`:
    - `register`
    - `verify_email`
    - `login`
    - `verify_2fa`
    - `reset_password_request`
    - `reset_password_confirm`
    - `me_info`
    - `logout`
    - `unregister_fcm_token`
    - `list_sessions` / `kick_session`
    - `set_public_key` / `get_public_key`

- **`ApiClient` (`lib/core/network/api_client.dart`)**:
  - HTTP REST client (`http.Client`) with Bearer token injection from `authTokenProvider`.
  - Standard methods: `get`, `post`, `put`, `patch`, `delete`, `postBytes`.

### 1.4 Routing & Deep Links
- **`AppRouter` (`lib/router/app_router.dart`)**:
  - `refreshListenable` bound to `authProvider` authentication changes.
  - Redirect Guard:
    - If not hydrated: return `null`.
    - If unauthenticated and path is not public: redirect to `/login`.
    - If authenticated and path is `/login`, `/onboarding`, `/register`, `/setup`, `/2fa`: redirect to `/main/chats`.
  - Current Public Routes: `/`, `/onboarding`, `/login`, `/register`, `/setup`, `/verify-email`, `/2fa`, `/reset-password/request`, `/reset-password/confirm`, `/legal/*`.
- **`DeepLinkService` (`lib/core/services/deep_link_service.dart`)**:
  - Initialized on native platforms via `app_links` (`uriLinkStream.listen(_handleUri)`).
  - Dispatches route changes to `AppRouter.navigatorKey.currentContext`.

---

## 2. Gap Analysis: Current State vs. Target Nios ID OAuth 2.0 PKCE

| Aspect | Current State in `pulse_flutter` | Required State (Target Specification) |
|---|---|---|
| **Credentials Input** | Forms for username, password, email, display name in `LoginScreen` & `RegisterScreen` | **Zero password or username fields**. Unified hub with single primary action «Войти через Nios ID». |
| **Auth Protocol** | Legacy username/password sent over WebSocket (`action: login`) | **OAuth 2.0 Authorization Code Flow with PKCE (S256)** + Token Exchange via `POST /oauth/token`. |
| **WS Auth Action** | `login` with `{ identifier, password }` | `login_nios_id` with `{ oauth_access_token, device_info }`. |
| **OAuth Token Storage** | N/A | `oauth_access_token` is **ephemeral only** — NEVER stored in `localStorage` or `FlutterSecureStorage`. Discarded after WS session establishment. |
| **PKCE Verifier & State** | N/A | Generated cryptographically (64-byte verifier, 24-byte state/nonce), stored in `sessionStorage` (Web) or ephemeral memory, cleared immediately upon callback. |
| **Callback Processing** | N/A | Intercept `?code=...&state=...`, sanitize URL address bar (`history.replaceState`), exchange code for OAuth access token, connect WS `login_nios_id`. |
| **Cold Start Verification** | Reads local `auth.session` and calls `getMe()` | Verifies central Nios ID session via `GET /id/api/v1/account`. If `401`, immediately purges local session and prompts re-auth. |
| **Logout** | WS `logout` + local storage clear | `POST /id/api/v1/logout` + WS `logout` + local storage clear + redirect to `/id/login?next=/web`. |
| **Registration / Password Reset** | Local screens (`/register`, `/verify-email`, `/reset-password/*`) | Delegated to Nios ID ecosystem portal (`https://ni-os.ru/id/register` / `/id/login`). Local routes consolidated or redirected. |
| **M3 Expressive Design** | Split login/register screens with fragmented titles | Unified responsive Auth Hub (maxWidth: 480dp), Hero header, 3 ecosystem benefit pillars (`surfaceContainerLow`), 56dp/28dp pill button. |

---

## 3. Detailed Technical Architecture for Nios ID Integration

### 3.1 OAuth 2.0 PKCE Specification & Constants
- **Constants**:
  - `clientId`: `'niosmess_web'`
  - `redirectUri`:
    - Web: `${Uri.base.origin}/web` (e.g. `https://ni-os.ru/web`)
    - Non-web / Deep Link: `https://ni-os.ru/web` or custom URI scheme registered in `AppLinks`
  - `scopes`: `'openid profile email'`
  - `authorizeEndpoint`: `https://ni-os.ru/oauth/authorize` (or `/oauth/authorize` on same-origin)
  - `tokenEndpoint`: `https://ni-os.ru/oauth/token` (or `/oauth/token` on same-origin)
  - `accountEndpoint`: `https://ni-os.ru/id/api/v1/account` (or `/id/api/v1/account`)
  - `logoutEndpoint`: `https://ni-os.ru/id/api/v1/logout` (or `/id/api/v1/logout`)

### 3.2 PKCE Helper Implementation
```dart
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart'; // or cryptography package (already in pubspec)

class PkceHelper {
  static String base64UrlUnpadded(List<int> bytes) {
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static String generateRandomString([int length = 32]) {
    final Random random = Random.secure();
    final Uint8List values = Uint8List(length);
    for (int i = 0; i < length; i++) {
      values[i] = random.nextInt(256);
    }
    return base64UrlUnpadded(values);
  }

  static String generateCodeVerifier() => generateRandomString(64);
  static String generateState() => generateRandomString(24);
  static String generateNonce() => generateRandomString(24);

  static String generateCodeChallenge(String verifier) {
    final List<int> bytes = utf8.encode(verifier);
    final Digest digest = sha256.convert(bytes);
    return base64UrlUnpadded(digest.bytes);
  }
}
```

### 3.3 Authorization Flow & Callback Handling
1. **Initiate Authorization**:
   - Check central Nios ID session via `GET /id/api/v1/account`:
     - If status `401`: redirect to `/id/login?next=/web?nios_oauth=start`.
     - Otherwise:
       - Generate `verifier` (64 bytes), `state` (24 bytes), `nonce` (24 bytes), and `code_challenge` (S256).
       - Store `verifier` and `state` in `sessionStorage` (Web) or ephemeral storage.
       - Construct authorization URL:
         `https://ni-os.ru/oauth/authorize?response_type=code&client_id=niosmess_web&redirect_uri=https://ni-os.ru/web&scope=openid+profile+email&state=...&nonce=...&code_challenge=...&code_challenge_method=S256`
       - Web: `window.location.assign(url)` / Non-web: launch system browser / Custom Tab.

2. **Handle Callback Return**:
   - Check query parameters for `nios_oauth=start` -> re-trigger `beginNiosIdAuthorization()`.
   - Check query parameters for `code`, `state`, `error`, `error_description`.
   - Clear query parameters from browser address bar immediately (`window.history.replaceState` or GoRouter redirect to `/web` / `/login`).
   - Retrieve stored `verifier` and `state` from ephemeral storage and immediately remove them.
   - If `error` present (e.g. `error=access_denied`):
     - Display error toast via `AppToast.showError(context, errorDescription)`.
     - Reset loading state and remain on auth screen.
   - If `state` does not match expected state:
     - Abort exchange, display error toast: "Не удалось проверить ответ Nios ID."
   - Perform Authorization Code Exchange:
     - `POST /oauth/token` with `Content-Type: application/x-www-form-urlencoded`:
       `grant_type=authorization_code&code=...&client_id=niosmess_web&redirect_uri=...&code_verifier=...`
     - Extract `access_token` (`oauth_access_token`).

3. **WebSocket Login (`login_nios_id`) & E2EE Setup**:
   - Ensure WebSocket client is connected (`await wsClient.connect()`).
   - Send WS action `login_nios_id`:
     ```json
     {
       "action": "login_nios_id",
       "payload": {
         "oauth_access_token": "<oauth_access_token>",
         "device_info": "<platform_and_user_agent>"
       }
     }
     ```
   - Receive local NiosMess session:
     ```json
     {
       "access_token": "local_niosmess_token",
       "user_id": 123,
       "nios_id": "nios_user_123",
       "username": "username",
       "display_name": "Display Name"
     }
     ```
   - Construct `AuthSession` and persist to `FlutterSecureStorage` (`auth.session`).
   - Set in-memory `authTokenProvider`.
   - Initialize E2EE key pair (`e2eeService.getPublicKeyBase64()` -> `authRepository.setPublicKey(...)`).
   - Refresh user profile (`authRepository.getMe()`).
   - Register FCM push token if on mobile.
   - Navigate to `/main/chats`.
   - Discard `oauth_access_token` from memory.

### 3.4 Cold Start Session Verification Flow
```
App Startup / Splash Screen
           │
           ▼
Check if OAuth Callback Query Params Exist (code, state, error, nios_oauth)
  ├── Yes ──► Execute OAuth Callback Exchange Flow ──► (Success -> /main/chats | Error -> /login)
  └── No
           │
           ▼
Check if Local NiosMess Session Exists in FlutterSecureStorage
  ├── No ──► Navigate to Unified Auth Screen (/login)
  └── Yes
           │
           ▼
Verify Central Nios ID Session: GET /id/api/v1/account
  ├── 401 Unauthorized ──► Central session invalid:
  │                        • authNotifier.logout()
  │                        • Show toast: "Сессия Nios ID завершена. Войдите снова."
  │                        • Navigate to /login
  └── 200 OK / Network Offline (non-401)
           │
           ▼
Resume Local Session, Connect WebSocket, Refresh Profile ──► Navigate to /main/chats
```

### 3.5 Clean Logout Flow
```
User taps «Выйти» in Settings / Profile
           │
           ▼
1. Unregister FCM Token: WS action 'unregister_fcm_token' (if mobile)
2. HTTP POST /id/api/v1/logout (terminates central Nios ID session)
3. WS action 'logout' & close WebSocket connection
4. Delete 'auth.session' from FlutterSecureStorage
5. Clear CacheService, E2EE in-memory secrets, and state
6. Web: window.location.assign('/id/login?next=/web')
   Non-web: context.go('/login')
```

---

## 4. UI/UX Specification: Unified Material 3 Expressive Auth Hub

### 4.1 Visual Hierarchy & Design Elements
1. **Container & Layout**:
   - `M3OrganicBackground` with smooth animated backdrop.
   - Responsive centering constrained to `maxWidth: 480`.
   - Vertical padding with scroll resilience across keyboard open/close.

2. **Hero Header**:
   - App Logo: Squircle brand logo mark (`AppLogoMark(size: 72)`).
   - Official Nios ID Badge / Logo alongside NiosMess branding.
   - Title: `GoogleFonts.unbounded` (24sp, weight 800, letterSpacing -0.4).
   - Subtitle: `GoogleFonts.inter` (14sp, `onSurfaceVariant`).

3. **Ecosystem Benefits Card (`surfaceContainerLow`)**:
   - Elevated tonal container with 24dp rounded corners and subtle border.
   - 3 Highlighted Pillars:
     1. **Единый аккаунт Nios ID** (`Icons.badge_outlined`) — быстрый вход без паролей.
     2. **Сквозное E2EE шифрование** (`Icons.lock_outline_rounded`) — ваши сообщения защищены.
     3. **Безопасная авторизация** (`Icons.shield_outlined`) — пароли никогда не передаются в клиент.

4. **Primary Action Block**:
   - 56dp height pill button (`FilledButton.icon` with 28dp radius).
   - Label: «Войти через Nios ID».
   - Icon: Nios ID brand glyph / `Icons.login_rounded`.
   - Loading State: compact spinner inside button + disabled interaction.
   - Haptic Feedback: `HapticService.tap()`.

5. **Secondary Action**:
   - Outlined/Text button: «Создать Nios ID» leading to Nios ID account registration (`/id/login?next=/web` or `/id/register`).

6. **Legal Footer**:
   - Responsive row with links to `/legal/privacy` («Политика конфиденциальности») and `/legal/terms` («Условия использования»).

7. **Auth Exchange Transition Overlay**:
   - When OAuth code exchange or WS login is processing, displays an elegant modal blur overlay with `AppLoadingIndicator` and status text: «Авторизация в Nios ID...».

---

## 5. Required Codebase Modifications Breakdown

### 5.1 `lib/models/api/auth_models.dart`
- Update `AuthSession` to optionally store `niosId` (`String? niosId`).
- Add `NiosOAuthTokenResponse` for parsing `POST /oauth/token` responses (`accessToken`, `tokenType`, `expiresIn`, `scope`, `idToken`).

### 5.2 `lib/repositories/auth_repository.dart`
- Add `loginNiosId({required String oauthAccessToken, required String deviceInfo})`:
  - Dispatches WS request `'login_nios_id'` with payload `{ 'oauth_access_token': oauthAccessToken, 'device_info': deviceInfo }`.
  - Returns `AuthLoginResult`.
- Add `checkCentralNiosIdSession()`:
  - Executes `GET /id/api/v1/account` (or `https://ni-os.ru/id/api/v1/account`).
  - Returns boolean indicating if central session is active (returns `false` ONLY on 401).
- Add `logoutCentralNiosId()`:
  - Executes `POST /id/api/v1/logout`.

### 5.3 `lib/providers/auth_provider.dart`
- Add `loginWithOAuth({required String oauthAccessToken})`:
  - Collects device info (`'Flutter · ...'`).
  - Calls `authRepository.loginNiosId(...)`.
  - Saves `AuthSession` to `FlutterSecureStorage`.
  - Refreshes profile & sets E2EE public key.
- Update `ensureLoaded()` / `_load()`:
  - If session exists, calls `checkCentralNiosIdSession()`. If 401 -> automatically executes `logout()`.
- Update `logout()`:
  - Calls `logoutCentralNiosId()`, unregisters FCM, closes WS, and purges storage.
- Remove/deprecate password/email login and registration mutation methods.

### 5.4 `lib/router/app_router.dart`
- Consolidate `/register`, `/verify-email`, `/2fa`, `/reset-password/*` routes to redirect to `/login`.
- Update redirect guard:
  - Public routes: `/`, `/login`, `/onboarding`, `/legal/*`.
  - Unauthenticated users redirected to `/login`.
  - Authenticated users on `/login` or `/onboarding` redirected to `/main/chats`.

### 5.5 `lib/screens/login_screen.dart`
- Full rewrite to the unified **Material 3 Expressive Authentication Hub**:
  - Remove all `TextFormField`, password controllers, and validation logic.
  - Implement PKCE generation & browser redirect.
  - Implement callback detection, code exchange, and loading overlay.

### 5.6 `lib/screens/settings_account_screen.dart`
- Remove local password prompt dialogs for 2FA toggles; redirect 2FA and session management to Nios ID web portal / central API.

---

## 6. Test Plan & Acceptance Matrix

1. **PKCE Cryptographic Correctness**:
   - Unit tests verifying S256 code challenge matches standard SHA-256 base64url calculation.
   - State and verifier entropy and length verification.
2. **Unified Auth Screen Widget Tests**:
   - Zero `TextField` widgets exist on screen.
   - Hero header, ecosystem benefit card, and 56dp pill button render correctly.
   - Loading indicator transitions and tap disables when auth is busy.
   - Legal links navigate to `/legal/privacy` and `/legal/terms`.
3. **OAuth Exchange & Error Handling Tests**:
   - `access_denied` error displays user-friendly toast without crashing or breaking state.
   - Invalid `state` mismatch is rejected.
   - Successful token exchange calls `login_nios_id` and navigates to `/main/chats`.
4. **Cold Start & Logout Tests**:
   - Cold start with 401 from central session triggers clean logout.
   - Logout invokes `/id/api/v1/logout`, closes WS, and clears storage.
5. **Static Analysis**:
   - `flutter analyze` reports 0 issues.
