# Handoff Report — Milestone M1: Core PKCE & OAuth Services

## 1. Observation
All deliverables requested in `DISPATCH.md` have been implemented and verified in `f:\Niosmess V2\pulse_flutter`:
1. `lib/core/network/pkce_helper.dart`:
   - `PkceHelper.base64UrlUnpadded(List<int> bytes)`: Converts raw bytes to unpadded Base64URL string (`[A-Za-z0-9_-]`, stripping `=` and replacing `+`/`/`).
   - `PkceHelper.generateCodeVerifier([int byteLength = 64])`: Generates 64 random bytes from CSPRNG (`Random.secure()`) encoded as unpadded Base64URL (86 characters, 512 bits of entropy).
   - `PkceHelper.generateCodeChallenge(String verifier)`: Computes SHA-256 digest of verifier ASCII bytes using `package:crypto` and returns unpadded Base64URL string (RFC 7636 S256).
   - `PkceHelper.generateState([int byteLength = 24])`: Generates 24 random bytes from CSPRNG encoded as unpadded Base64URL (32 characters).
   - `PkceHelper.generateNonce([int byteLength = 24])`: Generates 24 random bytes from CSPRNG encoded as unpadded Base64URL (32 characters).
2. `lib/core/network/api_constants.dart`:
   - `clientId`: `'niosmess_web'`
   - `redirectUri`: `'https://ni-os.ru/web'`
   - `scopes`: `'openid profile email'`
   - `oauthAuthorizeUrl`: `'https://ni-os.ru/oauth/authorize'`
   - `oauthTokenUrl`: `'https://ni-os.ru/oauth/token'`
   - `accountCheckUrl`: `'https://ni-os.ru/id/api/v1/account'`
   - `centralLogoutUrl`: `'https://ni-os.ru/id/api/v1/logout'`
3. `lib/core/storage/ephemeral_storage.dart`, `ephemeral_storage_stub.dart`, `ephemeral_storage_web.dart`:
   - Abstract `EphemeralStorage` factory contract with `savePkceSession(...)`, `getVerifier()`, `getState()`, `getNonce()`, `clear()`.
   - Web implementation utilizing browser `sessionStorage` with fallback to memory.
   - Stub/native implementation utilizing in-memory dictionary.
4. `lib/models/api/auth_models.dart`:
   - `AuthSession`: added optional `String? niosId` field with serialization in `toJson`, deserialization in `fromJson`, and `copyWith`.
   - `NiosOAuthTokenResponse`: model for `POST /oauth/token` response with `accessToken`, `tokenType`, `expiresIn` (handles int and string representations), `scope`, `idToken`, `error`, `errorDescription`, and `isSuccess` getter.
5. `lib/services/oauth_service.dart`:
   - `OAuthService.checkCentralNiosIdSession({http.Client? client})`: GET `/id/api/v1/account`. Returns `false` ONLY for 401; returns `true` for 200 OK and network errors.
   - `OAuthService.exchangeAuthCode({required String code, required String verifier, http.Client? client})`: POST `/oauth/token` with `application/x-www-form-urlencoded` body. Returns `NiosOAuthTokenResponse` or throws `ApiException`.
   - `OAuthService.logoutCentralNiosId({http.Client? client})`: POST `/id/api/v1/logout`. Returns `bool` without throwing unhandled exceptions.
   - `oauthServiceProvider`: Riverpod provider for `OAuthService`.
6. `test/unit/pkce_test.dart` & `test/unit/oauth_service_test.dart`:
   - 27 comprehensive unit tests testing standard RFC 7636 Appendix B test vectors, URL-safe Base64 character sets, entropy, ephemeral storage, HTTP mocks, network error resilience, 401 status checks, and model serialization.
7. Verification results:
   - `flutter test test/unit/`: 27/27 tests passed (exit code 0).
   - `flutter analyze`: 0 errors, 0 warnings (exit code 0).
   - `pubspec.yaml`: version bumped to `3.5.0+7`.

## 2. Logic Chain
- **Step 1 (Cryptographic Foundation)**: In OAuth 2.0 PKCE with S256, security relies on high-entropy verifiers and collision-resistant SHA-256 challenges. `PkceHelper` utilizes `Random.secure()` (CSPRNG) to generate 64 bytes (512-bit entropy) for the verifier, and 24 bytes (192-bit entropy) for state and nonce. The RFC 7636 Appendix B vector was tested and matched character-for-character (`dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk` -> `E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM`).
- **Step 2 (Storage Discipline)**: As mandated in `NIOSMESS_FRONTEND_LOGIN.md`, PKCE verifier and state must never touch persistent storage (`FlutterSecureStorage` or `localStorage`). `EphemeralStorage` provides cross-platform abstraction where web environments use browser `sessionStorage` (which is scoped to the browser tab session and destroyed on tab close) and native/test environments use in-memory store.
- **Step 3 (Resilient Session Verification)**: `checkCentralNiosIdSession` queries the central identity server. Per specification, ONLY HTTP status 401 indicates that the central session is inactive or terminated. Network failures (e.g. offline device, packet drop, timeout) return `true` so offline message cache and app functionality remain accessible without falsely evicting the user.
- **Step 4 (Clean Token Exchange & Model Integrity)**: `exchangeAuthCode` communicates with `/oauth/token` using the standard form URL encoding. `NiosOAuthTokenResponse` captures token payload or parses server error descriptions into structured `ApiException` instances.
- **Step 5 (Verification & Lint Hygiene)**: Comprehensive unit tests were written covering all edge cases, and all imports and lints were polished to achieve clean `flutter analyze` report.

## 3. Caveats
- `OAuthService.checkCentralNiosIdSession` and `exchangeAuthCode` provide optional `http.Client? client` injection parameters. When `client` is null, a default `http.Client()` is created and closed per request. In production, this can also be bound to a shared client or cookie-preserving client where needed.
- On Flutter Web, `sessionStorage` is accessed via `dart:html` with linter ignore comments (`deprecated_member_use, avoid_web_libraries_in_flutter`). If future Flutter versions mandate pure `package:web`, the underlying implementation can swap to `package:web` without affecting the `EphemeralStorage` contract.

## 4. Conclusion
Milestone M1 (Core PKCE & OAuth Services) is complete, thoroughly tested, and fully aligned with `NIOSMESS_FRONTEND_LOGIN.md`, `PROJECT.md`, and `AGENTS.md`. All unit tests pass with 100% success and static analysis passes with 0 warnings or errors.

## 5. Verification Method
To independently verify this milestone, run the following commands from `f:\Niosmess V2\pulse_flutter`:
```bash
flutter test test/unit/
flutter analyze
```
Expected output:
- `flutter test test/unit/`: `All tests passed!` (27/27 passed).
- `flutter analyze`: `No issues found!`.
