# BRIEFING — 2026-09-01T11:37:05Z

## Mission
Investigate pulse_flutter authentication, routing, WebSocket lifecycle, token storage, and prepare architecture report for Nios ID PKCE OAuth2 transition.

## 🔒 My Identity
- Archetype: explorer
- Roles: Auth & Routing Explorer
- Working directory: f:\Niosmess V2\.agents\explorer_auth_survey_1
- Original parent: 65ff2a5d-b51f-4b8f-9b41-07119b4e87c7
- Milestone: Auth & Routing Architecture Survey

## 🔒 Key Constraints
- Read-only investigation — do NOT implement
- Analyze pulse_flutter codebase thoroughly
- Adhere to Teamwork protocol and AGENTS.md conventions

## Current Parent
- Conversation ID: 65ff2a5d-b51f-4b8f-9b41-07119b4e87c7
- Updated: 2026-09-01T11:37:05Z

## Investigation State
- **Explored paths**: `lib/providers/auth_provider.dart`, `lib/providers/token_provider.dart`, `lib/providers/session_provider.dart`, `lib/providers/web_socket_provider.dart`, `lib/repositories/auth_repository.dart`, `lib/core/network/web_socket_client.dart`, `lib/core/network/api_client.dart`, `lib/router/app_router.dart`, `lib/core/services/deep_link_service.dart`, `lib/screens/login_screen.dart`, `lib/screens/register_screen.dart`, `lib/screens/two_fa_screen.dart`, `lib/screens/splash_screen.dart`, `lib/screens/onboarding_screen.dart`, `lib/screens/sessions_screen.dart`, `lib/services/e2ee_service.dart`, `test/screens/*`.
- **Key findings**:
  1. Password and username inputs are currently in `LoginScreen` and `RegisterScreen`, transmitting credentials over WS `'login'`.
  2. Transition to PKCE OAuth 2.0 requires replacing `login` with `login_nios_id` WS action (`oauth_access_token` and `device_info`).
  3. OAuth access token is short-lived and discarded after session establishment; local session is stored in `FlutterSecureStorage` under `'auth.session'`.
  4. Cold start requires verifying central session via `GET /id/api/v1/account` (401 purges local session).
  5. Logout requires `POST /id/api/v1/logout` + WS `logout` + storage purge + redirect to `/id/login?next=/web`.
  6. Routing requires consolidating standalone registration/2FA/reset-password screens into the unified Nios ID hub at `/login` and stripping callback query params on return.
- **Unexplored areas**: None for auth and routing scope.

## Key Decisions Made
- Completed comprehensive architectural survey in `auth_architecture_report.md`.
- Completed self-contained 5-component `handoff.md`.

## Artifact Index
- `f:\Niosmess V2\.agents\explorer_auth_survey_1\auth_architecture_report.md` — Detailed technical findings and specification.
- `f:\Niosmess V2\.agents\explorer_auth_survey_1\handoff.md` — 5-component hard handoff report.
