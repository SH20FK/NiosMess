## 2026-09-01T11:32:09Z
Task:
Read and mine all exact technical requirements, protocols, and constraints from:
1. f:\Niosmess V2\NIOSMESS_FRONTEND_LOGIN.md
2. f:\Niosmess V2\.agents\ORIGINAL_REQUEST.md
3. f:\Niosmess V2\AGENTS.md

Specifically detail:
- OAuth 2.0 PKCE S256 flow (verifier, challenge, state, nonce, entropy, encoding rules, redirect URIs, client_id)
- HTTP endpoints: GET /id/api/v1/account, POST /oauth/token, POST /id/api/v1/logout, error codes and payloads
- WebSocket protocol: action login_nios_id on wss://ni-os.ru/ws, payload structure, returned session structure, E2EE setup trigger
- Ephemeral vs persistent storage constraints (sessionStorage on Web, secure storage/in-memory, strictly no persistent oauth_access_token)
- Cold-start session verification and clean logout lifecycle
- Error cases (consent rejection / access_denied, invalid_grant, network error vs 401)
- UI and Legal requirements (/legal/privacy, /legal/terms)

Write your comprehensive findings to f:\Niosmess V2\.agents\spec_miner_survey_1\spec_report.md and create a self-contained handoff.md in your directory. When finished, send a message to your parent with your summary and file paths.
