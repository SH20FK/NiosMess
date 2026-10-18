import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:nios_mls/nios_mls.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

String _hash(Object value) =>
    sha256.convert(utf8.encode(jsonEncode(value))).toString();

/// A deterministic delivery API for interruption tests. MLS itself remains the
/// real native OpenMLS engine; FastAPI/SQLite wire contracts have separate tests.
class _Server {
  _Server(this.group) {
    head = _hash(['nios-mls-group', 1, mlsServerGroupId(group), 'alice']);
  }
  final Uint8List group;
  BigInt epoch = BigInt.zero;
  late String head;
  bool offline = false;
  final Map<String, Uint8List> packages = {};
  final Set<String> members = {'alice'};
  final Map<String, MlsMembershipReservation> reservations = {};
  final Map<String, MlsCommitReceipt> commits = {};
  final Map<String, NiosMlsOutbound> commitBytes = {};
  final Map<String, MlsApplicationDelivery> applications = {};
  final Set<String> confirmed = {};
  String? pending;
  int reserveCalls = 0;
  int applicationCalls = 0;
  int confirms = 0;
  bool loseCommitReply = false;
  bool loseApplicationReply = false;
}

class _Api implements MlsDeliveryApi {
  _Api(this.server, this.device);
  final _Server server;
  final String device;

  void _network() {
    if (server.offline) throw const NiosMlsException('test_offline');
  }

  @override
  Future<MlsServerHead> groupHead(Uint8List groupId) async {
    _network();
    return MlsServerHead(
      groupId: server.group,
      epoch: server.epoch,
      head: server.head,
      coordinatorDeviceId: 'alice',
      pendingOperationId: server.pending,
    );
  }

  @override
  Future<MlsMembershipReservation> reserve({
    required Uint8List groupId,
    required String operationId,
    required BigInt baseEpoch,
    required String baseHead,
    required List<String> addDevices,
    required List<String> removeDevices,
  }) async {
    _network();
    server.reserveCalls++;
    if (server.reservations.containsKey(operationId)) {
      return server.reservations[operationId]!;
    }
    if (device != 'alice' ||
        server.pending != null ||
        baseEpoch != server.epoch ||
        baseHead != server.head) {
      throw const NiosMlsException('test_reservation_conflict');
    }
    final result = MlsMembershipReservation(
      operationId: operationId,
      token: List.filled(64, 'a').join(),
      baseEpoch: baseEpoch,
      baseHead: baseHead,
      keyPackages: {for (final d in addDevices) d: server.packages[d]!},
    );
    server.reservations[operationId] = result;
    server.pending = operationId;
    return result;
  }

  @override
  Future<MlsCommitReceipt> publishCommit({
    required MlsMembershipReservation reservation,
    required NiosMlsOutbound operation,
  }) async {
    _network();
    final digest = _hash([
      'nios-mls-commit',
      1,
      mlsServerGroupId(operation.groupId),
      operation.operationId,
      reservation.baseEpoch.toInt(),
      operation.epoch!.toInt(),
      base64Encode(operation.message),
      operation.welcome == null ? null : base64Encode(operation.welcome!),
    ]);
    final old = server.commits[operation.operationId];
    if (old != null) {
      if (old.digest != digest) {
        throw const NiosMlsException('test_commit_collision');
      }
      return old;
    }
    if (server.pending != operation.operationId ||
        server.epoch != reservation.baseEpoch) {
      throw const NiosMlsException('test_invalid_commit');
    }
    final head = _hash([
      'nios-mls-head',
      1,
      reservation.baseHead,
      digest,
      operation.epoch!.toInt(),
    ]);
    final receipt = MlsCommitReceipt(
      epoch: operation.epoch!,
      head: head,
      digest: digest,
    );
    server.commits[operation.operationId] = receipt;
    server.commitBytes[operation.operationId] = operation;
    server.members.addAll(reservation.keyPackages.keys);
    server.epoch = receipt.epoch;
    server.head = head;
    server.pending = null;
    if (server.loseCommitReply) {
      server.loseCommitReply = false;
      throw const NiosMlsException('test_reply_lost');
    }
    return receipt;
  }

  @override
  Future<void> ensureApplicationDeliveryAllowed({
    required Uint8List groupId,
    required BigInt epoch,
    required List<String> recipientDeviceIds,
  }) async {
    _network();
    if (server.epoch != epoch ||
        server.pending != null ||
        !server.members.contains(device) ||
        !server.members.containsAll(recipientDeviceIds)) {
      throw const NiosMlsException('mls_epoch_delivery_paused');
    }
  }

