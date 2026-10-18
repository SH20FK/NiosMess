# Nios SDK

Flutter-independent Dart building blocks for durable encrypted operations,
authenticated file ranges, device-key history and three-of-five storage.
The native OpenMLS and Iroh adapters live in separate packages. These packages
implement the five proposed technical directions **#1, #2, #5, #6 and #12**.

## Packages and imports

| Direction | Public API | Purpose |
| --- | --- | --- |
| #1 | `package:nios_sdk/link.dart` | Encrypted persistent queue, ordered reducer, deduplication, device-authenticated ACKs, HTTP mailbox transport |
| #2 | `package:nios_sdk/stream.dart` | Independently authenticated file segments, resumable ciphertext cache, strict HTTP Range, immutable blob upload |
| #2 media | `package:nios_sdk/media.dart` | Loopback capability URL for a native range-capable player; plaintext is authenticated in RAM |
| #5 | `package:nios_mls/nios_mls.dart` | Genuine RFC 9420 group membership, epochs and encrypted messages through native OpenMLS |
| #6 | `package:nios_sdk/trust.dart` | Account-authorized device bundles, RFC 6962 proofs, signed checkpoints and persistent witnesses |
| #12 | `package:nios_sdk/distributed.dart` | Systematic 3+2 Reed–Solomon coding, verified shares, recovery and keyless repair |
| #1 native | `package:nios_iroh/nios_iroh.dart` | Pinned-identity Iroh QUIC transport and encrypted persistent endpoint identity |

`package:nios_sdk/nios_sdk.dart` exports the Dart modules together. Dart sources
use `universal_io` and do not depend on Flutter UI. File-backed journals, native
media gateways and this MLS durability adapter require a native filesystem;
browser qualification is not implied by Flutter independence.

## Install and test

```sh
cd packages/nios_sdk
dart pub get
dart analyze --fatal-infos
dart test
```

From this directory, run the complete native integration:

```sh
cd ../nios_lab
dart pub get
dart run iroh_quic:setup
dart analyze --fatal-infos
dart test
dart run bin/nios_lab.dart
```

The setup verifies the upstream publisher's native Iroh signature. OpenMLS 3.2.1
uses its dependency build hook and release SHA-256 verification. Native binaries
are downloaded/build artifacts and must be bundled for the target platform by
its distributor. A Windows setup cache does not install Android libraries into
an APK. Both native adapters have been exercised on Windows x64; the CI matrix
and real mobile/device scenarios remain separate verification surfaces.

The lab uses genuine native cryptography, QUIC endpoints, bearer-authenticated
HTTP ranges and five loopback shard servers. It discards an ACK, reopens the
sender, rejects a forged device ACK despite possession of a group encryption
key, stops two shard servers, repairs a share and verifies the restored bytes.
See [the lab contract](../nios_lab/README.md) for exact checks and diagnostics.

## #1 — Durable Link

`DurableSession.open` owns an encrypted account/device Hive journal. Supply its
32-byte `journalKey` from platform secure storage, a cipher with authenticated
peer identities, one or more `LinkTransport`s and a deterministic reducer.

```dart
final session = await DurableSession.open(
  directory: privateAccountDirectory,
  accountId: accountId,
  deviceId: deviceId,
  journalKey: keyFromSecureStorage,
  cipher: authenticatedDeviceCipher,
  transports: configuredTransports,
  autoStart: false,
  reducer: (previous, operation) => {
    'applied': (previous['applied'] as int? ?? 0) + 1,
    'lastOperation': operation.context.operationId,
  },
);

final saved = await session.enqueue(
  peerId: peerDeviceId,
  sessionId: negotiatedSessionId,
  operationId: persistentOperationId,
  payload: {'kind': 'example', 'value': 7},
);
// saved includes localDurable only after the journal write and flush.
session.start();
```

Enqueue persists the payload before trying to encrypt. Missing peer keys pause
preparation without discarding the accepted local operation. Once prepared, the
same envelope bytes are reused on every retry and after reopen. Reusing an
operation ID for different content, destination or session is rejected.

Delivery facts are independent: `localDurable`, `mailboxStored`,
`recipientStored`, `recipientApplied`, `userRead`. A mailbox or QUIC write is
insufficient to claim recipient application. Receiver state, the deduplication
record and its prepared ACK are journaled together. Reordered operations wait
for preceding sequence numbers. Reducers must have no external side effects;
database writes, payments or notifications outside this journal need their own
transaction/idempotency integration. This is scoped local application-once
behavior while its journal is retained, rather than a global exactly-once
network guarantee.

