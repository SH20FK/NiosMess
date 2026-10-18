# Nios five-module protocol lab

An executable integration of the five proposed technical modules, using real
native OpenMLS and Iroh QUIC plus loopback HTTP services. It creates synthetic
accounts and content in a temporary directory. It never contacts the NiosMess
backend, uses a production account, or changes installed application data.

## Run

Requires Dart 3.12 or newer and a platform supported by both pinned native
dependencies. The Windows x64 native path has been executed. Android/iOS device
qualification, public-network NAT traversal and physical multi-host failures
are separate deployment checks.

```sh
dart pub get
dart analyze --fatal-infos
dart test
dart run bin/nios_lab.dart
```

`runNiosProtocolLab()` is also exported from `package:nios_lab/nios_lab.dart`.
It returns `Future<Map<String, Object>>`. Success returns `status: passed` and
numeric/boolean diagnostics only. Failure throws; the CLI translates it to a
generic `lab_verification_failed` code and nonzero exit status without printing
exception strings, keys, tokens or message bodies. Test failures retain the
individual invariant's symbolic error code.

## What is exercised

1. **Key transparency.** Two account identity keys authorize a device bundle:
   the MLS credential signing key, a separate Link Ed25519 signing key, and the
   Iroh endpoint public key. The statements have real account signatures,
   RFC 6962 inclusion proofs, a signed checkpoint and a persistent witness
   signature. The verified bundle supplies both transport pins and envelope
   verification keys. The local witness models the API; its placement on the
   same machine is not administrative or physical independence.
2. **MLS.** Alice creates a genuine RFC 9420 group, adds Bob's real KeyPackage,
   and Bob processes the Welcome. MLS encrypts the file's stream manifest,
   distribution manifest, their hashes and the decryption key. Restart returns
   the identical outbound ciphertext and saved inbound plaintext. Removing Bob
   advances the epoch; Bob cannot read the new application message.
3. **Durable Link over Iroh.** A real QUIC operation is durably applied by Bob,
   while Alice deliberately discards the ACK. Alice's encrypted queue survives
   closing and reopening with the same signed envelope bytes; retransmission
   returns a valid ACK and does not apply the operation again. A simulated
   attacker given the group encryption secret cannot forge Bob's ACK, because
   the outer Ed25519 signature uses Bob's separately authorized device key.
4. **NiosStream over HTTP Range.** Bob authenticates the received manifest and
   reads an arbitrary plaintext range through bearer-authenticated HTTP 206
   responses. Each ciphertext segment is authenticated before plaintext release.
   Restart reuses verified segments instead of downloading them again.
5. **Three-of-five storage.** Five actual loopback HTTP shard servers acknowledge
   stored ciphertext shares. Two servers are stopped. The remaining three
   restore the ciphertext; a replacement node receives a repaired share without
   a file decryption key. NiosStream then authenticates and restores the exact
   original synthetic plaintext.

The exporter derives an epoch-bound encryption key. All group members can know
that key; it is never treated as proof of a unique sender or ACK origin. Device
authentication comes from the account-authorized outer Ed25519 signature.
Production applications must retain the appropriate old epoch encryption keys
for already queued envelopes and use distinct session IDs when rotating keys.

The optional `DeviceKeyStatement.linkSigningKey` and `transportEndpointKey` form
one complete binding. Both are covered by the account identity signature in the
domain-separated statement version 2, alongside the MLS device key. A statement
without either field retains the original version 1 signing bytes and can still
authorize MLS-only membership. A v1 record cannot authorize a Link signer or Iroh
endpoint. Swapping a transport key invalidates the account signature even if the
log and witness sign a checkpoint containing the tampered entry. Both keys are
persisted and retained in revoked-device tombstones; device IDs cannot be reused
to silently replace a key.

The lab closes native engines, sessions, HTTP clients and listeners, then deletes
its own temporary directory. It leaves no test account or remote service behind.
The CLI flushes its report and explicitly exits after cleanup because upstream
FRB receive ports otherwise keep a plain Dart process alive. The exported lab
function never exits or tears down its host application's shared native runtime.
It is an integration reference and qualification target, not a promise that an
unconfigured production backend supports these new protocols.
