# Handoff Report: Adversarial Challenge on Nios ID Auth, Cold Start, Clean Logout & Responsiveness

**Verdict**: `REQUEST_CHANGES`

---

## 1. Observation

### 1.1 Test Suite Execution
- Executed `flutter test` across all unit, widget, and integration test suites:
  ```powershell
  flutter test
  ```
  Result: **299/299 tests passed** in 42s across existing test files (`test/integration/e2e_cold_start_and_logout_test.dart`, `test/integration/e2e_auth_flow_test.dart`, `test/unit/oauth_service_test.dart`, `test/stress/oauth_service_stress_test.dart`, `test/stress/pkce_stress_test.dart`, etc.).

### 1.2 Session Probe (HTTP 401 vs 500/Offline) Evaluation
- In `lib/services/oauth_service.dart:20-40`:
  ```dart
  Future<bool> checkCentralNiosIdSession({http.Client? client}) async {
    final http.Client httpClient = client ?? http.Client();
    try {
      final http.Response response = await httpClient.get(
        Uri.parse(ApiConstants.accountCheckUrl),
        headers: const <String, String>{'Accept': 'application/json'},
      );
      if (response.statusCode == 401) {
        return false;
      }
      return true;
    } catch (_) {
      // Network errors / offline must not kick the user out
      return true;
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }
  ```
- In `lib/providers/auth_provider.dart:121-133`:
  - `_load()` triggers auto-logout and purges storage ONLY when `checkCentralNiosIdSession()` returns `false` (HTTP 401).
  - Status codes 200, 204, 500, 502, 503, 504, and `ClientException` / `SocketException` return `true`, keeping the local session intact for offline operation.
  - Verified by tests in `test/unit/oauth_service_test.dart` (lines 15-62) and `test/integration/e2e_cold_start_and_logout_test.dart` (tests 23.1 - 23.4, T2.3, T2.4).

### 1.3 Clean Logout Pipeline Resilience
- In `lib/providers/auth_provider.dart:493-528`:
  - FCM token unregistration (`PushNotificationService.getToken()`, `unregisterFcmToken`) is wrapped in `try { ... } catch (e) { ... }`.
  - WebSocket logout is dispatched.
  - Central logout `oauthServiceProvider.logoutCentralNiosId()` (POST `/id/api/v1/logout`) is executed inside a separate `try/catch`.
  - Guaranteed execution path outside try blocks ensures:
    - `BackgroundService.stop()`
    - `_fcmTokenRefreshSubscription?.cancel()`
    - `ref.read(webSocketClientProvider).close()`
    - `await _clearSessionStorage()` (deletes `auth.session` from `FlutterSecureStorage` and clears `authTokenProvider`)
    - `cacheServiceProvider.clearAll()` (wrapped in try/catch)
    - `state = state.copyWith(clearSession: true, clearPendingIdentifier: true, clearError: true, clearProfile: true)`
  - Verified by tests in `test/integration/e2e_cold_start_and_logout_test.dart` (tests 24.1 - 24.8, T2.2, T2.5).

### 1.4 Consent Denial (`error=access_denied`) Handling
- In `lib/screens/login_screen.dart:55-87`:
  - Query parameter `error` and `error_description` are intercepted before UI interaction.
  - Address bar is sanitized via `OAuthNavigationHelper().sanitizeAddressBar()`.
  - `HapticService.destructive()` is triggered and `AppToast.showError(...)` is displayed.
  - Interactive state (`_isStartingAuth`, `_isExchanging`) remains `false` (or resets in `finally`), leaving the primary login button immediately enabled for retry without application lockup or corrupted state.
  - Verified by tests in `test/integration/e2e_auth_flow_test.dart` (tests 21.1 - 21.5, Scenario 5).

### 1.5 Screen Width Responsiveness (320dp to 3840dp) Failure
- Added comprehensive viewport matrix in `test/screens/login_screen_adversarial_responsiveness_test.dart`.
- Executed `flutter test test/screens/login_screen_adversarial_responsiveness_test.dart`:
  ```text
  ════════════════════════════════════════════════════════════════════════════════════════════════════
  A RenderFlex overflowed by 104 pixels on the right.
  The relevant error-causing widget was:
    Row Row:file:///F:/Niosmess%20V2/pulse_flutter/lib/screens/login_screen.dart:469:15
  constraints: BoxConstraints(0.0<=w<=225.7, 0.0<=h<=56.0)
  size: Size(225.7, 23.0)
  direction: horizontal
  mainAxisAlignment: center
  ════════════════════════════════════════════════════════════════════════════════════════════════════
  ```
