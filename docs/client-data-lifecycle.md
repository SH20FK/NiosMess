# Client data lifecycle and migration

This document describes the compatible client storage changes from the 2026-10-26 audit. Wire encryption, the secret-chat ratchet protocol and server schemas are unchanged by this client work.

## Sessions and account boundaries

The audited inbox, comment and message operations capture account and session identity; late results are rejected after that boundary changes. Logout attempts to persist a non-secret sign-out fence before cleanup. When that write succeeds, startup refuses to restore the old credentials even if their later secure-storage deletion failed. A marker-write failure is itself reported as incomplete cleanup; if both storage mechanisms fail, restart suppression cannot be guaranteed by an unwritten marker. Local auth becomes signed out in finally despite cleanup failures. Logout first awaits background, call and push-handler shutdown. Only afterward does it stop the secret/protocol account services and erase their data and notification history. If a first-stage handler shutdown fails, account services still stop but private data erasure is skipped and incomplete cleanup is reported. Account-specific draft and encrypted-history erasure additionally requires successful secret-coordinator shutdown; general cache cleanup and clearing the session still run in finally. Partial cleanup is reported rather than claimed successful.

## Message persistence

Ordinary outgoing messages commit their local record to the existing encrypted history archive before preparing encryption and contacting the server. Prepared envelopes are checkpointed before the network call. The composer clears only after the local-save callback, and only if its current draft still matches. A disk error preserves the input and prevents the network call. Failed manual retry retains the same local row and local ID until a replacement has been saved.

Known own originals survive ambiguous empty history/edited echoes and failed E2E opening. Successful authenticated decryption is authoritative even when the result is an intentionally empty media caption, as is an explicit plaintext edit with an edit timestamp. Deleted messages/tombstones are not restored by this fallback.

This does not add an ordinary-chat background transport queue or server idempotency. A lost acknowledgement followed by manual retry can still need server reconciliation; exactly-once delivery is not claimed. Secret chats continue using their existing durable journal and queued-delivery service.

## Sender plaintext cache v2

`enc_sender_plaintext_v1` held raw string values. `enc_sender_plaintext_v2` holds AES-GCM-256 envelopes using the existing local message-cache key `niosmess_msg_cache_key_v1` from secure storage. Each record uses a fresh nonce; AAD is `NiosMess/sender-cache/2:<account>_<chat>_<message>`. Bytes are nonce (12), ciphertext, MAC (16), then Base64. This is local-cache encoding, not a new network cryptosystem.

Migration preserves existing account/chat/message keys. The encrypted copy is flushed and decrypted for equality before deleting its legacy source. A failed conversion or a conflicting protected value retains its legacy source for recovery; migration does not overwrite a newer different protected value. Unscoped records can be encrypted under their original unscoped key without being assigned to any account; verified conversion can remove the raw v1 copy while the protected unattributed record remains. Existing readers support retained legacy entries. Unscoped old sender records are attributed to the active account only when an actual history row proves the sender ID. Unknown sources are preserved, never fabricated as that user's messages.

A downgrade cannot read v2 values. It must not be used as a data rollback: preserve the newer storage and keys, and reinstall a compatible client. There is no destructive conversion back to plaintext. Account erase fences delayed writes so logout cannot repopulate removed records. The decrypted sender-original RAM cache is an insertion-order LRU of at most 256 entries; eviction neither deletes disk history nor truncates a message.

## Drafts and optional caches

Ordinary drafts use account-scoped secure storage. The old global `draft.<chat>` format contains no reliable author. Only explicit `draft.owner.<chat>` metadata permits automatic adoption; a key-identity owner does not prove a group draft's author. Unattributed legacy sources remain on disk and are not shown to another account. This can leave an old draft unavailable in the new UI until its ownership is resolved; it is not silently deleted.

Chat lists are stored under account-scoped keys. Public NiosGram caches remove personal reaction, follow and ballot selections, including on legacy reads. Custom emoji pack metadata is optional account-scoped cache data; successful refresh updates it for offline restarts, and late writes from an old account cannot win over a new one.

## Limits

Native secure storage relies on the platform; browser storage cannot protect against compromised same-origin application code. Device compromise, malicious client updates, metadata leakage and the documented first-contact trust tradeoffs remain outside these storage fixes. Physical-device cold-start/FPS measurements and live production-account delivery are separate checks. See the audit verification matrix for execution evidence.