`savedPayload` supplies the local outgoing payload; the sender need not decrypt
a server echo to display its own text. `events`, `incoming`, `operations`,
`applicationState`, `retryNow`, `markRead` and `close` expose the lifecycle.
`close(wipe: true)` removes the Link journal and key commitment; the account
owner must also remove attachments, native state and secure-store keys.
The reference journal retains acknowledged operation records and restores them
into memory. Long-running deployments need an explicitly designed retention/
checkpoint protocol; silently deleting deduplication history would weaken the
application-once boundary. No bounded-history compaction is claimed here.

`AesGcmEnvelopeCipher` requires independently provisioned pairwise keys.
`SignedEnvelopeCipher` adds an outer Ed25519 signature over the exact ciphertext
and context. Use device verification keys from authenticated enrollment, such
as the verified transparency bundle below. A shared MLS exporter authenticates
membership in an epoch, not the unique device that originated an operation or
ACK. Stateful ratchets must atomically publish their own state and ciphertext;
the stateless envelope adapter does not provide that transaction for them.

`HttpMailboxTransport` requires HTTPS unless insecure loopback is explicitly
enabled. The development mailbox in `example/mailbox_server.dart` requires:

- `NIOS_MAILBOX_KEY`: base64 encoding of a fresh 32-byte storage key;
- `NIOS_MAILBOX_TOKENS`: JSON mapping each device ID to a distinct random token
  containing at least 24 characters;
- optional `NIOS_MAILBOX_DIRECTORY` and `NIOS_MAILBOX_PORT`.

Start it with `dart run example/mailbox_server.dart` after supplying those
values through the environment. Credentials are never printed. It binds
loopback and stores opaque envelopes; authentication/account enrollment,
production quotas, key distribution and public TLS deployment need an owner.

## #2 — NiosStream and native media

`NiosStream.prepareFile(inputPath:, outputDirectory:, segmentSize:)` generates
a fresh key, immutable manifest and `content.nsc`. Contents are encrypted with
AES-256-GCM in independent segments, each at most 1 MiB. `PreparedStreamObject`
exposes `manifest`, `key`, `directory`, `ciphertextPath` and `ciphertextSource`.
Persist the file key in the encrypted account journal before acknowledging
attachment acceptance. Public manifests contain no file key, filename or caption.

Use `HttpCiphertextBlobStore.ensurePublished` to upload the exact ciphertext;
`sourceFor(manifest)` produces a strict authenticated HTTP Range source. Publish
the blob before delivering its metadata envelope, or use the Flutter account
adapter's transport publication barrier. Keep retryable encrypted files until
delivery is safely complete. A publication receipt is the server's durable-store
claim; the receiver still authenticates every segment.

`NiosStreamManifest.fromJson(json, expectedHash: trustedHash)` requires a hash
obtained through an independently authenticated channel. A manifest and its
claimed hash fetched from the same untrusted server are insufficient. Deliver
the manifest hash and file key inside an authenticated Link/MLS payload.

```dart
final download = await NiosStreamDownload.open(
  directory: privateAccountCache,
  manifest: authenticatedManifest,
  key: fileKeyFromEncryptedMessage,
  sources: configuredCiphertextSources,
);
final bytes = await download.readRange(10000, 20000); // exclusive end
// Consume promptly; this caller owns the plaintext buffer.
bytes.fillRange(0, bytes.length, 0);
await download.close();
```

Only ciphertext and verified-progress metadata are written to this cache.
Reopen reauthenticates claimed segments and interrupted writes. Sources can
change while the trusted object identity stays fixed. Each returned range is
bounded to 8 MiB; large consumers iterate ranges. A modified tag, wrong key,
wrong range or oversized HTTP reply fails closed. Cancellation is explicit.

`AuthenticatedMediaGateway.bind(download:, mimeType:)` exposes an unguessable
loopback URL with byte ranges and `no-store`; it does not create a plaintext
media file. Native decoders must support the particular container and seek
position. Third-party player caches and bytes already consumed by a recipient
are outside the gateway's control. Close the gateway before its download and
account storage. See [the versioned format and HTTP contract](lib/src/stream/FORMAT.md).

## #5 — MLS groups

