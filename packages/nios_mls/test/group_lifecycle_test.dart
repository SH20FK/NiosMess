import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:nios_mls/nios_mls.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  late Directory temp;
  late Map<String, Uint8List> trusted;
  late List<NiosMlsClient> clients;
  final key = List.generate(32, (i) => i + 1);
  final groupId = utf8.encode('nios-integration-group');
  Future<NiosMlsClient> open(String device, {MlsFaultHook? fault}) async {
    final c = await NiosMlsClient.open(
      path: '${temp.path}/$device',
      storageKey: key,
      accountId: device == 'alice-laptop' ? 'alice' : device,
      deviceId: device,
      faultHook: fault,
      authorizeDevice: (account, deviceId, publicKey) async =>
          base64Encode(trusted['$account/$deviceId'] ?? []) ==
          base64Encode(publicKey),
    );
    trusted['${c.accountId}/${c.deviceId}'] = c.signingPublicKey;
    clients.add(c);
    return c;
  }

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('nios-mls-');
    trusted = {};
    clients = [];
  });
  tearDown(() async {
    for (final c in clients) {
      await c.close();
    }
    await temp.delete(recursive: true);
  });

  Future<(NiosMlsClient, NiosMlsClient)> pair() async {
    final alice = await open('alice');
    final bob = await open('bob');
    await alice.createGroup(groupId: groupId);
    final kp = await bob.createKeyPackage();
    final add = await alice.addDevices(
      operationId: 'add-bob',
      groupId: groupId,
      keyPackages: [kp],
    );
    await bob.join(welcome: add.welcome!);
    return (alice, bob);
  }

  test(
    'real MLS group, multi-device add, signed commit, remove and epoch secrecy',
    () async {
      final (alice, bob) = await pair();
      expect(await alice.members(groupId), hasLength(2));
      final outgoing = await alice.encrypt(
        operationId: 'hello',
        groupId: groupId,
        plaintext: utf8.encode('hello authenticated MLS'),
      );
      final incoming = await bob.receive(
        groupId: groupId,
        message: outgoing.message,
      );
      expect(utf8.decode(incoming.plaintext!), 'hello authenticated MLS');
      final laptop = await open('alice-laptop');
      final add = await alice.addDevices(
        operationId: 'add-laptop',
        groupId: groupId,
        keyPackages: [await laptop.createKeyPackage()],
      );
      await bob.receive(groupId: groupId, message: add.message);
      await laptop.join(welcome: add.welcome!);
      expect(await bob.members(groupId), hasLength(3));
      expect(await laptop.epoch(groupId), await alice.epoch(groupId));
      final members = await alice.members(groupId);
      final remove = await alice.removeDevices(
        operationId: 'remove-bob',
        groupId: groupId,
        leafIndices: [
          members.singleWhere((m) => m.accountId == 'bob').leafIndex,
        ],
      );
      await laptop.receive(groupId: groupId, message: remove.message);
      await bob.receive(groupId: groupId, message: remove.message);
      expect(await bob.isActive(groupId), isFalse);
      final secret = await alice.encrypt(
        operationId: 'after-removal',
        groupId: groupId,
        plaintext: utf8.encode('only alice devices'),
      );
      expect(
        utf8.decode(
          (await laptop.receive(
            groupId: groupId,
            message: secret.message,
          )).plaintext!,
        ),
        'only alice devices',
      );
      await expectLater(
        bob.receive(groupId: groupId, message: secret.message),
        throwsA(anything),
      );
    },
  );

  test(
    'ciphertext and decrypted result survive restart and duplicate calls',
    () async {
      var (alice, bob) = await pair();
      final own = await alice.encrypt(
        operationId: 'persistent',
        groupId: groupId,
        plaintext: utf8.encode('a persistent message'),
      );
      final decoded = await bob.receive(groupId: groupId, message: own.message);
      await alice.close();
      await bob.close();
      alice = await open('alice');
      bob = await open('bob');
      expect(
        (await alice.encrypt(
          operationId: 'persistent',
          groupId: groupId,
          plaintext: utf8.encode('a persistent message'),
        )).message,
        own.message,
      );
      expect(
        (await bob.receive(groupId: groupId, message: own.message)).plaintext,
        decoded.plaintext,
      );
      await expectLater(
        alice.encrypt(
          operationId: 'persistent',
          groupId: groupId,
          plaintext: utf8.encode('different contents'),
        ),
        throwsA(isA<NiosMlsException>()),
      );
      expect(alice.pendingOperations, hasLength(2));
      await alice.acknowledge('persistent');
      expect(alice.pendingOperations, hasLength(1));
      await alice.close();
      alice = await open('alice');
      expect(alice.pendingOperations, hasLength(1));
      final reply = await bob.encrypt(
        operationId: 'reply',
        groupId: groupId,
        plaintext: utf8.encode('after restart'),
      );
      expect(
        utf8.decode(
          (await alice.receive(
            groupId: groupId,
            message: reply.message,
          )).plaintext!,
        ),
        'after restart',
      );
    },
  );

  test(
    'wrong storage key preserves the journal and previously prepared ciphertext',
    () async {
      var (alice, bob) = await pair();
      final outgoing = await alice.encrypt(
        operationId: 'wrong-key-probe',
        groupId: groupId,
        plaintext: utf8.encode('retained synthetic content'),
      );
      await alice.close();
      await expectLater(
        NiosMlsClient.open(
          path: '${temp.path}/alice',
          storageKey: List.filled(32, 99),
          accountId: 'alice',
          deviceId: 'alice',
          authorizeDevice: (_, _, _) async => true,
        ),
        throwsA(
          isA<NiosMlsException>().having(
            (e) => e.code,
            'code',
            'storage_key_mismatch',
          ),
        ),
      );
      alice = await open('alice');
      expect(
        (await alice.encrypt(
          operationId: 'wrong-key-probe',
          groupId: groupId,
          plaintext: utf8.encode('retained synthetic content'),
        )).message,
        outgoing.message,
      );
      expect(
        utf8.decode(
          (await bob.receive(
            groupId: groupId,
            message: outgoing.message,
          )).plaintext!,
        ),
        'retained synthetic content',
      );
    },
  );

  test(
    'tampered ciphertext and unauthorized membership do not advance state',
    () async {
      final (alice, bob) = await pair();
      final outgoing = await alice.encrypt(
        operationId: 'untampered',
        groupId: groupId,
        plaintext: utf8.encode('intact'),
      );
      final damaged = Uint8List.fromList(outgoing.message);
      damaged[damaged.length ~/ 2] ^= 0x80;
      await expectLater(
        bob.receive(groupId: groupId, message: damaged),
        throwsA(anything),
      );
      expect(
        utf8.decode(
          (await bob.receive(
            groupId: groupId,
            message: outgoing.message,
          )).plaintext!,
        ),
        'intact',
      );
      final mallory = await open('mallory');
      final kp = await mallory.createKeyPackage();
      trusted.remove('mallory/mallory');
      final before = await alice.epoch(groupId);
      await expectLater(
        alice.addDevices(
          operationId: 'untrusted-add',
          groupId: groupId,
          keyPackages: [kp],
        ),
        throwsA(isA<NiosMlsException>()),
      );
      expect(await alice.epoch(groupId), before);
      expect(await alice.members(groupId), hasLength(2));
    },
  );

  test(
    'failure before publication preserves ratchet; after publication recovers exact bytes',
    () async {
      var (alice, bob) = await pair();
      await alice.close();
      var failStage = 'native_state_closed';
      alice = await open(
        'alice',
        fault: (stage) async {
          if (stage == failStage) throw StateError('simulated_process_crash');
        },
      );
      await expectLater(
        alice.encrypt(
          operationId: 'before',
          groupId: groupId,
          plaintext: utf8.encode('before publication'),
        ),
        throwsStateError,
      );
      failStage = '';
      final retry = await alice.encrypt(
        operationId: 'before',
        groupId: groupId,
        plaintext: utf8.encode('before publication'),
      );
      expect(
        utf8.decode(
          (await bob.receive(
            groupId: groupId,
            message: retry.message,
          )).plaintext!,
        ),
        'before publication',
      );
      failStage = 'journal_published';
      await expectLater(
        alice.encrypt(
          operationId: 'after',
          groupId: groupId,
          plaintext: utf8.encode('after publication'),
        ),
        throwsStateError,
      );
      await expectLater(alice.epoch(groupId), throwsA(isA<NiosMlsException>()));
      await alice.close();
      alice = await open('alice');
      final recovered = alice.pendingOperations.singleWhere(
        (o) => o.operationId == 'after',
      );
      final identical = await alice.encrypt(
        operationId: 'after',
        groupId: groupId,
        plaintext: utf8.encode('after publication'),
      );
      expect(identical.message, recovered.message);
      expect(
        utf8.decode(
          (await bob.receive(
            groupId: groupId,
            message: recovered.message,
          )).plaintext!,
        ),
        'after publication',
      );
    },
  );

  test(
    'SQLCipher and journal files contain neither payload nor identity strings',
    () async {
      final (alice, bob) = await pair();
      const marker = 'unique-sensitive-message-abcdefghijklmnopqrstuvwxyz';
      final operation = await alice.encrypt(
        operationId: 'private',
        groupId: groupId,
        plaintext: utf8.encode(marker),
      );
      await bob.receive(groupId: groupId, message: operation.message);
      await alice.close();
      await bob.close();
      await for (final entity in temp.list(recursive: true)) {
        if (entity is File) {
          final contents = latin1.decode(
            await entity.readAsBytes(),
            allowInvalid: true,
          );
          expect(contents, isNot(contains(marker)), reason: entity.path);
          expect(
            contents,
            isNot(startsWith('SQLite format 3')),
            reason: entity.path,
          );
        }
      }
    },
  );

  test(
    'inbound crash before and after publication preserves exact plaintext',
    () async {
      var (alice, bob) = await pair();
      await bob.close();
      var stageToFail = 'native_state_closed';
      bob = await open(
        'bob',
        fault: (stage) async {
          if (stage == stageToFail) throw StateError('simulated_crash');
        },
      );
      final first = await alice.encrypt(
        operationId: 'in-before',
        groupId: groupId,
        plaintext: utf8.encode('incoming before publication'),
      );
      await expectLater(
        bob.receive(groupId: groupId, message: first.message),
        throwsStateError,
      );
      stageToFail = '';
      expect(
        utf8.decode(
          (await bob.receive(
            groupId: groupId,
            message: first.message,
          )).plaintext!,
        ),
        'incoming before publication',
      );
      final second = await alice.encrypt(
        operationId: 'in-after',
        groupId: groupId,
        plaintext: utf8.encode('incoming after publication'),
      );
      stageToFail = 'journal_published';
      await expectLater(
        bob.receive(groupId: groupId, message: second.message),
        throwsStateError,
      );
      await bob.close();
      bob = await open('bob');
      expect(
        utf8.decode(
          (await bob.receive(
            groupId: groupId,
            message: second.message,
          )).plaintext!,
        ),
        'incoming after publication',
      );
    },
  );

  test(
    'serialized concurrent sends and reordering preserve ratchet messages',
    () async {
      final (alice, bob) = await pair();
      final messages = await Future.wait(
        List.generate(
          8,
          (i) => alice.encrypt(
            operationId: 'parallel-$i',
            groupId: groupId,
            plaintext: utf8.encode('message $i'),
          ),
        ),
      );
      for (final i in [7, 0, 4, 2, 6, 1, 3, 5]) {
        expect(
          utf8.decode(
            (await bob.receive(
              groupId: groupId,
              message: messages[i].message,
            )).plaintext!,
          ),
          'message $i',
        );
      }
      final duplicate = await Future.wait(
        List.generate(
          2,
          (_) => alice.encrypt(
            operationId: 'same-id',
            groupId: groupId,
            plaintext: utf8.encode('one operation'),
          ),
        ),
      );
      expect(duplicate[0].message, duplicate[1].message);
      await expectLater(
        NiosMlsClient.open(
          path: '${temp.path}/alice',
          storageKey: key,
          accountId: 'alice',
          deviceId: 'alice',
          authorizeDevice: (_, _, _) async => false,
        ),
        throwsA(
          isA<NiosMlsException>().having(
            (e) => e.code,
            'code',
            'storage_already_open',
          ),
        ),
      );
    },
  );

  test(
    'revocation blocks sending but still allows removing the revoked device',
    () async {
      final (alice, _) = await pair();
      final bobIndex = (await alice.members(
        groupId,
      )).singleWhere((m) => m.accountId == 'bob').leafIndex;
      trusted.remove('bob/bob');
      await expectLater(
        alice.encrypt(
          operationId: 'blocked-by-revoke',
          groupId: groupId,
          plaintext: utf8.encode('must not send'),
        ),
        throwsA(isA<NiosMlsException>()),
      );
      await alice.removeDevices(
        operationId: 'apply-revoke',
        groupId: groupId,
        leafIndices: [bobIndex],
      );
      expect(await alice.members(groupId), hasLength(1));
      await alice.encrypt(
        operationId: 'after-revoke',
        groupId: groupId,
        plaintext: utf8.encode('safe to send'),
      );
    },
  );

  test(
    'catalog revocation does not block a trusted removal commit on another device',
    () async {
      final (alice, bob) = await pair();
      final laptop = await open('alice-laptop');
      final add = await alice.addDevices(
        operationId: 'add-revocation-observer',
        groupId: groupId,
        keyPackages: [await laptop.createKeyPackage()],
      );
      await bob.receive(groupId: groupId, message: add.message);
      await laptop.join(welcome: add.welcome!);
      final bobIndex = (await alice.members(
        groupId,
      )).singleWhere((m) => m.accountId == 'bob').leafIndex;
      final waiting = await alice.encrypt(
        operationId: 'before-catalog-revoke',
        groupId: groupId,
        plaintext: utf8.encode('delayed but authorized sender'),
      );
      trusted.remove('bob/bob');
      final epochBefore = await laptop.epoch(groupId);
      await expectLater(
        laptop.receive(groupId: groupId, message: waiting.message),
        throwsA(isA<NiosMlsException>()),
      );
      expect(await laptop.epoch(groupId), epochBefore);
      final removal = await alice.removeDevices(
        operationId: 'propagate-catalog-revoke',
        groupId: groupId,
        leafIndices: [bobIndex],
      );
      await laptop.receive(groupId: groupId, message: removal.message);
      expect(await laptop.members(groupId), hasLength(2));
      expect(await laptop.epoch(groupId), await alice.epoch(groupId));
      final after = await alice.encrypt(
        operationId: 'after-propagated-revoke',
        groupId: groupId,
        plaintext: utf8.encode('trusted devices agree'),
      );
      expect(
        utf8.decode(
          (await laptop.receive(
            groupId: groupId,
            message: after.message,
          )).plaintext!,
        ),
        'trusted devices agree',
      );
    },
  );

  test(
    'close immediately fences new native mutations while an admitted transaction drains',
    () async {
      var (alice, _) = await pair();
      await alice.close();
      final entered = Completer<void>();
      final release = Completer<void>();
      alice = await open(
        'alice',
        fault: (stage) async {
          if (stage == 'native_state_closed' && !entered.isCompleted) {
            entered.complete();
            await release.future;
          }
        },
      );
      final preparing = alice.encrypt(
        operationId: 'closing-in-flight',
        groupId: groupId,
        plaintext: utf8.encode('persist before close completes'),
      );
      await entered.future;
      var drained = false;
      final closing = alice.close().then((_) {
        drained = true;
      });
      await expectLater(
        alice.encrypt(
          operationId: 'must-not-start-after-close',
          groupId: groupId,
          plaintext: utf8.encode('reject before touching native state'),
        ),
        throwsA(
          isA<NiosMlsException>().having((e) => e.code, 'code', 'closed'),
        ),
      );
      expect(drained, isFalse);
      release.complete();
      final saved = await preparing;
      await closing;
      alice = await open('alice');
      expect(
        (await alice.encrypt(
          operationId: 'closing-in-flight',
          groupId: groupId,
          plaintext: utf8.encode('persist before close completes'),
        )).message,
        saved.message,
      );
    },
  );
}