  @override
  Future<void> enqueueApplication(MlsApplicationDelivery delivery) async {
    _network();
    server.applicationCalls++;
    final old = server.applications[delivery.deliveryId];
    if (old != null &&
        base64Encode(old.ciphertext) != base64Encode(delivery.ciphertext)) {
      throw const NiosMlsException('test_delivery_id_collision');
    }
    server.applications[delivery.deliveryId] = delivery;
    if (server.loseApplicationReply) {
      server.loseApplicationReply = false;
      throw const NiosMlsException('test_reply_lost');
    }
  }

  @override
  Future<void> confirmControl(String eventId) async {
    _network();
    server.confirms++;
    server.confirmed.add(eventId);
  }
}

void main() {
  late Directory directory;
  late Map<String, Uint8List> trusted;
  late List<NiosMlsClient> clients;
  late List<NiosMlsDeliveryCoordinator> bridges;
  final group = Uint8List.fromList(utf8.encode('durable-mls-bridge'));
  final key = List.generate(32, (i) => i + 1);

  Future<NiosMlsClient> open(String device) async {
    final client = await NiosMlsClient.open(
      path: '${directory.path}/$device',
      storageKey: key,
      accountId: device,
      deviceId: device,
      authorizeDevice: (account, deviceId, signingKey) async =>
          base64Encode(trusted[deviceId] ?? []) == base64Encode(signingKey),
    );
    trusted[device] = client.signingPublicKey;
    clients.add(client);
    return client;
  }

  NiosMlsDeliveryCoordinator attach(
    NiosMlsClient client,
    _Server server, {
    MlsFaultHook? fault,
  }) {
    final bridge = NiosMlsDeliveryCoordinator.attach(
      client: client,
      api: _Api(server, client.deviceId),
      faultHook: fault,
    );
    bridges.add(bridge);
    return bridge;
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('nios-mls-delivery-');
    trusted = {};
    clients = [];
    bridges = [];
  });
  tearDown(() async {
    for (final bridge in bridges) {
      await bridge.close();
    }
    for (final client in clients) {
      await client.close();
    }
    await directory.delete(recursive: true);
  });

  for (final boundary in [
    'delivery_intent_saved',
    'delivery_reservation_saved',
    'delivery_mls_saved',
    'delivery_transport_saved',
    'delivery_mls_acknowledged',
  ]) {
    test(
      'membership recovery at $boundary preserves one reservation and exact commit',
      () async {
        var alice = await open('alice');
        final bob = await open('bob');
        await alice.createGroup(groupId: group);
        final server = _Server(group)
          ..packages['bob'] = await bob.createKeyPackage();
        var fired = false;
        var bridge = attach(
          alice,
          server,
          fault: (stage) async {
            if (!fired && stage == boundary) {
              fired = true;
              throw StateError('simulated termination');
            }
          },
        );
        if (boundary == 'delivery_intent_saved') {
          await expectLater(
            bridge.enqueueAdd(
              operationId: 'add-bob',
              groupId: group,
              deviceIds: ['bob'],
            ),
            throwsStateError,
          );
        } else {
          await bridge.enqueueAdd(
            operationId: 'add-bob',
            groupId: group,
            deviceIds: ['bob'],
          );
          await expectLater(bridge.pump(), throwsStateError);
        }
        final original = alice.outboundOperation('add-bob')?.message;
        await bridge.close();
        await alice.close();
        alice = await open('alice');
        bridge = attach(alice, server);
        await bridge.pump();
        await bridge.pump();
        expect(bridge.intents.single.complete, isTrue);
        expect(server.commits, hasLength(1));
        expect(server.reservations, hasLength(1));
        final saved = alice.outboundOperation('add-bob')!;
        expect(saved.baseEpoch, BigInt.zero);
        expect(saved.epoch, BigInt.one);
        if (original != null) expect(saved.message, original);
        await bob.join(
          welcome: saved.welcome!,
          expectedGroupId: group,
          expectedEpoch: BigInt.one,
        );
        expect(await bob.epoch(group), BigInt.one);
      },
    );
  }

  Future<(_Server, NiosMlsClient, NiosMlsClient, NiosMlsDeliveryCoordinator)>
  pair() async {
    final alice = await open('alice');
    final bob = await open('bob');
    await alice.createGroup(groupId: group);
    final server = _Server(group)
      ..packages['bob'] = await bob.createKeyPackage();
    final bridge = attach(alice, server);
    await bridge.enqueueAdd(
      operationId: 'add-bob',
      groupId: group,
      deviceIds: ['bob'],
    );
    server.loseCommitReply = true;
    await expectLater(bridge.pump(), throwsA(isA<NiosMlsException>()));
    await bridge.pump();
    await bob.join(welcome: server.commitBytes['add-bob']!.welcome!);
    return (server, alice, bob, bridge);
  }

  test(
    'offline intent survives reopen and lost durable outbox response deduplicates',
    () async {
      var (server, alice, bob, bridge) = await pair();
      server.offline = true;
      await bridge.enqueueApplication(
        operationId: 'important',
        groupId: group,
        plaintext: utf8.encode('text survives before encryption or networking'),
      );
      await expectLater(bridge.pump(), throwsA(isA<NiosMlsException>()));
      expect(alice.outboundOperation('important'), isNull);
      await bridge.close();
      await alice.close();
      alice = await open('alice');
      bridge = attach(alice, server);
      server.offline = false;
      server.loseApplicationReply = true;
      await expectLater(bridge.pump(), throwsA(isA<NiosMlsException>()));
      final saved = alice.outboundOperation('important')!;
      expect(saved.baseEpoch, BigInt.one);
      expect(saved.epoch, BigInt.one);
      await bridge.close();
      await alice.close();
      alice = await open('alice');
      bridge = attach(alice, server);
      await bridge.pump();
      expect(server.applications, hasLength(1));
      expect(server.applicationCalls, 2);
      expect(alice.outboundOperation('important')!.message, saved.message);
      expect(
        utf8.decode(
          (await bob.receive(
            groupId: group,
            message: server.applications.values.single.ciphertext,
          )).plaintext!,
        ),
        'text survives before encryption or networking',
      );
      await expectLater(
        bridge.enqueueApplication(
          operationId: 'important',
          groupId: group,
          plaintext: utf8.encode('different'),
        ),
        throwsA(isA<NiosMlsException>()),
      );
    },
  );

  test('old epoch application pauses intact when membership changes', () async {
    final (server, alice, _, bridge) = await pair();
    await bridge.enqueueApplication(
      operationId: 'before-removal',
      groupId: group,
      plaintext: utf8.encode('keep this text'),
    );
    server.loseApplicationReply = true;
    await expectLater(bridge.pump(), throwsA(isA<NiosMlsException>()));
    final ciphertext = alice.outboundOperation('before-removal')!.message;
    server.epoch = BigInt.two;
    server.members.remove('bob');
    await expectLater(bridge.pump(), throwsA(isA<NiosMlsException>()));
    expect(alice.outboundOperation('before-removal')!.message, ciphertext);
    expect(
      alice.pendingOperations.any((o) => o.operationId == 'before-removal'),
      isTrue,
    );
    expect(bridge.intents.last.errorCode, 'mls_epoch_delivery_paused');
    expect(server.applicationCalls, 1);
  });

  test(
    'Welcome applied before interruption replays after restart before confirm',
    () async {
      final (server, alice, bob, _) = await pair();
      // New device and a separate Welcome: this exercises native first join.
      final carol = await open('carol');
      final add = await alice.addDevices(
        operationId: 'manual-add-carol',
        groupId: group,
        keyPackages: [await carol.createKeyPackage()],
      );
      var failed = false;
      var bridge = attach(
        carol,
        server,
        fault: (stage) async {
          if (!failed && stage == 'delivery_control_applied') {
            failed = true;
            throw StateError('termination before confirm');
          }
        },
      );
      final event = MlsControlEvent(
        id: 'welcome-carol',
        groupId: group,
        epoch: BigInt.two,
        kind: 'welcome',
        payload: add.welcome!,
      );
      await expectLater(bridge.processControl(event), throwsStateError);
      expect(server.confirmed, isEmpty);
      await bridge.close();
      await carol.close();
      final reopened = await open('carol');
      bridge = attach(reopened, server);
      await bridge.processControl(event);
      await bridge.processControl(event);
      expect(server.confirmed, {'welcome-carol'});
      expect(await reopened.epoch(group), BigInt.two);
      // An incorrect transport epoch must not advance an existing member.
      final bobBridge = attach(bob, server);
      await expectLater(
        bobBridge.processControl(
          MlsControlEvent(
            id: 'wrong-epoch',
            groupId: group,
            epoch: BigInt.from(99),
            kind: 'commit',
            payload: add.message,
          ),
        ),
        throwsA(isA<NiosMlsException>()),
      );
      expect(await bob.epoch(group), BigInt.one);
    },
  );

  test(
    'wrong key-package device binding rejects native state publication',
    () async {
      final alice = await open('alice');
      final bob = await open('bob');
      final carol = await open('carol');
      await alice.createGroup(groupId: group);
      final server = _Server(group)
        ..packages['bob'] = await carol.createKeyPackage();
      final bridge = attach(alice, server);
      await bridge.enqueueAdd(
        operationId: 'add-bob',
        groupId: group,
        deviceIds: ['bob'],
      );
      await expectLater(bridge.pump(), throwsA(isA<NiosMlsException>()));
      expect(await alice.epoch(group), BigInt.zero);
      expect(alice.outboundOperation('add-bob'), isNull);
      expect(server.commits, isEmpty);
      await expectLater(bob.isActive(group), throwsA(anything));
    },
  );
}
