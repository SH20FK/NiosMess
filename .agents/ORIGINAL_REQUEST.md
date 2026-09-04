# Original User Request

## 2026-09-01T11:30:45Z

Implementation of the unified Nios ID OAuth 2.0 PKCE authentication flow and premium Material 3 Expressive authentication screen for NiosMess in accordance with NIOSMESS_FRONTEND_LOGIN.md.

Working directory: f:\Niosmess V2\pulse_flutter
Integrity mode: development

Specification reference: f:\Niosmess V2\NIOSMESS_FRONTEND_LOGIN.md

## Requirements

### R1. Unified Nios ID Auth Screen (Material 3 Expressive)
- Eliminate all local username and password input fields and separate registration screens from NiosMess in strict compliance with NIOSMESS_FRONTEND_LOGIN.md.
- Consolidate /login and /register into a unified, responsive Material 3 Expressive authentication hub centered around the primary action «Войти через Nios ID».
- Responsive desktop and mobile centering with maxWidth: 480dp.

### R2. Expressive Hub Visual Design & Hierarchy
- Hero Header: Brand NiosMess logo squircle alongside official Nios ID badge, expressive typography using GoogleFonts.unbounded and GoogleFonts.inter.
- Ecosystem Benefits Card: Elevated tonal container (surfaceContainerLow) with 3 highlighted pillars:
  1. Unified Nios ID Account (Icons.badge_outlined)
  2. End-to-End E2EE Encryption (Icons.lock_outline_rounded)
  3. Zero Password Transmission to Client App (Icons.shield_outlined)
- Primary Action Block: Full-width 56dp pill button (FilledButton.icon with 28dp radius) labeled «Войти через Nios ID» with branded icon and haptic feedback. Secondary action «Создать Nios ID» leading to Nios ID account registration.
- Legal Footer: High-contrast, responsive links to «Политика конфиденциальности» and «Условия использования» invoking the Material 3 Expressive Legal Reader (/legal/privacy and /legal/terms).

### R3. OAuth 2.0 PKCE & Token Exchange Flow
- PKCE Generation: Standard S256 code verifier (64-byte random base64url) and code challenge (SHA-256 base64url without padding) with cryptographic randomness.
- Ephemeral State Storage: Store verifier and state strictly in ephemeral storage (sessionStorage on Web) prior to redirect.
- Authorization Redirect:
  - Web: Perform clean navigation to /oauth/authorize?response_type=code&client_id=niosmess_web&redirect_uri=...&scope=openid+profile+email&state=...&code_challenge=...&code_challenge_method=S256.
  - Non-web (Mobile/Desktop): Launch system browser / Custom Tabs with deep link callback (app_links).
- Callback Interception & Exchange:
  - Intercept return parameters (code, state, error) before app initialization.
  - Sanitize the browser address bar via history.replaceState or GoRouter redirect to prevent code leakage.
  - Validate received state against stored state.
  - Exchange authorization code for short-lived access token via POST /oauth/token (grant_type=authorization_code).