- Specific viewport overflow amounts:
  - `Compact Mobile (iPhone SE)` (320x568): **overflowed by 104 pixels on the right**
  - `Narrow Android` (360x640): **overflowed by 64 pixels on the right**
  - `Standard Mobile (iPhone 14)` (390x844): **overflowed by 34 pixels on the right**
  - `Large Mobile (Pixel 7 Pro)` (412x915): **overflowed by 12 pixels on the right**
- Root cause in `lib/screens/login_screen.dart:469-483`:
  ```dart
  // Inside FilledButton child:
  Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.vpn_key_rounded, size: 20, color: scheme.onPrimary),
      const SizedBox(width: 10),
      Text(
        'Войти через Nios ID',
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
    ],
  )
  ```
  Inside a 56dp `FilledButton` on mobile viewports with horizontal padding (24dp container padding + button default padding), the unconstrained `Row` causes text rendering to overflow the flex container width on devices with screen widths <= 412dp.

---

## 2. Logic Chain

1. **R1 & R2 Contract Requirement**: `ORIGINAL_REQUEST.md` (R1, R2, Acceptance Criteria) requires the Auth Hub to be fully responsive across mobile and desktop devices down to standard mobile screens (320dp).
2. **Empirical Defect**: `test/screens/login_screen_adversarial_responsiveness_test.dart` empirically proved that on standard mobile screens (320dp, 360dp, 390dp, 412dp), rendering the `LoginScreen` throws a fatal Flutter framework `RenderFlex overflow` error during layout due to `Row` on line 469 of `lib/screens/login_screen.dart`.
3. **Other Subsystems**: Core OAuth PKCE logic, central session probe 401 vs 500/offline semantics, FCM/WS/Storage clean logout pipeline, and consent denial toast/reset are robust, well-tested, and fully adhere to specifications.
4. **Resolution**: A change request is required to fix the unconstrained `Row` in `LoginScreen._buildPrimaryAction` (e.g. by using `Flexible`/`FittedBox` or `FilledButton.icon` with responsive label).

---

## 3. Caveats

- The RenderFlex overflow only triggers on mobile viewport widths (<= 412dp). Tablet (600dp, 768dp) and desktop (1024dp to 3840dp) render cleanly without overflow due to centering within the 480dp/520dp constraint box.
- No other logic bugs were detected in auth session lifecycle, PKCE crypto math, token exchange, or clean logout.

---

## 4. Conclusion

**Verdict: `REQUEST_CHANGES`**

### Required Changes:
1. **Fix `LoginScreen` Primary Action Layout**:
   In `pulse_flutter/lib/screens/login_screen.dart:469`, replace the unconstrained `Row` inside `FilledButton` with a responsive structure, such as:
   ```dart
   FilledButton.icon(
     onPressed: (_isStartingAuth || _isExchanging) ? null : _startNiosIdAuth,
     style: FilledButton.styleFrom(
       backgroundColor: scheme.primary,
       foregroundColor: scheme.onPrimary,
       shape: RoundedRectangleBorder(
         borderRadius: BorderRadius.circular(28),
       ),
       elevation: 0,
     ),
     icon: _isStartingAuth
         ? SizedBox(
             width: 20,
             height: 20,
             child: CircularProgressIndicator(
               strokeWidth: 2,
               valueColor: AlwaysStoppedAnimation<Color>(scheme.onPrimary),
             ),
           )
         : Icon(Icons.vpn_key_rounded, size: 20, color: scheme.onPrimary),
     label: FittedBox(
       fit: BoxFit.scaleDown,
       child: Text(
         'Войти через Nios ID',
         style: GoogleFonts.inter(
           fontSize: 16,
           fontWeight: FontWeight.w700,
           letterSpacing: -0.2,
         ),
       ),
     ),
   )
   ```
2. **Verify All Responsiveness Viewports Pass**:
   Ensure `flutter test test/screens/login_screen_adversarial_responsiveness_test.dart` passes across all 12 viewports (320dp to 3840dp).

---

## 5. Verification Method

To independently reproduce and verify:

1. Run the adversarial responsiveness test matrix:
   ```powershell
   cd "f:\Niosmess V2\pulse_flutter"
   flutter test test/screens/login_screen_adversarial_responsiveness_test.dart
   ```
   **Expected Failure**: Viewports 320dp, 360dp, 390dp, 412dp throw `RenderFlex overflowed by X pixels on the right` on `login_screen.dart:469:15`.

2. Run the core cold start and logout test suite:
   ```powershell
   flutter test test/integration/e2e_cold_start_and_logout_test.dart
   ```
   **Expected Result**: All 18 tests pass.

3. Run the complete test suite after applying the layout fix:
   ```powershell
   flutter test
   ```
   **Expected Result**: All tests pass with 0 errors.
