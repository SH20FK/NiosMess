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
256-bit recovery secret. The recovery secret is never included in server requests.
The app prompts users to save it in their password manager. Restoring validates
AES-GCM and reconstructed public keys before persisting private material.

An existing device can transfer keys to a new device via a 10-minute connection
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
lost acknowledgements cannot destroy the new private keys. Contacts must verify
changed identities before trusting them.

## Trust and limits

- Contact keys use trust on first use plus persisted pins. Changed epochs require
  explicit out-of-band fingerprint comparison; changed keys within an existing
  epoch are rejected. Fingerprints can be compared in the settings screen.
- A malicious directory at the first contact can substitute keys unless users
  compare fingerprints. This version has no key transparency directory.
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
The ordinary realtime provider is tested with real encryption on its send, own
acknowledgement and incoming push paths. Legacy realtime tests isolate encryption
to retain their original history/lifecycle scope.
