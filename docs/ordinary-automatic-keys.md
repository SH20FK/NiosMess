# Automatic ordinary-chat key maintenance

Ordinary human DMs automatically adopt a new current contact epoch from the
authenticated messenger chat API. A brief «Ключ изменился» subtitle informs the
user without blocking the composer. Historical identity lookups pin immutable
per-epoch public material without rolling the current epoch backwards. Reusing
an existing epoch with different key bytes is rejected. Bluetooth relays cannot
introduce identities or change membership.

The application prepares eligible contacts and relay permits while online. A
temporary network failure preserves a previously verified offline chat context;
an explicit 401/403/404 or an ineligible chat clears it. Cached keys do not extend
the existing 72-hour offline authorization window.

Decryption selects the matching epoch from the saved account key ring. If an
epoch is missing, a bounded background repair reloads local secure storage and
reuses the existing authenticated NiosID device-enrollment path when a valid
login offer is still available. That path can import older epochs from another
active device even when the current epoch is already present. Imported keys
trigger an automatic history retry. A missing key never triggers a reset,
plaintext fallback, signature bypass or acceptance of another account's key.

Pending messages expose a local «Перейти к настройкам чатов» button using the
existing inline-button style. Its route is hardcoded in the client and no bot
callback is sent. Once key material arrives the placeholder and button disappear.

If no trusted device or saved recovery material retains the required private key,
the client cannot recreate it. Ciphertext stays intact instead of being treated
as readable or silently discarded. The existing experimental static-account
protocol still has no Signal-style forward secrecy/post-compromise security or
independent cryptographic audit. Secret chats are unchanged.
