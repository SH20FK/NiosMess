# NiosLink Iroh transport

Native peer-to-peer QUIC transport for `package:nios_sdk/link.dart`, backed by
the real Iroh Rust core through pinned `iroh_quic` 1.1.0. Requires Dart 3.12+.
This package is independent of Flutter platform configuration.

## Install and verify

```sh
dart pub get
dart run iroh_quic:setup
dart analyze
dart test
```

The setup tool verifies the publisher's Ed25519 signature on the platform
library. Native loading is a mandatory test prerequisite: tests fail if the
library is absent; they do not replace QUIC with a simulation. CI must run setup
on its runner. A Flutter/mobile distributor must explicitly bundle/build native
libraries for its target platforms; a desktop per-user setup cache is not an APK
dependency. The native artifact is not checked into this repository.

## Account identity and peer pins

`IrohIdentityStore.loadOrCreate(directory:, accountId:, wrappingKey:)` stores a
fresh Iroh secret identity under AES-256-GCM with account-bound associated data.
Keep its wrapping key in the OS credential store, independently from the file.
A wrong key or modified file fails closed without resetting the identity.
Concurrent identity loads in one isolate are serialized and independently
authenticate each caller's wrapping key; an OS advisory lock also protects the
file across processes. The application must use one identity-store owner across
its isolates, because Unix advisory locks may be process-scoped.

Bind `IrohLinkTransport` with that identity, a device identifier, and callbacks:

```dart
late DurableSession session;
final transport = await IrohLinkTransport.bind(
  deviceId: deviceId,
  identity: identity,
  onOperation: (envelope) => session.receive(envelope),
  onAcknowledgement: (ack) => session.acceptAcknowledgement(ack),
);
```

Pass the transport to `DurableSession.open`, then obtain a peer's Iroh
`EndpointId` through an authenticated key exchange. `setPeer(IrohPeer(...))`
binds that key to exactly one device identifier. Address updates must retain the
same key. Identity changes require explicit application confirmation before the
old pin is removed; discovery and user names must not automatically replace pins.
Exchange `transport.address` updates through your existing authenticated
signaling channel (`watchAddress` exposes the native address watcher).

## Network and receipt semantics

Relays default to disabled. The adapter replaces the native default DNS/pkarr
lookup with an empty application lookup, and connects to explicit pinned peer
addresses. Supply deployment-controlled HTTPS `relayUrls` explicitly for relay
support. No public relay is implicitly selected and no server is deployed by
this package. Cross-NAT and mobile network transitions still need deployment
and device verification.

ALPN is `nios.link/1`. Each bidirectional stream carries a four-byte big-endian
length followed by UTF-8 JSON, with a strict 2 MiB frame limit and no trailing
data. Only a pinned authenticated QUIC peer may dispatch envelopes. A durable
operation acknowledgement is returned by `DurableSession.receive` after journal
commit; stream success alone is not a receipt. The acknowledgement remains
encrypted/authenticated by the session cipher. Connection failures propagate to
the durable queue for retry or mailbox fallback. This direct transport does not
pretend to store messages for offline peers.

Both inbound and outbound connection counts are bounded, including pending
dials. Operation timeouts close active streams/connections; late native dial
results are explicitly closed. `close()` releases endpoint sockets and handlers.
Call `close()` on account logout before deleting encrypted identity/session data.
Diagnostics publish state codes only, without envelope bodies or keys.

## Verification here

Tests exercise two actual native QUIC endpoints, the actual encrypted
`DurableSession` journal, duplicate delivery, reverse ACK publication, identity
reopen/wrong-key, pin replacement, unknown peers, and an oversized hostile frame
header. A concurrent-load regression verifies that 20 callers retain one pin and
a concurrently supplied wrong wrapping key is still rejected. The local test
uses no public relay. It does not establish Android
background behavior or interoperability with another implementation of this
application protocol.

## Signed address rendezvous

`IrohRendezvousClient` exchanges real native `EndpointAddr.encode()` Postcard
bytes through the additive backend's HTTPS `/v1/iroh/address` directory. This is
signaling, not a relay. Publishing requires both the registered endpoint secret
and the separate registered Link signing key. The address expires within five
minutes and every update has a caller-persisted increasing revision.

```dart
final directory = IrohRendezvousClient(
  baseUri: protocolOrigin,
  accountId: accountId,
  deviceId: deviceId,
  bearerToken: existingAuthenticatedSession,
);
await directory.publish(
  address: transport.address,
  endpointIdentity: identity,
  linkSigningKey: accountAuthorizedLinkSigningKey,
  revision: nextPersistedAddressRevision,
);
final publication = await directory.lookup(
  peerAccountId: enrolledPeerAccount,
  peerDeviceId: enrolledPeerDevice,
  pinnedEndpointId: enrolledEndpointId,
  pinnedLinkSigningKey: enrolledLinkKey,
  chatId: authorizedChatId,
  minimumRevision: lastPersistedPeerAddressRevision,
);
transport.setPeer(publication.peer);
```

Lookup checks both signatures, account/device, freshness and monotonic revision,
then calls the native Postcard decoder and verifies its actual endpoint ID against
the supplied pin. A discovery response cannot replace an identity. Relay URLs
are refused unless explicitly listed in `allowedRelayUrls`; its default is empty.
The backend applies chat/device ACLs, and never dials a supplied address.

The account owner must close the directory on logout, persist revisions and
coordinate `watchAddress` updates. Native enrollment and a tested application
opt-in remain necessary; adding this helper does not activate mobile P2P flows.
The HTTP adapter uses platform TLS validation, refuses redirects, bounds replies,
and aborts pending requests on close. HTTP loopback is an explicit test option.

The test suite includes native Postcard + real QUIC exchange through a Python
backend process. Set `NIOS_PROTOCOL_TEST_PYTHON` to a Python environment containing
`backend_changes/protocol_v1/requirements-test.txt`; CI sets it and runs the test
without skipping. Without that variable only this cross-language test is skipped;
the independent native transport and signed socket-directory tests still run.
