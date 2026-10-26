# Ordinary personal chat E2E — experimental v1

Scope: new messages, edits, stickers and files in human-to-human ordinary direct
chats. Groups, public channels, bot conversations and old readable history retain
their existing behavior. The client setting defaults to enabled; either enrolled
participant requiring E2E prevents plaintext sends. Clients without the new
protocol must update; no automatic plaintext downgrade is permitted.

This is an original application envelope using the existing `cryptography`
package, not Signal Protocol or copied libsignal code. It has not received an
independent cryptographic audit. Do not describe it as Signal-equivalent.

## Keys and delivery

Each account has random X25519 and Ed25519 seeds scoped to the account and a
random identity epoch. Private seeds stay in OS-backed FlutterSecureStorage.
Public identities are registered with proof of possession and immutable within
an epoch. A partial unique index permits only one active epoch per account.

Each message gets a random 256-bit AES-GCM content key and ephemeral X25519 key.
The content key is independently wrapped for sender and recipient identities
with X25519/HKDF-SHA256/AES-GCM. The full envelope is signed with Ed25519.
Authenticated metadata binds chat, sender, identity epoch, operation UUID, reply,
edit target and ephemeral key. Sender and recipient can independently decrypt
stored ciphertext without any device being online. Fresh nonces are generated
by the crypto library. A durable server operation ledger prevents retry duplicates.

Files use the existing per-file AES-256-GCM implementation before upload. Their
keys and original descriptors are only carried inside message ciphertext. A
protected send rejects an upload without a client-side file key. Server wrapping
is omitted for these already-encrypted upload bytes, avoiding double encryption
that would break E2E downloads. Caption edits retain the encrypted file key.

## Device connection and loss

The server stores a recovery backup encrypted with an independently generated
256-bit recovery secret. The recovery secret is never sent to the server in plaintext.
The app prompts users to save it in their password manager. Restoring validates
AES-GCM and reconstructed public keys before persisting private material.

From 3.103.1 an active device automatically transfers keys after a fresh confirmed
NiosID login. Before the login starts, the new device stores an ephemeral X25519
private key locally and binds its public key, random salt and request UUID in the
OIDC nonce. NiosID signs that exact nonce into its RS256 ID token only after the
existing email/CAPTCHA/consent checks. The messenger relay cannot substitute an
arbitrary new target key using an existing messenger access token.

The source independently verifies the ID token against the fixed NiosID JWKS
endpoint, own pinned subject, first-party client ID, target binding and ten-minute
freshness window. Keys, recovery secret and retained older epochs travel only in
an authenticated encrypted packet for the target device, signed by the current
account identity. The recipient verifies the signature and encrypted recovery
backup before saving anything. Delivery is tied to the requesting session;
revocation/reset/expiry prevent retrieval, and the first valid source response
wins. Push events contain no key packet; reconnect/polling recover lost wakeups.

This explicitly trusts NiosID to authorize device enrollment. A compromised
NiosID authority or account login can authorize a foreign device while an active
source is online. The owner accepted this tradeoff for unattended synchronization.
Both devices need an updated client; background/suspended/offline clients cannot
serve keys. After successful transfer, history remains readable with the source
offline. Without an available source, use the saved recovery secret or a fresh
login when a source becomes active; login by itself cannot decrypt history.

As a fallback, an existing device can transfer keys via a 10-minute connection
code. The code contains an ephemeral target key and an independent 256-bit
out-of-band secret. The server sees only the public target key and request UUID.
The transfer uses authenticated encryption whose derivation also requires the
out-of-band secret; merely controlling the relay or knowing the target public key
cannot forge a transfer. Requests are account-bound, signed by the current account
identity, expire and are bounded to five pending requests per account.

With neither a device nor recovery secret, NiosID still restores account access.
Explicit key reset requires a login less than 15 minutes old, revokes other
sessions, preserves old public epochs, and makes old encrypted history unavailable
without old private keys. A new identity is staged durably before publication so
lost acknowledgements cannot destroy the new private keys. Ordinary chats adopt a
new current contact epoch from the authenticated messenger chat API and show a
key-change notice. Users can compare fingerprints out of band; the composer does
not require that comparison. See [automatic key maintenance](ordinary-automatic-keys.md).

## Trust and limits

- Contact keys use trust on first use plus persisted immutable per-epoch pins.
  Different key bytes within an existing epoch are rejected. A new current epoch
  from the authenticated messenger chat API is adopted automatically, with a
  nonblocking key-change notice. Historical lookups cannot move the current epoch
  backwards. Fingerprints can optionally be compared in settings.
- This policy trusts the authenticated directory to introduce new epochs. A
  malicious directory can substitute first-contact keys or introduce a different
  new epoch unless users independently compare fingerprints. This version has no
  key transparency directory. Device-bound secret chats use a separate
  identity-change confirmation policy, unchanged by this audit.
- Static account recipient keys do not provide forward secrecy or post-compromise
  security. A stolen account key can decrypt retained ciphertext for its epoch.
- Confirmed devices share account identity keys. Removing a session prevents future
  API access but cannot erase copied keys; rotate identities to exclude a stolen
  device from future content. Already decrypted/copied content cannot be revoked.
- The server still sees account/chat identifiers, routing, timestamps, ciphertext
  sizes and upload metadata. E2E does not hide traffic metadata.
- Server text search cannot search new ciphertext. Existing local plaintext caches
  remain protected by the app's existing encrypted cache; device compromise and
  malicious application updates are outside the server-storage threat model.
- Calling server AI or sharing text for moderation necessarily discloses the
  explicitly shared text to that endpoint. No message keys may be included.

## Validation

Python `cryptography` vectors are consumed by Dart tests; all fixed fixture keys
are explicitly synthetic. Tests cover both message directions, offline devices,
recovery, corrupt packets, account/chat/reply/edit binding, fresh nonces, pairing
secrets, registry authorization, reset, encrypted attachments and retry dedup.
Automatic enrollment tests also exercise the actual Dart RS256 verifier against
Python-signed synthetic fixtures, cross-account/expired/tampered logins, encrypted
transfer between separate device stores, source-offline history and logout races.
The ordinary realtime provider is tested with real encryption on its send, own
acknowledgement and incoming push paths. Legacy realtime tests isolate encryption
to retain their original history/lifecycle scope.
