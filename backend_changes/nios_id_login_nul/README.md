# NiosID profile provisioning: NUL-safe technical password

New NiosID-linked messenger profiles used `bcrypt.hashpw(secrets.token_bytes(48), ...)`. The deployed bcrypt rejects NUL bytes, so the random input intermittently broke initial OAuth login with `password may not contain NUL bytes`.

The patch encodes the same 48 random bytes as URL-safe ASCII before hashing (64 bytes, below bcrypt's 72-byte input limit). No account credentials, OAuth verification, linking policy or existing hashes change. Profile creation is still gated by verified active NiosID claims; email collisions are not auto-linked.

`check_provisioning.py` runs against the host app imports and an in-memory synthetic database. It deterministically reproduces the old failure with zero bytes, then tests new provisioning, profile reuse, independent sessions, invalid tokens, email collisions and ineligible claims. It uses no production accounts.

Deployed as `/opt/niosmess/releases/login-nul-20261020T183938Z`, with backup and tested SQLite snapshot restore under `/var/backups/nios-ai-plus/login-nul-20261020T183938Z`. Rollback switches the service symlink to the previous source release; no database rollback is required.
