# NiosStream version 1

Finite files, AES-256-GCM, authenticated independent segments. This is an
application format using the `cryptography` implementation of standard AEAD,
not a new cryptographic primitive. No plaintext is returned before full segment
authentication succeeds. A media decoder must separately support its container
and requested seek position.

## Trust and keys

`prepareFile` generates a fresh 256-bit key, random 128-bit lowercase-hex object
identifier, and random 64-bit nonce prefix for every object. The key is never
stored in the manifest, download metadata or ciphertext directory. Persist it in
an account-scoped encrypted journal/OS key store. Convey the manifest SHA-256
and key over an independently authenticated, encrypted channel. A manifest and
its hash obtained from the same untrusted server are not authentication.

Use `NiosStreamManifest.fromJson(json, expectedHash: trustedHash)` to load external
metadata. Missing/extra fields, unsupported versions/algorithms, malformed
numbers and out-of-bounds lengths are rejected.

## Manifest encoding

Canonical bytes are UTF-8 JSON with exactly these keys, in this order, no spaces:

1. `version`: integer `1`;
2. `algorithm`: string `A256GCM`;
3. `objectId`: 32 lowercase hexadecimal characters;
4. `plaintextLength`: integer in `0..2^40`;
5. `segmentSize`: integer in `1..1048576`;
6. `noncePrefix`: standard padded base64 of eight bytes;
7. `segmentHashes`: ordered lowercase SHA-256 hex hashes of ciphertext segments.

The manifest identity is lowercase hex SHA-256 of those canonical bytes. At most
1,048,576 segments are allowed. Empty objects contain no segments and have a
zero-byte ciphertext file. Hashes, lengths and progress are public metadata;
file names and keys are absent. Manifest memory is proportional to the segment
count; file-content processing is bounded by one segment.

## Segments

Segment count: `ceil(plaintextLength / segmentSize)`. The zero-based index is
encoded as four unsigned big-endian bytes and appended to the nonce prefix,
forming the 12-byte GCM nonce. Each segment uses the object's unique key.

Associated data is canonical UTF-8 compact JSON of this array:

```text
["NiosStream",1,"A256GCM",objectId,plaintextLength,segmentSize,index,segmentPlaintextLength]
```

The physical segment is `ciphertext || 16-byte GCM tag`. `content.nsc` concatenates
those segments without a header. Segment offset is `index * (segmentSize + 16)`;
the final segment may be shorter. SHA-256 is checked against the trusted
manifest before AEAD verification. Position/object/AAD tampering and wrong keys
fail authentication. Never generate fresh ciphertext for a retry: transfer the
same prepared file.

## Publication and resume

Preparation reads/writes in blocks of at most 64 KiB; the AEAD working segment
is at most 1 MiB. Ciphertext is flushed and closed, the canonical manifest is
written through a flushed temporary file, then the staging directory is renamed
to its final object identifier. A ready return means this publication completed.
Cancelled/failed preparation removes its staging directory.

Downloads store ciphertext in a sparse `content.nsc` and progress in atomically
replaced `download.json`. Before a verified segment is written, metadata records
its pending index. Ciphertext is flushed before the verified bitmap bit and
cleared pending index are committed. Reopening authenticates every claimed
segment and the pending range, detecting corruption and recovering the
flush-before-bitmap process-crash boundary. Missing sparse ranges are not read.
A wrong encryption key fails open without replacing the stored bitmap.

One instance serializes reads, writes and metadata commits. Duplicate instances
within an isolate are rejected; an OS advisory lock protects other processes.
The application must have one owner per cache across its isolates. Durability
covers process termination and OS file flushing; Dart does not expose a portable
parent-directory fsync, so rename metadata persistence after sudden power loss
is not claimed.

`readRange(start, endExclusive)` returns at most 8 MiB per call. Larger consumers
must iterate ranges. A segment is always authenticated in full even when a
caller requests a few bytes. Plaintext remains in memory and is never placed in
shared disk/media caches. Consumers own returned buffers; discard them promptly.
Close downloads before removing an account directory.

