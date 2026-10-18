# Nios MLS

A native Dart SDK for real RFC 9420 groups. The cryptographic implementation is
Rust **OpenMLS**, accessed through the third-party `openmls` Dart package pinned
to **3.2.1**. No homemade group cipher or MLS-shaped mock is used.

## Supported and verified

`dart pub get`, `dart analyze --fatal-infos`, and `dart test` work without a Rust
toolchain on Windows x64. The dependency's native build hook downloads its
prebuilt library and verifies the release's SHA-256 checksum. Android/iOS/macOS/
Linux artifacts are supplied upstream; the same native tests can run in CI on
those hosts. Actual mobile device qualification remains separate.

The adapter explicitly advertises only MLS 1.0 ciphersuite **0x0001**
(X25519/AES-128-GCM/SHA-256/Ed25519). Upstream experimental PQ capabilities are
not accidentally advertised.

The COW filesystem adapter is native-only. The dependency has a Web engine, but
it cannot export an atomic state snapshot together with this Dart journal;
silently weakening the crash guarantee for Web would be incorrect.

## API

```dart
final client = await NiosMlsClient.open(
  path: privateAccountDeviceDirectory,
  storageKey: keyFromPlatformSecureStorage, // random 32 bytes
  accountId: accountId,
  deviceId: deviceId,
  authorizeDevice: (account, device, signingKey) async {
    // Pin/account-authorize this exact device key, e.g. using key transparency.
    return trustedDeviceDirectory.authorizes(account, device, signingKey);
  },
);

// Publish the device signingPublicKey through authenticated enrollment.
final package = await client.createKeyPackage();
await client.createGroup(groupId: groupId);
final invitation = await client.addDevices(
  operationId: 'enroll-bob-device-1',
  groupId: groupId,
  keyPackages: [bobsPackage],
);
// Deliver invitation.message to existing members and invitation.welcome to Bob.
// Bob calls join(welcome: invitation.welcome!).

final queued = await client.encrypt(
  operationId: 'stable-application-operation-id',
  groupId: groupId,
  plaintext: payload,
);
// Send queued.message through a durable ordered transport. Retry returns exactly
// these bytes; call acknowledge only after the transport's durable receipt.
await client.close();
```

`members`, `epoch`, `isActive`, `removeDevices`, `receive`, `pendingOperations`,
`deriveApplicationKey` and `acknowledge` provide the remaining lifecycle. Group actions require ordered
commit delivery; concurrent changes need application-level conflict sequencing
or rebasing and must not silently overwrite another commit.

Every new member's credential and signing key is passed to `authorizeDevice`,
including the Welcome's creator. A credential declares account/device identifiers;
it does not prove a human identity by itself. Revoked members can be removed even
when the authorizer no longer approves their old key. Application messages remain
blocked while an unauthorized member remains in the group.
If the catalog revocation arrives first, a remaining device can still process
an authorized member's removal commit that eliminates all unauthorized members.
The old sender credential and resulting membership are checked on a private
generation before publication; ordinary application/proposal messages remain
blocked during that transition. Failed checks preserve the committed epoch.

`deriveApplicationKey` uses the RFC 9420 exporter with an application label and
context, after checking group authorization. Its result is known to all members
of that epoch. Use separate account-authorized device signatures or genuinely
pairwise keys to authenticate Link operations and ACKs. A group exporter alone
does not identify a particular member. Session IDs and retained queue keys must
include the epoch; changing membership must not reinterpret old queued bytes
under a different key. The five-module `../nios_lab` executable demonstrates
verified key bundles, SignedEnvelopeCipher and real Iroh transport together.

## Durability

OpenMLS has its own SQLCipher transaction. Combining that with an unrelated Dart
journal cannot be made atomic by awaiting two writes. This adapter instead:

1. Copies the last **closed**, encrypted SQLCipher database to a new generation.
2. Runs the OpenMLS operation against the new generation, then closes and flushes it.
3. Publishes the new generation pointer, ciphertext or decrypted result, and
   idempotency record in **one encrypted Hive record** before returning anything.
4. Deletes obsolete generations after publication. Reopen discards unreferenced
   generations left by interruption.

A pre-publication failure preserves the old ratchet. A post-publication failure
recovers the exact saved result after reopen. An uncertain journal write poisons
the current instance until reopen and keeps both generations. The `faultHook`
allows deterministic tests at `native_state_closed` and `journal_published`.
`close()` synchronously fences new mutations, drains an already running native
transaction, and releases the journal only afterward. Repeated closes share the
same completion future. An operation that already reached its private native
generation may finish durable publication; its ciphertext remains recoverable.

This correctness-first adapter copies O(database size) per mutation and retains
acknowledged operation records for idempotency. Production throughput and bounded
history retention require moving the application journal into the Rust SQL
transaction or an explicitly designed compaction/checkpoint protocol. Benchmarks
must include that cost; this implementation does not claim zero-copy performance.

Storage keys are derived into separate SQLCipher and journal keys. Keep the root
storage key in the platform's secure storage, the path in app-private storage,
and destroy both data and keys on confirmed account logout. File deletion does
not promise physical erasure from SSD snapshots/backups. Old epochs already read
by a removed member cannot be revoked retroactively.

## Sources and notices

- Standard: https://www.rfc-editor.org/rfc/rfc9420.html
- Rust implementation: https://github.com/openmls/openmls
- Dart wrapper source: https://github.com/djx-y-z/openmls_dart
- Pinned release: https://pub.dev/packages/openmls/versions/3.2.1

`THIRD_PARTY_NOTICES.txt` and `OPENMLS_WRAPPER_LICENSE.txt` are copied verbatim
from that pinned dependency. Any application distributing its native binary must
ship the notices; a Flutter application should register them in LicenseRegistry.
This package keeps them available as source files rather than injecting a Flutter
dependency into the standalone Dart SDK.