### R4. WebSocket login_nios_id Action & Local Session Setup
- Connect WebSocket client (wss://ni-os.ru/ws).
- Dispatch action login_nios_id with payload { "oauth_access_token": token, "device_info": ... }.
- Save returned local NiosMess session (access_token, user_id, nios_id, username, display_name) to client storage.
- Initialize E2EE encryption without ever storing the temporary oauth_access_token.

### R5. Loading States, Error Handling & Consent Cancellation UX
- Inline Loading: Transition primary button into a compact spinner with disabled tap state upon initiating authorization.
- Exchange Transition Overlay: Display an elegant tonal loading overlay with status text «Авторизация в Nios ID...» during callback processing.
- Error & Cancellation Handling: If user denies consent on Nios ID (error=access_denied), dismiss overlay, re-enable the button, and show a clear error toast via AppToast.showError(...) without breaking app state.

### R6. Session Verification on Cold Start & Logout Flow
- Cold Start: On application launch / refresh, if a stored NiosMess session exists, verify central Nios ID session via GET /id/api/v1/account. If 401, clear local session and prompt re-authentication.
- Clean Logout: Tapping «Выйти» in settings triggers POST /id/api/v1/logout, terminates WebSocket and local storage, and redirects to /id/login?next=/web.
- No periodic background polling timers (per user preference).

## Acceptance Criteria

### Security & Contract Compliance
- [ ] Zero password or username input fields exist in NiosMess client code.
- [ ] No direct access or usage of nios_session cookies from JavaScript / client.
- [ ] PKCE S256 verifier and state are stored strictly in ephemeral storage and removed upon callback.
- [ ] Authorization code and state are cleared from URL address bar immediately upon return.
- [ ] oauth_access_token is never persisted to long-term storage or exposed in logs.

### Visual & Architecture Quality
- [ ] Auth screen uses semantic Material 3 Expressive tokens (colorScheme.surface, colorScheme.surfaceContainerLow, colorScheme.onPrimary, etc.) with zero hardcoded Colors.white/Colors.black or legacy withOpacity().
- [ ] Primary button uses 56dp height and 28dp pill radius with high contrast in both light and dark themes.
- [ ] Layout is responsive across mobile and desktop (maxWidth: 480dp centering).

### Automated Verification
- [ ] All unit and widget tests covering the Nios ID auth screen, PKCE generation, callback handling, and error states pass (flutter test).
- [ ] All pre-existing test suites pass without regression.
- [ ] flutter analyze reports 0 errors and 0 warnings.
- [ ] Semantic version automatically bumped in pubspec.yaml following SemVer protocol.

## 2026-09-02T18:38:20Z

Complete Material 3 Expressive redesign and responsive web adaptivity for NiosGram social feed (720-800dp wide adaptive feed with floating controls and rich media cards) and all Settings screens (responsive 2-pane Master-Detail layout on desktop/web, fully conforming to Material 3 Expressive components, tonal grouping, and crisp SVG iconography).

Working directory: f:\Niosmess V2\pulse_flutter
Integrity mode: development

## Requirements

### R1. NiosGram Expressive Feed & Responsive Web Adaptation
- Expand NiosGram layout on wide screens/desktop to an adaptive centered 720-800dp canvas, removing awkward side voids while keeping optimal reading line lengths.
- Redesign post cards with Material 3 Expressive tokens:
  - Tonal container surfaces (surfaceContainerLow / surfaceContainer), subtle borders (outlineVariant), and 20-24dp smooth corners.
  - Expressive typography: author names in bold with handle, relative time badge, and verified tick.
  - Full-width aspect-ratio media viewports with smooth blur/shimmer loaders and rounded inner corners (16dp).
  - Floating and inline action controls: heart/like button with reactive animation, comment trigger with counter, share, and bookmark.
  - Polished quick-creation FAB/bar with expressive shape (flutter_m3shapes).

### R2. Settings Master-Detail Architecture & Pure M3 Overhaul
- Transform Settings on desktop/wide screens into an ergonomic 2-pane (Master-Detail) layout:
  - Left pane (320-360dp): expressive list of settings sections (Аккаунт, Внешний вид, Приватность и безопасность, Хранилище, Язык и регион, Уведомления, О приложении, E2EE) with active highlight indicator (secondaryContainer).
  - Right pane (expanded): direct in-place rendering of the selected settings sub-screen without forcing deep navigation.
  - On mobile: seamless fallback to classic full-screen stacked navigation.
- Overhaul ALL individual settings screens (settings_account_screen.dart, settings_appearance_screen.dart, settings_privacy_screen.dart, settings_storage_screen.dart, settings_language_region_screen.dart, settings_preferences_screen.dart, settings_about_screen.dart, e2ee_settings_screen.dart, profile_screen.dart):
  - Standardize on M3 Expressive grouped cards (surfaceContainerLow, 20dp radius).
  - Use Switch.adaptive, segmented buttons, and tonal sliders.
  - Expressive leading icons wrapped in distinct tonal squircle containers.

### R3. SVG & Vector Illustrations Integration
- Eliminate empty or flat placeholder elements across NiosGram and Settings.
- Embed crisp SVG/vector icons and illustrations for:
  - Empty feed states ("Лента пуста", "Здесь появятся ваши публикации").
  - Media placeholder states with soft tinted vector graphics.
  - Settings section headers and visual indicators.

### R4. Responsive Polish & Quality
- Eliminate all layout overflow errors across screen resize events (from 360dp mobile to 1920dp+ 4K).
- Zero flutter analyze errors or warnings.
- Build and verify for Web (flutter build web --profile).

## Acceptance Criteria

### Visual & Interactive Quality
- [ ] NiosGram feed on desktop expands to an expressive 720-800dp card layout with zero awkward dead margins.
- [ ] Settings on desktop displays as a 2-pane Master-Detail layout with instant switching.
- [ ] All 8+ settings screens strictly use Material 3 Expressive surfaces (surfaceContainerLow), switches, sliders, and tonal icon containers.
- [ ] Empty feed and loading placeholders feature rich vector/SVG assets instead of plain grey boxes.
- [ ] flutter analyze reports 0 issues (zero warnings, zero errors).
- [ ] Application compiles and runs cleanly in web (flutter build web --profile).

## 2026-09-04T09:54:05Z

Execute the complete end-to-end multi-agent performance optimization of the graphics pipeline, message lists, and media caching for NiosMess (pulse_flutter) for stable and smooth 60/120 FPS adaptive frame rate performance across both budget and flagship devices.

Requirements:
- R1. Smart Adaptive Performance Engine (jank detection, adaptive degradation/enhancement of shaders, MeshGradient, BackdropFilter, M3 Expressive)
- R2. List Virtualization Optimization & Dynamic Memory Management (smooth 60/120 FPS scroll in chat_detail_screen, chat_list_screen, NiosGram post_card, adaptive image decoding with memCacheWidth/Height, RepaintBoundary, viewport eviction, Riverpod select rebuild prevention)
- R3. Background Energy Efficiency & Resource Leak Elimination (controllers, websockets, timers audit and cleanup)

Strictly adhere to f:\Niosmess V2\AGENTS.md, maintain your plan.md, progress.md, and BRIEFING.md in f:\Niosmess V2\.agents\orchestrator_5.
Dispatch specialized subagents (explorers, workers, reviewers, challengers, etc.). NOTE: when invoking subagents, specify Model: 'flash' to preserve quota.
Ensure all tests pass and flutter analyze reports 0 issues. Update pubspec.yaml following SemVer protocol.
When work is complete and verified by your team, report completion to the Sentinel via send_message.


