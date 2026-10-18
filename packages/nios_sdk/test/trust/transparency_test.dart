import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:nios_sdk/trust.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

final class MemoryStore implements TransparencyStateStore {
  Map<String, dynamic>? value;
  bool fail = false;
  Completer<void>? writeEntered;
  Completer<void>? releaseWrite;
  @override
  Future<Map<String, dynamic>?> read() async => value == null
      ? null
      : jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
  @override
  Future<void> write(Map<String, dynamic> snapshot) async {
    if (writeEntered != null && !writeEntered!.isCompleted) {
      writeEntered!.complete();
    }
    await releaseWrite?.future;
    if (fail) throw StateError('disk_full');
    value = jsonDecode(jsonEncode(snapshot)) as Map<String, dynamic>;
  }
}

void main() {
  late SimpleKeyPair logKey, witness, identity, attacker;
  late KeyTransparencyClient client;
  late MemoryStore store;
  late TransparencyMerkleLog log;
  late List<AuthorizedDeviceStatement> entries;
  final time = DateTime.utc(2026, 10, 17);
  Future<KeyTransparencyClient> open(TransparencyStateStore storage) async =>
      KeyTransparencyClient.open(
        logId: 'nios-test',
        logPublicKey: (await logKey.extractPublicKey()).bytes,
        witnessPublicKeys: {
          'independent': (await witness.extractPublicKey()).bytes,
        },
        witnessQuorum: 1,
        store: storage,
        now: () => time,
      );
  Future<AuthorizedDeviceStatement> make({
    String device = 'phone',
    DeviceKeyAction action = DeviceKeyAction.enroll,
    List<int>? key,
    SimpleKeyPair? signer,
  }) async {
    final entry = await AuthorizedDeviceStatement.sign(
      DeviceKeyStatement(
        accountId: 'alice',
        deviceId: device,
        revision: entries.length + 1,
        action: action,
        deviceKey: key ?? List.filled(32, device == 'phone' ? 1 : 2),
        previousStatementHash: entries.isEmpty
            ? Uint8List(32)
            : entries.last.hash,
        createdAtMilliseconds: time.millisecondsSinceEpoch,
      ),
      signer ?? identity,
    );
    entries.add(entry);
    log.append(entry.logEntry);
    return entry;
  }

  Future<SignedLogCheckpoint> checkpoint({
    TransparencyMerkleLog? tree,
    int? size,
    SimpleKeyPair? witnessKey,
    int? milliseconds,
  }) => signLogCheckpoint(
    LogCheckpoint(
      logId: 'nios-test',
      size: size ?? (tree ?? log).length,
      root: (tree ?? log).root(size),
      issuedAtMilliseconds: milliseconds ?? time.millisecondsSinceEpoch,
    ),
    logKey,
    witnessKeys: {'independent': witnessKey ?? witness},
  );
  ProvenDeviceStatement proof(int i, {TransparencyMerkleLog? tree}) =>
      ProvenDeviceStatement(
        entry: entries[i],
        leafIndex: i,
        inclusionProof: (tree ?? log).inclusionProof(i),
      );
  Matcher error(String code) =>
      isA<TransparencyException>().having((e) => e.code, 'code', code);
  setUp(() async {
    logKey = await Ed25519().newKeyPair();
    witness = await Ed25519().newKeyPair();
    identity = await Ed25519().newKeyPair();
    attacker = await Ed25519().newKeyPair();
    store = MemoryStore();
    log = TransparencyMerkleLog();
    entries = [];
    client = await open(store);
    await client.pinAccount('alice', (await identity.extractPublicKey()).bytes);
  });

  test(
    'real signatures enroll, restart, revoke and keep key tombstone',
    () async {
      await make();
      await client.apply(
        signedCheckpoint: await checkpoint(),
        statements: [proof(0)],
      );
      await make(device: 'laptop');
      final restarted = await open(store);
      await restarted.apply(
        signedCheckpoint: await checkpoint(),
        consistencyProof: log.consistencyProof(1),
        statements: [proof(1)],
      );
      expect(restarted.devices('alice'), hasLength(2));
      await make(action: DeviceKeyAction.revoke);
      await restarted.apply(
        signedCheckpoint: await checkpoint(),
        consistencyProof: log.consistencyProof(2),
        statements: [proof(2)],
      );
      expect(restarted.devices('alice').single.deviceId, 'laptop');
      expect(
        restarted.devices('alice', includeRevoked: true).first.revoked,
        isTrue,
      );
      final finalRestart = await open(store);
      expect(finalRestart.devices('alice'), hasLength(1));
      await expectLater(
        finalRestart.pinAccount(
          'alice',
          (await attacker.extractPublicKey()).bytes,
        ),
        throwsA(error('identity_key_changed')),
      );
    },
  );

  test(
    'account signature binds MLS, Link signing and transport endpoint keys',
    () async {
      final linkKey =
          (await (await Ed25519().newKeyPair()).extractPublicKey()).bytes;
      final endpointKey =
          (await (await Ed25519().newKeyPair()).extractPublicKey()).bytes;
      final statement = DeviceKeyStatement(
        accountId: 'alice',
        deviceId: 'phone',
        revision: 1,
        action: DeviceKeyAction.enroll,
        deviceKey: List.filled(32, 1),
        linkSigningKey: linkKey,
        transportEndpointKey: endpointKey,
        previousStatementHash: Uint8List(32),
        createdAtMilliseconds: time.millisecondsSinceEpoch,
      );
      final authorized = await AuthorizedDeviceStatement.sign(
        statement,
        identity,
      );
      final changed = DeviceKeyStatement.fromJson({
        ...statement.toJson(),
        'transportEndpointKey': base64Encode(
          (await attacker.extractPublicKey()).bytes,
        ),
      });
      final tampered = AuthorizedDeviceStatement(
        statement: changed,
        signature: authorized.signature,
      );
      final maliciousLog = TransparencyMerkleLog()..append(tampered.logEntry);
      await expectLater(
        client.apply(
          signedCheckpoint: await checkpoint(tree: maliciousLog),
          statements: [
            ProvenDeviceStatement(
              entry: tampered,
              leafIndex: 0,
              inclusionProof: maliciousLog.inclusionProof(0),
            ),
          ],
        ),
        throwsA(error('invalid_identity_signature')),
      );
      expect(client.devices('alice'), isEmpty);
      entries.add(authorized);
      log.append(authorized.logEntry);
      await client.apply(
        signedCheckpoint: await checkpoint(),
        statements: [proof(0)],
      );
      final restarted = await open(store);
      final device = restarted.devices('alice').single;
      expect(device.linkSigningKey, linkKey);
      expect(device.transportEndpointKey, endpointKey);
      expect(
        DeviceKeyStatement.fromJson(statement.toJson()).signingBytes,
        statement.signingBytes,
      );
      await make(action: DeviceKeyAction.revoke);
      await restarted.apply(
        signedCheckpoint: await checkpoint(),
        consistencyProof: log.consistencyProof(1),
        statements: [proof(1)],
      );
      expect(restarted.devices('alice'), isEmpty);
      expect(
        restarted.devices('alice', includeRevoked: true).single.linkSigningKey,
        linkKey,
      );
    },
  );

  test('incomplete transport binding is rejected before it can be signed', () {
    expect(
      () => DeviceKeyStatement(
        accountId: 'alice',
        deviceId: 'phone',
        revision: 1,
        action: DeviceKeyAction.enroll,
        deviceKey: List.filled(32, 1),
        linkSigningKey: List.filled(32, 2),
        previousStatementHash: Uint8List(32),
        createdAtMilliseconds: time.millisecondsSinceEpoch,
      ),
      throwsArgumentError,
    );
  });

  test(
    'close fences new calls and drains admitted checkpoint/account writes',
    () async {
      await make();
      final cp = await checkpoint();
      store.writeEntered = Completer<void>();
      store.releaseWrite = Completer<void>();
      final applying = client.apply(
        signedCheckpoint: cp,
        statements: [proof(0)],
      );
      await store.writeEntered!.future;
      final queuedPin = client.pinAccount(
        'bob',
        (await attacker.extractPublicKey()).bytes,
      );
      var drained = false;
      final closing = client.close().then((_) {
        drained = true;
      });
      await expectLater(
        client.pinAccount('mallory', (await attacker.extractPublicKey()).bytes),
        throwsA(error('closed')),
      );
      await expectLater(
        client.apply(signedCheckpoint: cp),
        throwsA(error('closed')),
      );
      expect(drained, isFalse);
      store.releaseWrite!.complete();
      await applying;
      await queuedPin;
      await closing;
      expect(drained, isTrue);
      final restored = await open(store);
      expect(restored.devices('alice'), hasLength(1));
      expect(restored.checkpoint!.size, 1);
      await client.close();
      expect(restored.devices('alice'), hasLength(1));
    },
  );

  test(
    'identity signature, wrong witness and bad inclusion preserve queue trust',
    () async {
      await make(signer: attacker);
      await expectLater(
        client.apply(
          signedCheckpoint: await checkpoint(),
          statements: [proof(0)],
        ),
        throwsA(error('invalid_identity_signature')),
      );
      expect(client.checkpoint, isNull);
      await expectLater(
        client.apply(signedCheckpoint: await checkpoint(witnessKey: attacker)),
        throwsA(error('independent_witness_quorum_missing')),
      );
      final bad = ProvenDeviceStatement(
        entry: entries[0],
        leafIndex: 0,
        inclusionProof: [List.filled(32, 7)],
      );
      await expectLater(
        client.apply(signedCheckpoint: await checkpoint(), statements: [bad]),
        throwsA(error('invalid_inclusion_proof')),
      );
      expect(client.devices('alice'), isEmpty);
    },
  );

  test('duplicate witness signatures cannot manufacture a quorum', () async {
    final witness2 = await Ed25519().newKeyPair();
    final strict = await KeyTransparencyClient.open(
      logId: 'nios-test',
      logPublicKey: (await logKey.extractPublicKey()).bytes,
      witnessPublicKeys: {
        'independent': (await witness.extractPublicKey()).bytes,
        'second': (await witness2.extractPublicKey()).bytes,
      },
      witnessQuorum: 2,
      store: MemoryStore(),
      now: () => time,
    );
    final signed = await checkpoint();
    await expectLater(
      strict.apply(
        signedCheckpoint: SignedLogCheckpoint(
          checkpoint: signed.checkpoint,
          logSignature: signed.logSignature,
          witnesses: [signed.witnesses.single, signed.witnesses.single],
        ),
      ),
      throwsA(error('independent_witness_quorum_missing')),
    );
  });

  test(
    'same-size fork, growing fork and rollback detected by gossip',
    () async {
      await make();
      final cp1 = await checkpoint();
      await client.apply(signedCheckpoint: cp1, statements: [proof(0)]);
      final fork = TransparencyMerkleLog()..append([99]);
      await expectLater(
        client.apply(signedCheckpoint: await checkpoint(tree: fork)),
        throwsA(error('fork_or_invalid_consistency_proof')),
      );
      fork.append([100]);
      await expectLater(
        client.apply(
          signedCheckpoint: await checkpoint(tree: fork),
          consistencyProof: fork.consistencyProof(1),
        ),
        throwsA(error('fork_or_invalid_consistency_proof')),
      );
      await make(device: 'laptop');
      await client.apply(
        signedCheckpoint: await checkpoint(),
        consistencyProof: log.consistencyProof(1),
        statements: [proof(1)],
      );
      await expectLater(
        client.apply(signedCheckpoint: cp1),
        throwsA(error('checkpoint_rollback')),
      );
    },
  );

  test(
    'missing revisions fail atomically; concurrent duplicate is idempotent',
    () async {
      await make();
      await make(device: 'laptop');
      final signed = await checkpoint();
      await expectLater(
        client.apply(signedCheckpoint: signed, statements: [proof(1)]),
        throwsA(error('account_history_not_contiguous')),
      );
      await Future.wait([
        client.apply(
          signedCheckpoint: signed,
          statements: [proof(0), proof(1)],
        ),
        client.apply(signedCheckpoint: signed, statements: [proof(1)]),
      ]);
      expect(client.devices('alice'), hasLength(2));
      store.fail = true;
      await make(device: 'tablet');
      await expectLater(
        client.apply(
          signedCheckpoint: await checkpoint(),
          consistencyProof: log.consistencyProof(2),
          statements: [proof(2)],
        ),
        throwsStateError,
      );
      expect(client.checkpoint!.size, 2);
      expect(client.devices('alice'), hasLength(2));
    },
  );

  test('future/stale checkpoint and reused device ID rejected', () async {
    await expectLater(
      client.apply(
        signedCheckpoint: await checkpoint(
          milliseconds: time
              .add(const Duration(days: 1))
              .millisecondsSinceEpoch,
        ),
      ),
      throwsA(error('checkpoint_outside_freshness_policy')),
    );
    await make();
    await client.apply(
      signedCheckpoint: await checkpoint(),
      statements: [proof(0)],
    );
    await make();
    await expectLater(
      client.apply(
        signedCheckpoint: await checkpoint(),
        consistencyProof: log.consistencyProof(1),
        statements: [proof(1)],
      ),
      throwsA(error('device_identifier_already_used')),
    );
  });

  test(
    'encrypted Hive pin/checkpoint storage survives reopen without plaintext',
    () async {
      final temp = await Directory.systemTemp.createTemp('nios-kt-');
      final key = List.generate(32, (i) => i);
      HiveTransparencyStateStore? disk;
      try {
        disk = await HiveTransparencyStateStore.open(
          path: temp.path,
          boxName: 'kt-alice',
          encryptionKey: key,
        );
        var c = await open(disk);
        await c.pinAccount('alice', (await identity.extractPublicKey()).bytes);
        await make();
        await c.apply(
          signedCheckpoint: await checkpoint(),
          statements: [proof(0)],
        );
        await disk.close();
        final file = await File('${temp.path}/kt-alice.hive').readAsBytes();
        expect(
          latin1.decode(file, allowInvalid: true),
          isNot(contains('alice')),
        );
        disk = await HiveTransparencyStateStore.open(
          path: temp.path,
          boxName: 'kt-alice',
          encryptionKey: key,
        );
        c = await open(disk);
        expect(c.checkpoint!.size, 1);
        expect(c.devices('alice'), hasLength(1));
      } finally {
        await disk?.close();
        await temp.delete(recursive: true);
      }
    },
  );

  test(
    'concurrent first open and a wrong key cannot erase trust storage',
    () async {
      final temp = await Directory.systemTemp.createTemp('nios-kt-open-');
      final key = List.generate(32, (i) => i);
      HiveTransparencyStateStore? disk;
      try {
        final opening = HiveTransparencyStateStore.open(
          path: temp.path,
          boxName: 'kt-first-open',
          encryptionKey: key,
        );
        await expectLater(
          HiveTransparencyStateStore.open(
            path: temp.path,
            boxName: 'kt-first-open',
            encryptionKey: key,
          ),
          throwsA(error('storage_already_open')),
        );
        disk = await opening;
        await disk.write({'persistent': true});
        await disk.close();
        final before = await File(
          '${temp.path}/kt-first-open.hive',
        ).readAsBytes();
        await expectLater(
          HiveTransparencyStateStore.open(
            path: temp.path,
            boxName: 'kt-first-open',
            encryptionKey: List.filled(32, 99),
          ),
          throwsStateError,
        );
        expect(
          await File('${temp.path}/kt-first-open.hive').readAsBytes(),
          before,
        );
        disk = await HiveTransparencyStateStore.open(
          path: temp.path,
          boxName: 'kt-first-open',
          encryptionKey: key,
        );
        expect(await disk.read(), {'persistent': true});
      } finally {
        await disk?.close();
        await temp.delete(recursive: true);
      }
    },
  );

  test(
    'independent witness monitors append-only history across restart',
    () async {
      final monitorStore = MemoryStore();
      var monitor = await KeyTransparencyWitness.open(
        witnessId: 'independent',
        logId: 'nios-test',
        logPublicKey: (await logKey.extractPublicKey()).bytes,
        signingKey: witness,
        store: monitorStore,
        now: () => time,
      );
      await make();
      var signed = await signLogCheckpoint(
        LogCheckpoint(
          logId: 'nios-test',
          size: log.length,
          root: log.root(),
          issuedAtMilliseconds: time.millisecondsSinceEpoch,
        ),
        logKey,
      );
      final approval = await monitor.approve(signed);
      await client.apply(
        signedCheckpoint: SignedLogCheckpoint(
          checkpoint: signed.checkpoint,
          logSignature: signed.logSignature,
          witnesses: [approval],
        ),
        statements: [proof(0)],
      );
      monitor = await KeyTransparencyWitness.open(
        witnessId: 'independent',
        logId: 'nios-test',
        logPublicKey: (await logKey.extractPublicKey()).bytes,
        signingKey: witness,
        store: monitorStore,
        now: () => time,
      );
      final fork = TransparencyMerkleLog()..append([99]);
      await expectLater(
        monitor.approve(await checkpoint(tree: fork)),
        throwsA(error('fork_or_invalid_consistency_proof')),
      );
      await make(device: 'laptop');
      signed = await signLogCheckpoint(
        LogCheckpoint(
          logId: 'nios-test',
          size: log.length,
          root: log.root(),
          issuedAtMilliseconds: time.millisecondsSinceEpoch,
        ),
        logKey,
      );
      final nextApproval = await monitor.approve(
        signed,
        consistencyProof: log.consistencyProof(1),
      );
      await client.apply(
        signedCheckpoint: SignedLogCheckpoint(
          checkpoint: signed.checkpoint,
          logSignature: signed.logSignature,
          witnesses: [nextApproval],
        ),
        consistencyProof: log.consistencyProof(1),
        statements: [proof(1)],
      );
      expect(client.devices('alice'), hasLength(2));
      monitorStore.fail = true;
      await make(device: 'tablet');
      signed = await signLogCheckpoint(
        LogCheckpoint(
          logId: 'nios-test',
          size: log.length,
          root: log.root(),
          issuedAtMilliseconds: time.millisecondsSinceEpoch,
        ),
        logKey,
      );
      await expectLater(
        monitor.approve(signed, consistencyProof: log.consistencyProof(2)),
        throwsStateError,
      );
      expect(monitor.checkpoint!.size, 2);
    },
  );
}
