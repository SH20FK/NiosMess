part of 'client.dart';

/// Opaque server group identifiers are unpadded base64url of native MLS IDs.
String mlsServerGroupId(List<int> groupId) =>
    base64UrlEncode(groupId).replaceAll('=', '');

final class MlsServerHead {
  MlsServerHead({
    required List<int> groupId,
    required this.epoch,
    required this.head,
    required this.coordinatorDeviceId,
    this.pendingOperationId,
  }) : groupId = _copy(groupId);
  final Uint8List groupId;
  final BigInt epoch;
  final String head;
  final String coordinatorDeviceId;
  final String? pendingOperationId;
}

final class MlsMembershipReservation {
  MlsMembershipReservation({
    required this.operationId,
    required this.token,
    required this.baseEpoch,
    required this.baseHead,
    required Map<String, List<int>> keyPackages,
  }) : keyPackages = Map.unmodifiable(
         keyPackages.map((device, bytes) => MapEntry(device, _copy(bytes))),
       );
  final String operationId;
  final String token;
  final BigInt baseEpoch;
  final String baseHead;
  final Map<String, Uint8List> keyPackages;
}

final class MlsCommitReceipt {
  const MlsCommitReceipt({
    required this.epoch,
    required this.head,
    required this.digest,
  });
  final BigInt epoch;
  final String head;
  final String digest;
}

final class MlsControlEvent {
  MlsControlEvent({
    required this.id,
    required List<int> groupId,
    required this.epoch,
    required this.kind,
    required List<int> payload,
  }) : groupId = _copy(groupId),
       payload = _copy(payload);
  final String id;
  final Uint8List groupId;
  final BigInt epoch;
  final String kind;
  final Uint8List payload;
}

/// An immutable, per-device application transport request. The destination
/// outbox MUST deduplicate deliveryId and check group/epoch permission again at
/// actual network send, including direct Iroh sends. A prior gate response is
/// not a timeless authorization for an offline queue.
final class MlsApplicationDelivery {
  MlsApplicationDelivery({
    required this.logicalOperationId,
    required this.deliveryId,
    required List<int> groupId,
    required this.epoch,
    required this.recipientDeviceId,
    required List<int> ciphertext,
  }) : groupId = _copy(groupId),
       ciphertext = _copy(ciphertext);
  final String logicalOperationId;
  final String deliveryId;
  final Uint8List groupId;
  final BigInt epoch;
  final String recipientDeviceId;
  final Uint8List ciphertext;

  Map<String, dynamic> get payload => {
    'type': 'nios.mls.application',
    'v': 1,
    'logical_id': logicalOperationId,
    'group': base64Encode(groupId),
    'epoch': epoch.toString(),
    'ciphertext': base64Encode(ciphertext),
  };

  String get linkSessionId =>
      'mls:${mlsServerGroupId(groupId)}:${epoch.toString()}';
}

/// The host supplies authenticated HTTPS/control and durable Link outbox APIs.
/// Network receipts must be checked against the exact bytes, not merely a 2xx.
abstract interface class MlsDeliveryApi {
  Future<MlsServerHead> groupHead(Uint8List groupId);

  Future<MlsMembershipReservation> reserve({
    required Uint8List groupId,
    required String operationId,
    required BigInt baseEpoch,
    required String baseHead,
    required List<String> addDevices,
    required List<String> removeDevices,
  });

  Future<MlsCommitReceipt> publishCommit({
    required MlsMembershipReservation reservation,
    required NiosMlsOutbound operation,
  });

  Future<void> ensureApplicationDeliveryAllowed({
    required Uint8List groupId,
    required BigInt epoch,
    required List<String> recipientDeviceIds,
  });

  /// Completes only once the immutable delivery is saved in the host outbox.
  /// It does not mean a recipient applied it or that the wire send is allowed.
  Future<void> enqueueApplication(MlsApplicationDelivery delivery);

  Future<void> confirmControl(String eventId);
}

final class MlsQueuedIntent {
  MlsQueuedIntent._(Map<String, dynamic> record)
    : operationId = record['id'] as String,
      kind = record['kind'] as String,
      phase = record['phase'] as String,
      errorCode = record['error'] as String?;
  final String operationId;
  final String kind;
  final String phase;
  final String? errorCode;
  bool get complete => phase == 'complete';
}

