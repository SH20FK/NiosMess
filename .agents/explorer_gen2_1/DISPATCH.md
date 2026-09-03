## 2026-09-01T11:57:49Z
Conduct a comprehensive UI, Routing, and Screen audit of the Flutter codebase in f:\Niosmess V2\pulse_flutter:
1. Inspect all authentication and onboarding screens in `lib/screens/` and `lib/widgets/`:
   - Verify that all legacy username, password, email input fields, and separate registration screens are completely eliminated or replaced with the unified M3 Expressive Auth Hub.
   - Verify M3 Expressive layout: `maxWidth: 480dp` centering on desktop/mobile, Hero Header with NiosMess logo + Nios ID badge, Ecosystem Card with 3 pillars (`Icons.badge_outlined`, `Icons.lock_outline_rounded`, `Icons.shield_outlined`), 56dp Pill Button (`FilledButton.icon` with 28dp radius) labeled «Войти через Nios ID», Secondary action «Создать Nios ID», Legal reader links to `/legal/privacy` and `/legal/terms`.
   - Check for strict compliance with AGENTS.md: zero `Colors.white`/`Colors.black`, only semantic `colorScheme.*` tokens, `.withValues(alpha:)` (no `withOpacity()`), no `dart:io`.
2. Inspect `lib/router/app_router.dart`:
   - Verify route definitions: `/login`, legal routes (`/legal/privacy`, `/legal/terms`, `/legal/tos`, `/legal/consent`), route consolidation (redirecting `/register`, `/verify-email`, `/2fa`, `/reset-password` to `/login`).
   - Verify address bar query parameter interception and sanitization (`code`, `state`, `error`).
3. Check existing screen tests in `test/screens/`, `test/onboarding_screens_test.dart`, etc., and identify any broken or obsolete test files that expect legacy text fields.
