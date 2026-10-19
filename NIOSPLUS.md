# NiosPlus purchase and activation

The native client reads `/api/plus/catalog` using its NiosID access token. The server selects either `standard` or `ru` from the authoritative NiosID billing region and returns matching marketplace links. Product links are configured on the server, not embedded in the client. A missing listing disables purchase for that duration.

The client shows payment-gateway commission notice before opening FunPay. The checkout displays the final total. Explicit consent is required before the purchase handoff and before sending a SHA-256 device hash for activation.

Marketplace stock contains separate single-use links for each duration and region. Codes remain in the URL fragment. The application previews the subscription and target account before redeeming; the server rejects a wrong-region key and a changed account. Preview and redemption are authenticated server operations, not client-side price checks.

Android, Windows and Linux currently implement the device hash. This is not hardware attestation. iOS/macOS identity support remains to be implemented and verified before selling activation for these clients. Native builds and physical-device deep links must be checked in release CI; local changes alone do not update installed applications.

User interface: plain tariff rows, inline link entry and account confirmation. Use the existing theme and typography, SVG controls, accessible focus and narrow-screen layouts. No decorative hero, gradient panels or emoji controls.

Tests: HTTPS/native activation-link validation, foreign-host rejection, regional catalog display, payment-commission notice, mandatory consent and inline invalid-link handling. Server checks separately cover region mismatch, single-use redemption, account confirmation and the 14-day promotion restrictions.