/// Persistent source-to-transport bridge. The encrypted MLS Hive journal owns
/// intents, reservation responses and recipient snapshots. Every cross-service
/// step is idempotent by permanent operation/delivery IDs; no pair of unrelated
/// writes is presented as one transaction.
///
/// A reservation never expires or transfers to another coordinator. If an epoch
/// changes after an application was prepared, delivery pauses with all saved
/// bytes intact. Rebase/cancellation and coordinator transfer are intentionally
/// absent until a separate journaled recovery protocol is implemented.
final class NiosMlsDeliveryCoordinator {
  NiosMlsDeliveryCoordinator._(this.client, this.api, this.faultHook);
  final NiosMlsClient client;
  final MlsDeliveryApi api;
  final MlsFaultHook? faultHook;
  static final Expando<NiosMlsDeliveryCoordinator> _owners = Expando();
  Future<void> _tail = Future.value();
  Future<void>? _closing;

  static NiosMlsDeliveryCoordinator attach({
    required NiosMlsClient client,
    required MlsDeliveryApi api,
    MlsFaultHook? faultHook,
  }) {
    client._checkOpen();
    if (_owners[client] != null) {
      throw const NiosMlsException('delivery_coordinator_already_attached');
    }
    final result = NiosMlsDeliveryCoordinator._(client, api, faultHook);
    _owners[client] = result;
    return result;
  }

  List<MlsQueuedIntent> get intents {
    client._checkOpen();
    return List.unmodifiable(_records.values.map(MlsQueuedIntent._));
  }

  Map<String, Map<String, dynamic>> get _records {
    final journal = client._state['delivery'] as Map?;
    if (journal == null) return {};
    if (journal['v'] != 1) {
      throw const NiosMlsException('unsupported_delivery_journal');
    }
    return (journal['intents'] as Map).map(
      (key, value) => MapEntry(key as String, value as Map<String, dynamic>),
    );
  }