The cancellation token passed to `open` owns the entire download lifetime.
Cancelling that token or calling `close()` synchronously aborts active sources
and cancels queued work, even when a later read did not repeat the owner token.
Per-operation cancellation is linked to that lifetime and detaches its listeners
after completion; it does not cancel other operations. A failed/cancelled range
read clears its partially assembled plaintext buffer before rethrowing. Closing
waits for cancelled work to finish before releasing file handles and the lock.

## Sources

`StreamCiphertextSource` supplies an exclusive-end ciphertext range. Files and
HTTP support a maximum 1 MiB + 16 byte range. HTTP requires HTTPS; a caller may
explicitly opt into HTTP for `localhost`, `127.0.0.1` or `::1` only. User-info
credentials, fragments, empty hosts and invalid allocation/time bounds are
rejected. HTTP accepts only exact `206`,
matching `Content-Range` and total object length, optional matching Content-Length,
identity encoding, and an exact bounded body. Redirects and whole-file `200`
fallback are rejected. Cancellation closes the per-request HTTP client.

Multiple sources are tried in order. Every response is validated against the
same trusted manifest and AEAD key, preventing identity substitution during
failover. Integrity failures do not publish a ready range. No retry path sends
or caches an unencrypted original.

## Immutable HTTPS publication

`HttpCiphertextBlobStore(baseUri:, bearerToken:)` publishes prepared ciphertext
without reading the plaintext source. One file handle reads at most one segment
at a time and verifies its trusted SHA-256 before that segment reaches the HTTP
sink. A different same-sized file or damaged segment is rejected locally; a disk
producer error aborts the pending HTTP exchange immediately. Authentication is an explicit bearer token
over verified HTTPS. The token is never forwarded through redirects. Local
tools/tests must explicitly set `allowInsecureLoopback: true` to use plain HTTP.
Every request owns its HTTP client, abort trigger and deadline; cancellation
aborts an active upload/download without affecting another operation.

The version 1 endpoint contract is:

1. `HEAD /v1/blobs/{trustedManifestHash}` returns `404`, or `200` with matching
   `X-Nios-Manifest-Hash` and decimal `X-Nios-Ciphertext-Length` receipt headers.
2. `PUT /v1/manifests/{hash}` sends the canonical public manifest; `200`/`201`
   acknowledges an identical existing/new immutable manifest.
3. `PUT /v1/blobs/{hash}` sends the exact prepared ciphertext and length. The
   server verifies every segment SHA-256 before flushing and atomically renaming
   the staging file. `200`/`201` includes the same receipt headers as HEAD.
4. `GET /v1/blobs/{hash}` requires one explicit closed byte range no larger than
   a ciphertext segment. It returns exact `206`, length and `Content-Range`;
   absent/malformed/multiple/oversized ranges return `416`.

HEAD reuse does not need the original local file. Conflicting/corrupt uploads
cannot overwrite an immutable identity, and do not produce a success receipt.
Receipt bodies are limited to 4096 bytes. A server's receipt is its durable-store
claim, not proof of disk possession or a substitute for receiver AEAD validation.
Manifest/key delivery still belongs to a separately authenticated E2EE channel.

`CiphertextBlobServer.bind` is an actual loopback reference implementation with
optional `securityContext:` for HTTPS. It has exclusive directory ownership,
bounded requests, full equal-length token comparison without early exit, serialized
publication per object, flushed staging files, and cleanup of its own unfinished
staging files after process restart. It never promotes an incomplete upload.
The directory lock is OS advisory; as with download caches, the embedding
application must use one owner across Dart isolates. Closing the server closes
connections/handlers before releasing the directory. This helper does not
provision accounts, deploy public TLS, supply retention/quota accounting or add a
production backend handler. Those integrations require separate deployment work.

Tests exercise verified loopback TLS, exact ranges, idempotent HEAD/reopen,
corrupt uploads, auth/redirect rejection, bounded receipts, in-flight cancellation,
source failover and actual killed-process staging recovery. Test TLS identities
are public fixtures and must never be used for deployment.
