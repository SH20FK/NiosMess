# Bluetooth fallback (experimental)

Android and Windows can exchange ordinary human-DM text over BLE GATT, using
existing ordinary E2E envelopes. Settings default on; OS permission remains an
explicit user action and the app never enables the radio itself. Turning off E2E
requires first disabling Bluetooth fallback. Groups, bots, secret-chat protocol
and attachments use their existing transports.

Messages are at most 4 KiB UTF-8. Previously verified chat keys and an enrolled
account are required before going offline. Chat metadata is prepared in the
background while online. Offline credentials/chat metadata last at most 72 hours.
No identities are learned from arbitrary relay devices.

The relay queue retains at most 128 signed ciphertext packets / 2 MiB and
4096 replay IDs. It bounds each peer's traffic, requests and parsing. Outer
packets use a device-only Ed25519 signing key, a session-bound server MAC permit,
a 16-bit SHA-256 work stamp and a signed expiry of at most 72 hours. Relays see
routing metadata, not plaintext or private keys. The eight-hop counter is best
effort: a malicious relay can reset it, but cannot renew signed expiry. This is
not an anonymity network or a guarantee of delivery.

Each participant keeps a separate ciphertext backfill queue (up to 256 messages,
up to 30 days). A full outgoing queue rejects a new send instead of silently
losing an accepted message. When online, the server verifies the device signature,
permit, live original session, current account identity, central NiosID status,
membership, blocks and privacy. Existing operation UUID deduplication prevents
copies from multiple relays becoming multiple messages. Original signed send time
is preserved. Expired radio packets can be backfilled only while the origin's
session remains valid; expired/revoked origin sessions cannot write history.

Acknowledgements mean a recipient application decrypted the message, not that a
human read it. Acknowledging one device does not remove ciphertext from relays,
so another enrolled device can still encounter it. There must be a path of nearby
running clients. Powered-off devices, stopped applications, denied permissions,
OS background limits and radio interference can delay or prevent delivery. No
stable direct 200–300 metre link is promised. Local hiding cannot recall copies
already relayed to other devices.

Private account keys and the device signing seed stay in secure storage. The
radio store contains ciphertext and routing metadata only. Plaintext chat history
uses the application's existing encrypted local archive. Account namespaces and
per-login cache bindings prevent a recycled local user ID or another login from
adopting a previous session's offline keys.

The underlying ordinary E2E remains experimental static-account encryption,
without Signal-style forward secrecy/post-compromise security or an independent
cryptographic audit. Unit tests, compiler checks and emulation do not constitute
physical Android/Windows radio-interoperability testing.