  Future<T> _serial<T>(Future<T> Function() action) {
    if (_closing != null) {
      return Future.error(
        const NiosMlsException('delivery_coordinator_closed'),
      );
    }
    final result = _tail.then((_) {
      client._checkOpen();
      return action();
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> _save(Map<String, dynamic> intent) => client._serial(() async {
    final next = jsonDecode(jsonEncode(client._state)) as Map<String, dynamic>;
    final journal =
        next.putIfAbsent(
              'delivery',
              () => {'v': 1, 'intents': <String, dynamic>{}},
            )
            as Map;
    (journal['intents'] as Map)[intent['id']] = intent;
    try {
      await client._box.put('state', jsonEncode(next));
      await client._box.flush();
      client._state = next;
    } catch (_) {
      client._poisoned = true;
      rethrow;
    }
  });

  Future<void> enqueueAdd({
    required String operationId,
    required List<int> groupId,
    required List<String> deviceIds,
  }) => _enqueue(operationId, groupId, 'add', {'devices': _devices(deviceIds)});

  Future<void> enqueueRemove({
    required String operationId,
    required List<int> groupId,
    required List<String> deviceIds,
  }) => _enqueue(operationId, groupId, 'remove', {
    'devices': _devices(deviceIds),
  });

  Future<void> enqueueApplication({
    required String operationId,
    required List<int> groupId,
    required List<int> plaintext,
  }) {
    if (plaintext.length > 1024 * 1024) {
      throw ArgumentError('Use NiosStream for attachments');
    }
    return _enqueue(operationId, groupId, 'application', {
      'plaintext': base64Encode(plaintext),
    });
  }

  static List<String> _devices(List<String> devices) {
    final result = devices.map(_id).toSet().toList()..sort();
    if (result.isEmpty ||
        result.length > 64 ||
        result.length != devices.length) {
      throw ArgumentError('Expected 1..64 distinct devices');
    }
    return result;
  }

  Future<void> _enqueue(
    String operationId,
    List<int> groupId,
    String kind,
    Map<String, dynamic> data,
  ) {
    if (!RegExp(r'^[A-Za-z0-9._:@-]{1,160}$').hasMatch(operationId) ||
        groupId.isEmpty ||
        groupId.length > 128) {
      throw ArgumentError('Invalid delivery operation/group');
    }
    final record = <String, dynamic>{
      'id': operationId,
      'group': base64Encode(groupId),
      'kind': kind,
      ...data,
    };
    final fingerprint = _hash(utf8.encode(jsonEncode(record)));
    return _serial(() async {
      final old = _records[operationId];
      if (old != null) {
        if (old['fingerprint'] != fingerprint) {
          throw const NiosMlsException('delivery_operation_id_conflict');
        }
        return;
      }
      await _save({...record, 'fingerprint': fingerprint, 'phase': 'saved'});
      await faultHook?.call('delivery_intent_saved');
    });
  }

  Future<void> pump() => _serial(() async {
    for (final id in _records.keys.toList()) {
      var record = Map<String, dynamic>.from(_records[id]!);
      if (record['phase'] == 'complete') continue;
      try {
        if (record['kind'] == 'application') {
          await _application(record);
        } else {
          await _membership(record);
        }
      } catch (error) {
        // Flush uncertainty poisons the client; a fresh open must decide what
        // was committed, rather than overwrite a possibly published record.
        if (!client._poisoned && !client._closed) {
          record = Map<String, dynamic>.from(_records[id]!);
          await _save({
            ...record,
            'error': error is NiosMlsException
                ? error.code
                : 'mls_delivery_unavailable',
          });
        }
        rethrow;
      }
    }
  });

  Future<void> _membership(Map<String, dynamic> record) async {
    final groupId = _copy(base64Decode(record['group'] as String));
    final operationId = record['id'] as String;
    final adding = record['kind'] == 'add';
    final devices = (record['devices'] as List).cast<String>();
    if (record['baseEpoch'] == null) {
      final head = await api.groupHead(groupId);
      if (base64Encode(head.groupId) != record['group'] ||
          head.coordinatorDeviceId != client.deviceId ||
          (head.pendingOperationId != null &&
              head.pendingOperationId != operationId) ||
          await client.epoch(groupId) != head.epoch) {
        throw const NiosMlsException('mls_coordinator_head_sync_required');
      }
      record = {
        ...record,
        'baseEpoch': head.epoch.toString(),
        'baseHead': head.head,
      };
      await _save(record);
    }
    if (record['reservation'] == null) {
      final reservation = await api.reserve(
        groupId: groupId,
        operationId: operationId,
        baseEpoch: BigInt.parse(record['baseEpoch'] as String),
        baseHead: record['baseHead'] as String,
        addDevices: adding ? devices : const [],
        removeDevices: adding ? const [] : devices,
      );
      if (reservation.operationId != operationId ||
          reservation.baseEpoch.toString() != record['baseEpoch'] ||
          reservation.baseHead != record['baseHead'] ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(reservation.token) ||
          reservation.keyPackages.length != (adding ? devices.length : 0) ||
          (adding &&
              !reservation.keyPackages.keys.toSet().containsAll(devices))) {
        throw const NiosMlsException('mls_reservation_binding_mismatch');
      }
      record = {
        ...record,
        'reservation': {
          'token': reservation.token,
          'packages': reservation.keyPackages.map(
            (device, bytes) => MapEntry(device, base64Encode(bytes)),
          ),
        },
        'phase': 'reserved',
      };
      await _save(record);
      await faultHook?.call('delivery_reservation_saved');
    }
    final storedReservation = record['reservation'] as Map;
    final packages = (storedReservation['packages'] as Map).map(
      (device, bytes) =>
          MapEntry(device as String, base64Decode(bytes as String)),
    );
    final reservation = MlsMembershipReservation(
      operationId: operationId,
      token: storedReservation['token'] as String,
      baseEpoch: BigInt.parse(record['baseEpoch'] as String),
      baseHead: record['baseHead'] as String,
      keyPackages: packages,
    );
    var operation = client.outboundOperation(operationId);
    if (operation == null) {
      if (await client.epoch(groupId) != reservation.baseEpoch) {
        throw const NiosMlsException('mls_reservation_local_epoch_mismatch');
      }
      if (adding) {
        operation = await client.addDevices(
          operationId: operationId,
          groupId: groupId,
          keyPackages: devices.map((d) => packages[d]!).toList(),
          expectedDeviceIds: devices,
        );
      } else {
        final members = await client.membersForRemoval(groupId);
        final leaves = <int>[];
        for (final device in devices) {
          final matches = members.where((m) => m.deviceId == device).toList();
          if (device == client.deviceId || matches.length != 1) {
            throw const NiosMlsException('mls_removal_device_binding_mismatch');
          }
          leaves.add(matches.single.leafIndex);
        }
        operation = await client.removeDevices(
          operationId: operationId,
          groupId: groupId,
          leafIndices: leaves,
        );
      }
      await faultHook?.call('delivery_mls_saved');
    }
    if (base64Encode(operation.groupId) != record['group'] ||
        operation.kind != 'commit' ||
        operation.baseEpoch != reservation.baseEpoch ||
        operation.epoch != reservation.baseEpoch + BigInt.one) {
      throw const NiosMlsException('mls_saved_operation_epoch_mismatch');
    }
    final receipt = await api.publishCommit(
      reservation: reservation,
      operation: operation,
    );
    final digest = _hash(
      utf8.encode(
        jsonEncode([
          'nios-mls-commit',
          1,
          mlsServerGroupId(groupId),
          operationId,
          reservation.baseEpoch.toInt(),
          operation.epoch!.toInt(),
          base64Encode(operation.message),
          operation.welcome == null ? null : base64Encode(operation.welcome!),
        ]),
      ),
    );
    final head = _hash(
      utf8.encode(
        jsonEncode([
          'nios-mls-head',
          1,
          reservation.baseHead,
          digest,
          operation.epoch!.toInt(),
        ]),
      ),
    );
    if (receipt.digest != digest ||
        receipt.head != head ||
        receipt.epoch != operation.epoch) {
      throw const NiosMlsException('mls_commit_receipt_mismatch');
    }
    await faultHook?.call('delivery_transport_saved');
    await client.acknowledge(operationId);
    await faultHook?.call('delivery_mls_acknowledged');
    await _save({...record, 'phase': 'complete', 'error': null});
  }

  Future<void> _application(Map<String, dynamic> record) async {
    final groupId = _copy(base64Decode(record['group'] as String));
    final id = record['id'] as String;
    if (record['epoch'] == null) {
      final head = await api.groupHead(groupId);
      if (base64Encode(head.groupId) != record['group'] ||
          head.pendingOperationId != null ||
          await client.epoch(groupId) != head.epoch) {
        throw const NiosMlsException('mls_control_sync_required');
      }
      final members = await client.members(groupId);
      final devices = members.map((m) => m.deviceId).toSet();
      if (devices.length != members.length ||
          !devices.remove(client.deviceId)) {
        throw const NiosMlsException('mls_member_identity_ambiguous');
      }
      if (devices.isEmpty) {
        throw const NiosMlsException('mls_no_recipients');
      }
      record = {
        ...record,
        'epoch': head.epoch.toString(),
        'recipients': devices.toList()..sort(),
        'savedDeliveries': <String>[],
      };
      await _save(record);
    }
    final epoch = BigInt.parse(record['epoch'] as String);
    final recipients = (record['recipients'] as List).cast<String>();
    // Never reinterpret a prepared intent under another epoch, including after
    // restart. This call must also be repeated by the actual transport worker.
    await api.ensureApplicationDeliveryAllowed(
      groupId: groupId,
      epoch: epoch,
      recipientDeviceIds: recipients,
    );
    var operation = client.outboundOperation(id);
    if (operation == null) {
      if (await client.epoch(groupId) != epoch) {
        throw const NiosMlsException('mls_epoch_delivery_paused');
      }
      operation = await client.encrypt(
        operationId: id,
        groupId: groupId,
        plaintext: base64Decode(record['plaintext'] as String),
      );
      await faultHook?.call('delivery_mls_saved');
    }
    if (operation.kind != 'application' ||
        base64Encode(operation.groupId) != record['group'] ||
        operation.baseEpoch != epoch ||
        operation.epoch != epoch) {
      throw const NiosMlsException('mls_saved_operation_epoch_mismatch');
    }
    final saved = (record['savedDeliveries'] as List).cast<String>().toSet();
    for (final recipient in recipients) {
      final deliveryId = _hash(
        utf8.encode(
          jsonEncode([
            'nios-mls-link-delivery',
            1,
            record['group'],
            id,
            epoch.toString(),
            recipient,
          ]),
        ),
      );
      if (saved.contains(deliveryId)) continue;
      await api.ensureApplicationDeliveryAllowed(
        groupId: groupId,
        epoch: epoch,
        recipientDeviceIds: [recipient],
      );
      await api.enqueueApplication(
        MlsApplicationDelivery(
          logicalOperationId: id,
          deliveryId: deliveryId,
          groupId: groupId,
          epoch: epoch,
          recipientDeviceId: recipient,
          ciphertext: operation.message,
        ),
      );
      await faultHook?.call('delivery_transport_saved');
      saved.add(deliveryId);
      record = {
        ...record,
        'savedDeliveries': saved.toList(),
        'phase': 'bridged',
      };
      await _save(record);
    }
    await client.acknowledge(id);
    await faultHook?.call('delivery_mls_acknowledged');
    await _save({...record, 'phase': 'complete', 'error': null});
  }

  /// The host passes events in server order and confirms the cursor only after
  /// this method. Native receive/Welcome replay is itself durable/idempotent.
  Future<void> processControl(MlsControlEvent event) => _serial(() async {
    if (event.kind == 'welcome') {
      await client.join(
        welcome: event.payload,
        expectedGroupId: event.groupId,
        expectedEpoch: event.epoch,
      );
    } else if (event.kind == 'commit') {
      await client.receive(
        groupId: event.groupId,
        message: event.payload,
        expectedEpoch: event.epoch,
      );
    } else {
      throw const NiosMlsException('unsupported_mls_control_event');
    }
    await faultHook?.call('delivery_control_applied');
    await api.confirmControl(event.id);
  });

  /// Close the bridge before closing its client. Already running work drains;
  /// native state and pending intents remain available after a normal shutdown.
  Future<void> close() {
    if (_closing != null) return _closing!;
    return _closing = _tail.then((_) {
      _owners[client] = null;
    });
  }
}