The separate [nios_mls package](../nios_mls/README.md) uses native Rust OpenMLS,
MLS 1.0 suite 0x0001, real KeyPackages, Welcome, membership commits and exporter.
Every other member's credential/signature key must pass an application-provided
authorizer. Removing a member prevents reading future epochs; already obtained
history remains available to that member.

Native SQLCipher state and the encrypted application journal are published
using a closed-database copy plus a single Hive generation-pointer/result
record. Ciphertext and ratchet state survive the tested process-interruption
boundaries together. The reference adapter copies O(database size) per mutation;
high-throughput deployments should integrate the application journal into the
native database transaction. Concurrent membership commits require application
sequencing/rebasing; the transport alone does not resolve them. A separate web
adapter with equivalent durability has not been implemented.

## #6 — Key transparency

`KeyTransparencyClient.open` takes a pinned log key, independent witness keys,
quorum and `TransparencyStateStore`. First pin the account identity using
`pinAccount` after independent enrollment/verification. `apply` verifies signed
checkpoints, witness quorum, inclusion proofs, account signatures and continuous
per-account revisions, then atomically saves the next snapshot.

`DeviceKeyStatement` v1 authorizes an MLS `deviceKey`. Optional `linkSigningKey`
and `transportEndpointKey` must occur together: version 2 signs all three keys
under the account identity. A v1 statement retains its original signing bytes.
`TrustedDeviceKey` exposes the verified bundle and revocation state; tombstones
prevent a reused device ID from silently replacing a known key. A key change
requires an explicit application enrollment decision, not automatic trust reset.

`KeyTransparencyWitness.approve` validates append-only growth against its own
persisted checkpoint before exposing a signature. Operate witnesses in
independent administrative/failure domains and arrange checkpoint gossip or
monitoring. Several names/keys on one host do not supply independence. An
append-only proof establishes a history; it does not prove a person's identity
or that the server supplied every latest account update. Freshness and withholding
detection require deployment policy and monitoring.

`HiveTransparencyStateStore` encrypts atomic snapshots. Account/client owners
must use exclusive boxes. Call `await client.close()` to fence new mutations and
drain admitted calls, then close its externally owned store. Wrong storage keys
are rejected before Hive recovery can modify a journal.

## #12 — Distributed ciphertext storage

`DistributedStore(nodes:, spoolDirectory:)` requires five distinct configured
failure-domain labels. `putCiphertext` creates a `DistributedManifest` and five
`ShareReceipt`s; `recoverCiphertext` needs any three verified share indices.
`repairShare(manifest, index, replacement)` rebuilds a share without the file key.
`delete` writes node deletion tombstones. Authentication covers object identity,
share index and stripe position through manifest-pinned Merkle roots.

The codec is systematic Vandermonde Reed–Solomon, GF(256), polynomial 0x11d,
three data and two parity shares. Storage is roughly 5/3 of ciphertext plus
padding and metadata. It is erasure coding, so callers must encrypt before
distribution and retain the encryption key and authenticated manifest separately.
The key and manifest are themselves critical recovery material.

`DirectoryShardNode` provides flushed disk storage; `HttpShardNode` accesses
bearer-authenticated HTTPS nodes. `ShardNodeServer.bind` is the loopback reference
server. Deploy storage domains independently: labels cannot prove physical
separation or prevent a node from falsely claiming disk possession. The v1
manifest bounds stripe count to 4096 and blocks to 256 KiB, limiting one object
to approximately 3 GiB. Recovery/repair stage ciphertext on disk and validate
the final hash before publication.

## Deployment and durability boundaries

The packages and local reference services are executable implementations. Their
presence does not negotiate these protocols with installed older clients or add
production server handlers. NiosMess integration owns keys and shutdown per
account and remains explicitly configured/negotiated. Existing chat protocols
continue through their current paths.

Production mailbox/blob endpoints, independent witnesses, public Iroh relays,
five storage domains, account/device enrollment, quotas, monitoring and mobile
background behavior need deployment integration and qualification. **Changing
the existing NiosMess backend or deploying these services still requires the
user's approval. No production backend modification is part of the local lab.**

Flush/atomic-publication tests cover process termination. Portable Dart APIs do
not offer parent-directory fsync; sudden power-loss persistence of renamed
directory entries is not promised. Account deletion must stop all producers,
close handles and remove account data plus secure-store keys. File deletion
does not imply physical erasure from SSD snapshots or backups. Runtime/report
diagnostics should contain states/codes/counts, never payloads, file keys or tokens.
