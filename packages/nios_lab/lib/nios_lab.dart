import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:iroh_quic/iroh_quic.dart' as iroh;
import 'package:nios_iroh/nios_iroh.dart' hide SecretKey;
import 'package:nios_mls/nios_mls.dart';
import 'package:nios_sdk/link.dart';
import 'package:nios_sdk/stream.dart';
import 'package:nios_sdk/trust.dart';
import 'package:universal_io/io.dart';

Uint8List _randomKey() {
  final random = Random.secure();
  return Uint8List.fromList(List.generate(32, (_) => random.nextInt(256)));
}

void _require(bool condition, String code) {
  if (!condition) throw StateError(code);
}

/// Runs four modules together against synthetic data. Everything is loopback,
/// temporary and owner-scoped; no production service/account is contacted.
/// The returned report contains states/counts only, never secrets or payloads.
Future<Map<String, Object>> runNiosProtocolLab() async {
  final temp = await Directory.systemTemp.createTemp('nios-four-module-lab-');
  final mlsClients = <NiosMlsClient>[];
  final sessions = <DurableSession>[];
  final ktStores = <HiveTransparencyStateStore>[];
  final downloads = <NiosStreamDownload>[];
  final transports = <IrohLinkTransport>[];
  HttpServer? rangeServer;
  try {
    final now = DateTime.now().toUtc();
    final logSigner = await Ed25519().newKeyPair();
    final witnessSigner = await Ed25519().newKeyPair();
    final identities = <String, SimpleKeyPair>{
      'alice': await Ed25519().newKeyPair(),
      'bob': await Ed25519().newKeyPair(),
    };
    final linkSigningKeys = <String, SimpleKeyPair>{
      'alice': await Ed25519().newKeyPair(),
      'bob': await Ed25519().newKeyPair(),
    };
    final irohIdentities = <String, iroh.SecretKey>{};
    for (final account in identities.keys) {
      irohIdentities[account] = await IrohIdentityStore.loadOrCreate(
        directory: '${temp.path}/iroh-$account',
        accountId: account,
        wrappingKey: SecretKey(_randomKey()),
      );
    }
    Future<HiveTransparencyStateStore> store(String name) async {
      final s = await HiveTransparencyStateStore.open(
        path: '${temp.path}/trust',
        boxName: 'lab-$name',
        encryptionKey: _randomKey(),
      );
      ktStores.add(s);
      return s;
    }

    final observer = await KeyTransparencyClient.open(
      logId: 'nios-lab-log',
      logPublicKey: (await logSigner.extractPublicKey()).bytes,
      witnessPublicKeys: {
        'independent': (await witnessSigner.extractPublicKey()).bytes,
      },
      witnessQuorum: 1,
      store: await store('observer'),
      now: () => now,
    );
    for (final identity in identities.entries) {
      await observer.pinAccount(
        identity.key,
        (await identity.value.extractPublicKey()).bytes,
      );
    }
    final witness = await KeyTransparencyWitness.open(
      witnessId: 'independent',
      logId: 'nios-lab-log',
      logPublicKey: (await logSigner.extractPublicKey()).bytes,
      signingKey: witnessSigner,
      store: await store('witness'),
      now: () => now,
    );
    Future<bool> authorize(
      String account,
      String device,
      Uint8List key,
    ) async => observer
        .devices(account)
        .any(
          (known) =>
              known.deviceId == device && sameDigest(known.publicKey, key),
        );
    final mlsKeys = {'alice': _randomKey(), 'bob': _randomKey()};
    Future<NiosMlsClient> openMls(String account) async {
      final client = await NiosMlsClient.open(
        path: '${temp.path}/mls-$account',
        storageKey: mlsKeys[account]!,
        accountId: account,
        deviceId: '$account-phone',
        authorizeDevice: authorize,
      );
      mlsClients.add(client);
      return client;
    }

    var alice = await openMls('alice');
    var bob = await openMls('bob');
    final tree = TransparencyMerkleLog();
    final statements = <AuthorizedDeviceStatement>[];
    for (final client in [alice, bob]) {
      final entry = await AuthorizedDeviceStatement.sign(
        DeviceKeyStatement(
          accountId: client.accountId,
          deviceId: client.deviceId,
          revision: 1,
          action: DeviceKeyAction.enroll,
          deviceKey: client.signingPublicKey,
          linkSigningKey:
              (await linkSigningKeys[client.accountId]!.extractPublicKey())
                  .bytes,
          transportEndpointKey: irohIdentities[client.accountId]!.publicKey
              .asBytes(),
          previousStatementHash: Uint8List(32),
          createdAtMilliseconds: now.millisecondsSinceEpoch,
        ),
        identities[client.accountId]!,
      );
      tree.append(entry.logEntry);
      statements.add(entry);
    }
    final cp = await signLogCheckpoint(
      LogCheckpoint(
        logId: 'nios-lab-log',
        size: tree.length,
        root: tree.root(),
        issuedAtMilliseconds: now.millisecondsSinceEpoch,
      ),
      logSigner,
    );
    final coSignature = await witness.approve(cp);
    await observer.apply(
      signedCheckpoint: SignedLogCheckpoint(
        checkpoint: cp.checkpoint,
        logSignature: cp.logSignature,
        witnesses: [coSignature],
      ),
      statements: [
        for (var i = 0; i < statements.length; i++)
          ProvenDeviceStatement(
            entry: statements[i],
            leafIndex: i,
            inclusionProof: tree.inclusionProof(i),
          ),
      ],
    );
    _require(
      observer.devices('alice').length == 1 &&
          observer.devices('bob').length == 1,
      'key_transparency_enrollment_failed',
    );

    final group = utf8.encode('nios-lab-pairwise-group');
    await alice.createGroup(groupId: group);
    final add = await alice.addDevices(
      operationId: 'add-bob',
      groupId: group,
      keyPackages: [await bob.createKeyPackage()],
    );
    await bob.join(welcome: add.welcome!);
    final aliceLinkKey = await alice.deriveApplicationKey(
      groupId: group,
      label: 'link-envelope',
      context: utf8.encode('epoch-1/alice-phone/bob-phone'),
    );
    final bobLinkKey = await bob.deriveApplicationKey(
      groupId: group,
      label: 'link-envelope',
      context: utf8.encode('epoch-1/alice-phone/bob-phone'),
    );
    _require(
      sameDigest(
        await aliceLinkKey.extractBytes(),
        await bobLinkKey.extractBytes(),
      ),
      'mls_exporter_disagreement',
    );

    final input = File('${temp.path}/synthetic-input.bin');
    // Deterministic synthetic bytes make corruption/seek verification precise.
    final original = Uint8List.fromList(
      List.generate(384 * 1024 + 37, (i) => (i * 31 + i ~/ 251) & 255),
    );
    await input.writeAsBytes(original, flush: true);
    final prepared = await NiosStream.prepareFile(
      inputPath: input.path,
      outputDirectory: '${temp.path}/prepared',
      segmentSize: 32 * 1024,
    );
    // The manifest hash and decryption key are authenticated inside MLS.
    final metadata = <String, Object>{
      'stream': prepared.manifest.toJson(),
      'streamHash': prepared.manifest.hash,
      'fileKey': base64Encode(await prepared.key.extractBytes()),
    };
    final mlsOperation = await alice.encrypt(
      operationId: 'deliver-file-metadata',
      groupId: group,
      plaintext: utf8.encode(jsonEncode(metadata)),
    );
    await alice.close();
    alice = await openMls('alice');
    final restoredMlsOperation = await alice.encrypt(
      operationId: 'deliver-file-metadata',
      groupId: group,
      plaintext: utf8.encode(jsonEncode(metadata)),
    );
    _require(
      sameDigest(mlsOperation.message, restoredMlsOperation.message),
      'mls_ciphertext_changed_on_restart',
    );

    late DurableSession aliceSession;
    late DurableSession bobSession;
    var aliceTransport = await IrohLinkTransport.bind(
      deviceId: 'alice-phone',
      identity: irohIdentities['alice']!,
      onOperation: (e) => aliceSession.receive(e),
      onAcknowledgement: (e) => aliceSession.acceptAcknowledgement(e),
    );
    transports.add(aliceTransport);
    final bobTransport = await IrohLinkTransport.bind(
      deviceId: 'bob-phone',
      identity: irohIdentities['bob']!,
      onOperation: (e) => bobSession.receive(e),
      onAcknowledgement: (e) => bobSession.acceptAcknowledgement(e),
    );
    transports.add(bobTransport);
    await _waitForAddresses([aliceTransport, bobTransport]);
    TrustedDeviceKey trustedDevice(String account, String device) => observer
        .devices(account)
        .singleWhere((entry) => entry.deviceId == device);
    void pinTransport(
      IrohLinkTransport local,
      IrohLinkTransport remote,
      String remoteAccount,
    ) {
      final trusted = trustedDevice(remoteAccount, remote.deviceId);
      final expected = iroh.PublicKey.fromBytes(trusted.transportEndpointKey!);
      _require(remote.endpointId == expected, 'untrusted_transport_endpoint');
      local.setPeer(
        IrohPeer(
          deviceId: remote.deviceId,
          endpointId: expected,
          address: remote.address,
        ),
      );
    }

    pinTransport(aliceTransport, bobTransport, 'bob');
    pinTransport(bobTransport, aliceTransport, 'alice');
    final journalKeys = {'alice': _randomKey(), 'bob': _randomKey()};
    Future<DurableSession> openLink(
      String account,
      IrohLinkTransport transport,
      SecretKey key,
    ) async {
      final session = await DurableSession.open(
        directory: '${temp.path}/link-$account',
        accountId: account,
        deviceId: '$account-phone',
        journalKey: journalKeys[account]!,
        cipher: SignedEnvelopeCipher(
          deviceId: '$account-phone',
          inner: AesGcmEnvelopeCipher(
            deviceId: '$account-phone',
            keyForPeer: (_) async => key,
          ),
          signingKeyPair: linkSigningKeys[account]!,
          signingKeyForPeer: (device) async {
            final known = [
              for (final owner in identities.keys) ...observer.devices(owner),
            ].singleWhere((entry) => entry.deviceId == device);
            return SimplePublicKey(
              known.linkSigningKey!,
              type: KeyPairType.ed25519,
            );
          },
        ),
        transports: [transport],
        autoStart: false,
        reducer: (state, operation) => {
          'count': (state['count'] as int? ?? 0) + 1,
          'mls': operation.payload['mls'],
        },
      );
      sessions.add(session);
      return session;
    }

    aliceSession = await openLink('alice', aliceTransport, aliceLinkKey);
    bobSession = await openLink('bob', bobTransport, bobLinkKey);
    final saved = await aliceSession.enqueue(
      peerId: 'bob-phone',
      sessionId: 'pair-epoch-1',
      operationId: 'stream-metadata-1',
      payload: {'mls': base64Encode(mlsOperation.message)},
    );
    // Persisted queue is tested before opening a delivery socket.
    _require(
      saved.facts.contains(DeliveryFact.localDurable),
      'queue_not_saved',
    );
    // Knowing a group exporter cannot impersonate a specific receiver's ACK.
    // The simulated attacker has the encryption key but a different signer.
    final attacker = SignedEnvelopeCipher(
      deviceId: 'bob-phone',
      inner: AesGcmEnvelopeCipher(
        deviceId: 'bob-phone',
        keyForPeer: (_) async => bobLinkKey,
      ),
      signingKeyPair: await Ed25519().newKeyPair(),
      signingKeyForPeer: (_) async => SimplePublicKey(
        trustedDevice('bob', 'bob-phone').linkSigningKey!,
        type: KeyPairType.ed25519,
      ),
    );
    final forgedAck = await attacker.seal(
      EnvelopeContext(
        senderId: 'bob-phone',
        recipientId: 'alice-phone',
        sessionId: saved.context.sessionId,
        operationId: saved.operationId,
        sequence: saved.context.sequence,
        kind: 'ack',
      ),
      utf8.encode(
        jsonEncode({
          'digest': saved.envelope.digest,
          'fact': 'recipientApplied',
        }),
      ),
    );
    var forgedAckRejected = false;
    try {
      await aliceSession.acceptAcknowledgement(forgedAck);
    } catch (_) {
      forgedAckRejected = true;
    }
    _require(
      forgedAckRejected && !aliceSession.operation(saved.operationId)!.applied,
      'group_secret_forged_device_ack',
    );
    // Recipient commits, but the response never reaches the sender's journal.
    await aliceTransport.deliver(saved.envelope);
    _require(
      bobSession.appliedOperations.length == 1 &&
          !aliceSession.operation(saved.operationId)!.applied,
      'lost_ack_not_simulated',
    );
    await aliceSession.close();
    aliceTransport = await IrohLinkTransport.bind(
      deviceId: 'alice-phone',
      identity: irohIdentities['alice']!,
      onOperation: (e) => aliceSession.receive(e),
      onAcknowledgement: (e) => aliceSession.acceptAcknowledgement(e),
    );
    transports.add(aliceTransport);
    await _waitForAddresses([aliceTransport]);
    pinTransport(aliceTransport, bobTransport, 'bob');
    pinTransport(bobTransport, aliceTransport, 'alice');
    aliceSession = await openLink('alice', aliceTransport, aliceLinkKey);
    _require(
      aliceSession.operation(saved.operationId)!.envelope.digest ==
          saved.envelope.digest,
      'link_ciphertext_changed_on_restart',
    );
    await aliceSession.pump();
    _require(
      aliceSession.operation(saved.operationId)!.applied,
      'quic_durable_ack_missing',
    );
    final duplicate = await aliceTransport.deliver(saved.envelope);
    await aliceSession.acceptAcknowledgement(duplicate.acknowledgement!);
    _require(bobSession.appliedOperations.length == 1, 'duplicate_was_applied');
    final receivedMls = base64Decode(
      bobSession.appliedOperations.single.payload['mls'] as String,
    );
    final opened = await bob.receive(groupId: group, message: receivedMls);
    await bob.close();
    bob = await openMls('bob');
    final reopened = await bob.receive(groupId: group, message: receivedMls);
    _require(
      sameDigest(opened.plaintext!, reopened.plaintext!),
      'mls_plaintext_changed_on_restart',
    );
    final received =
        jsonDecode(utf8.decode(reopened.plaintext!)) as Map<String, dynamic>;
    final manifest = NiosStreamManifest.fromJson(
      received['stream'] as Map<String, dynamic>,
      expectedHash: received['streamHash'] as String,
    );
    final fileKey = SecretKey(base64Decode(received['fileKey'] as String));

    var rangeRequests = 0;
    rangeServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    rangeServer.listen((request) async {
      if (request.headers.value(HttpHeaders.authorizationHeader) !=
          'Bearer ephemeral-lab-range-token') {
        request.response.statusCode = HttpStatus.unauthorized;
        await request.response.close();
        return;
      }
      final match = RegExp(
        r'^bytes=(\d+)-(\d+)$',
      ).firstMatch(request.headers.value(HttpHeaders.rangeHeader) ?? '');
      if (match == null || request.uri.path != '/ciphertext') {
        request.response.statusCode = HttpStatus.badRequest;
        await request.response.close();
        return;
      }
      final start = int.parse(match[1]!);
      final end = int.parse(match[2]!);
      if (start < 0 ||
          end < start ||
          end >= manifest.ciphertextLength ||
          end - start + 1 > 32784) {
        request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        await request.response.close();
        return;
      }
      rangeRequests++;
      request.response.statusCode = HttpStatus.partialContent;
      request.response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-$end/${manifest.ciphertextLength}',
      );
      request.response.contentLength = end - start + 1;
      await request.response.addStream(
        File(prepared.ciphertextPath).openRead(start, end + 1),
      );
      await request.response.close();
    });
    final source = HttpRangeCiphertextSource(
      uri: Uri.parse('http://127.0.0.1:${rangeServer.port}/ciphertext'),
      headers: {'Authorization': 'Bearer ephemeral-lab-range-token'},
      totalLength: manifest.ciphertextLength,
      maximumRangeLength: 32784,
      allowInsecureLoopback: true,
    );
    var download = await NiosStreamDownload.open(
      directory: '${temp.path}/http-download',
      manifest: manifest,
      key: fileKey,
      sources: [source],
    );
    downloads.add(download);
    final start = 129 * 1024 + 11;
    final seek = await download.readRange(start, start + 7000);
    _require(
      sameDigest(seek, original.sublist(start, start + 7000)),
      'range_seek_mismatch',
    );
    final downloadedBefore = download.verifiedSegmentCount;
    await download.close();
    download = await NiosStreamDownload.open(
      directory: '${temp.path}/http-download',
      manifest: manifest,
      key: fileKey,
      sources: [source],
    );
    downloads.add(download);
    _require(
      download.verifiedSegmentCount == downloadedBefore,
      'range_progress_lost',
    );
    final requestsBefore = rangeRequests;
    await download.readRange(start, start + 7000);
    _require(rangeRequests == requestsBefore, 'verified_range_redownloaded');
    await download.downloadAll();
    _require(download.isComplete, 'http_download_incomplete');

    final plaintext = await download.readRange(0, original.length);
    _require(sameDigest(plaintext, original), 'downloaded_plaintext_mismatch');

    // Exclude Bob and prove that the new MLS epoch cannot be read by his state.
    final bobIndex = (await alice.members(
      group,
    )).singleWhere((d) => d.accountId == 'bob').leafIndex;
    final removed = await alice.removeDevices(
      operationId: 'remove-bob',
      groupId: group,
      leafIndices: [bobIndex],
    );
    await bob.receive(groupId: group, message: removed.message);
    _require(!await bob.isActive(group), 'removed_member_still_active');
    final next = await alice.encrypt(
      operationId: 'post-removal',
      groupId: group,
      plaintext: utf8.encode('synthetic-post-removal-proof'),
    );
    var refused = false;
    try {
      await bob.receive(groupId: group, message: next.message);
    } catch (_) {
      refused = true;
    }
    _require(refused, 'removed_member_decrypted_new_epoch');

    return {
      'status': 'passed',
      'modules': 4,
      'transport': 'native_iroh_quic',
      'trusted_devices': 2,
      'witness_quorum': 1,
      'mls_ciphertext_restart': true,
      'link_ciphertext_restart': true,
      'device_signed_acknowledgements': true,
      'group_key_forgery_rejected': true,
      'lost_ack_recovered_after_restart': true,
      'transport_keys_account_authorized': true,
      'mls_plaintext_restart': true,
      'duplicate_applications': 0,
      'file_bytes': original.length,
      'segments': manifest.segmentCount,
      'http_range_requests': rangeRequests,
      'cache_reused_after_restart': true,
      'plaintext_verified': true,
      'removed_member_rejected': true,
    };
  } finally {
    for (final download in downloads) {
      await download.close();
    }
    for (final session in sessions) {
      await session.close();
    }
    for (final transport in transports) {
      await transport.close();
    }
    for (final client in mlsClients) {
      await client.close();
    }
    for (final store in ktStores) {
      await store.close();
    }
    await rangeServer?.close(force: true);
    await temp.delete(recursive: true);
  }
}

Future<void> _waitForAddresses(List<IrohLinkTransport> transports) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (transports.any((t) => t.address.ipAddrs.isEmpty)) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('quic_address_unavailable');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
