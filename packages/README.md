# Nios protocol packages

These standalone packages implement the five selected technical directions.
NiosMess supplies the Flutter account owner; other native Dart applications can
embed the packages through their public APIs.

| Package | Direction | Implemented surface |
| --- | --- | --- |
| [nios_sdk](nios_sdk/README.md) | #1 | Encrypted persistent operations, retries, ordering, deduplication, distinct delivery facts, device-signed ACKs, HTTP mailbox |
| [nios_iroh](nios_iroh/README.md) | #1 | Native pinned-identity Iroh QUIC and encrypted endpoint identity |
| [nios_sdk](nios_sdk/README.md#2--niosstream-and-native-media) | #2 | Segmented AES-GCM files, resume, authenticated HTTP Range, blob publication, native media gateway |
| [nios_mls](nios_mls/README.md) | #5 | Real RFC 9420 groups through native OpenMLS, authorized device membership and crash-consistent state/result publication |
| [nios_sdk](nios_sdk/README.md#6--key-transparency) | #6 | Account-signed device/transport key bundles, append-only Merkle proofs, checkpoint verification and witness monitor |
| [nios_sdk](nios_sdk/README.md#12--distributed-ciphertext-storage) | #12 | Verified Reed–Solomon 3-of-5 ciphertext shares, restore, repair and deletion tombstones |
| [nios_lab](nios_lab/README.md) | All five | Executable native end-to-end integration with synthetic accounts and loopback services |

## Quick verification

Use Dart 3.12+ for the whole package set. From `packages/nios_sdk`:

```sh
dart pub get
dart analyze --fatal-infos
dart test
```

From `packages/nios_mls`, run the same three commands. Its pinned OpenMLS 3.2.1
dependency downloads the appropriate native library through a checksum-verified
build hook. From `packages/nios_iroh` and then `packages/nios_lab`:

```sh
dart pub get
dart run iroh_quic:setup
dart analyze --fatal-infos
dart test
```

The Iroh setup verifies the upstream signature on the native artifact. Run the
combined demonstration from `packages/nios_lab`:

```sh
dart run bin/nios_lab.dart
```

Success prints one JSON report with `status: passed`; the CLI then exits with
code zero. Report fields are booleans/counts/states without content, tokens or
keys. It uses actual native cryptography and QUIC, discards an ACK before sender
restart, rejects a forged device ACK from an attacker given the encryption
secret, resumes authenticated file ranges, stops two of five HTTP shard nodes,
repairs a share without the file key, and restores the original bytes. It also
checks that an excluded MLS member cannot decrypt the next epoch.

## Current integration boundary

The Flutter account adapter is
`pulse_flutter/lib/services/protocol/nios_protocol_accounts.dart`. It owns
account-scoped storage and root keys, explicit protocol startup, attachment
publication, media handles, MLS and transparency setup, and logout cleanup.
Startup requires authenticated peer keys, configured transports and explicit
protocol version negotiation. The existing app does not automatically switch
older conversations or unsupported peers to the new protocol.

These are working local/reference implementations with explicit production
limits. The native Windows path has been exercised; real Android/iOS behavior,
NAT traversal, mobile background scheduling and media decoders require device
qualification. A desktop native-library download cache does not package mobile
libraries into an APK. The MLS copy-on-write adapter favors durable publication
and copies O(database size) per mutation. Browser durability is a separate
adapter. Reducers cover journal-local application-once effects; external side
effects require their own transactions or idempotency.

The five shard servers and witness in the lab run on one machine. Independent
production failure domains and independent witness operators remain deployment
requirements. Keys/manifests must be backed up or recovered deliberately;
erasure coding cannot recover a lost encryption key. Process-crash flush tests
do not establish persistence after sudden power loss without directory fsync.

## Backend approval

The local loopback mailbox/blob/shard services and lab do not modify
`/opt/niosmess/current` or the production backend. Public endpoint deployment,
account/device enrollment, supported-protocol advertisement, TLS, quotas,
independent key witnesses, relays and storage provisioning still need backend
integration. **Ask the user before changing/deploying the existing backend.**

See each package README for exact APIs, protocol formats, authorization rules,
third-party native notices, shutdown ordering and the limits of each guarantee.
