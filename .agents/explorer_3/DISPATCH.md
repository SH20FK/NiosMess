## 2026-08-31T19:09:12Z
Task:
1. Locate and thoroughly inspect `two_fa_screen.dart`, `verify_email_screen.dart`, `reset_password_request_screen.dart`, `reset_password_confirm_screen.dart`, OTP widgets, pin input components, and resend timer logic in `pulse_flutter/lib/`.
2. Inspect localization files (`pulse_flutter/lib/l10n/app_en.arb`, `app_ru.arb`) and theme tokens (`pulse_flutter/lib/core/theme/`).
3. Inspect any existing unit/widget/integration tests related to verification and password reset in `pulse_flutter/test/`.
4. Analyze what is needed to implement R3 from `ORIGINAL_REQUEST.md`:
   - 6-digit OTP code input boxes with animated squircle focus states, auto-fill support, and auto-submit on completion.
   - Dynamic resend countdown timer with animated progress ring and pulse haptics on code expiry.
   - Password reset request and confirmation forms with M3 20dp/28dp squircle geometry and strong feedback states.
   - Strict adherence to AGENTS.md rules (no `Colors.white`/`Colors.black`, no `withOpacity()`, Riverpod 3.x, 100% `context.l10n`).
5. Identify existing OTP inputs, countdown timers, clipboard/autofill hooks, missing l10n strings, and necessary test coverage.
6. Write your complete handoff report to `f:\Niosmess V2\.agents\explorer_3\handoff.md`.
7. Send a message to your parent when done referencing your handoff file.
