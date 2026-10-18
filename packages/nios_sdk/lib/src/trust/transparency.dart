import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:hive/hive.dart';
import 'package:universal_io/io.dart';
import '../link/journal_guard.dart';

import 'merkle.dart';

final class TransparencyException implements Exception {
  const TransparencyException(this.code);
  final String code;
  @override
  String toString() => 'TransparencyException($code)';
}

Uint8List _bytes(List<int> bytes, int length) {
  if (bytes.length != length || bytes.any((b) => b < 0 || b > 255)) {
    throw ArgumentError('Expected $length bytes');
  }
  return Uint8List.fromList(bytes).asUnmodifiableView();
}

String _id(String value) {
  if (!RegExp(r'^[A-Za-z0-9._:@/-]{1,160}$').hasMatch(value)) {
    throw ArgumentError('Invalid identifier');
  }
  return value;
}

void _counter(int value) {
  if (value < 0 || value > 9007199254740991) {
    throw ArgumentError('Counter outside canonical integer range');
  }
}

Uint8List _encode(List<Object?> fields) =>
    Uint8List.fromList(utf8.encode(jsonEncode(fields)));

/// The identical domain-separated bytes are signed by the log and witnesses.
/// Witnesses must independently validate append-only history before signing.
final class LogCheckpoint {
  LogCheckpoint({
    required String logId,
    required this.size,
    required List<int> root,
    required this.issuedAtMilliseconds,
  }) : logId = _id(logId),
       root = _bytes(root, 32) {
    _counter(size);
    _counter(issuedAtMilliseconds);
  }
  final String logId;
  final int size;
  final Uint8List root;
  final int issuedAtMilliseconds;
  Uint8List get signingBytes => _encode([
    'nios-key-log-checkpoint',
    1,
    logId,
    size,
    base64Encode(root),
    issuedAtMilliseconds,
  ]);
  Map<String, Object?> toJson() => {
    'log': logId,
    'size': size,
    'root': base64Encode(root),
    'time': issuedAtMilliseconds,
  };
  factory LogCheckpoint.fromJson(Map<String, dynamic> json) => LogCheckpoint(
    logId: json['log'] as String,
    size: json['size'] as int,
    root: base64Decode(json['root'] as String),
    issuedAtMilliseconds: json['time'] as int,
  );
}

final class WitnessSignature {
  WitnessSignature({required String witnessId, required List<int> signature})
    : witnessId = _id(witnessId),
      signature = _bytes(signature, 64);
  final String witnessId;
  final Uint8List signature;
}

final class SignedLogCheckpoint {
  SignedLogCheckpoint({
    required this.checkpoint,
    required List<int> logSignature,
    List<WitnessSignature> witnesses = const [],
  }) : logSignature = _bytes(logSignature, 64),
       witnesses = List.unmodifiable(witnesses) {
    if (witnesses.length > 32) throw ArgumentError('Too many witnesses');
  }
  final LogCheckpoint checkpoint;
  final Uint8List logSignature;
  final List<WitnessSignature> witnesses;
}

Future<SignedLogCheckpoint> signLogCheckpoint(
  LogCheckpoint checkpoint,
  SimpleKeyPair logKey, {
  Map<String, SimpleKeyPair> witnessKeys = const {},
}) async {
  final algorithm = Ed25519();
  final signature = await algorithm.sign(
    checkpoint.signingBytes,
    keyPair: logKey,
  );
  final witnesses = <WitnessSignature>[];
  for (final entry in witnessKeys.entries) {
    witnesses.add(
      WitnessSignature(
        witnessId: entry.key,
        signature: (await algorithm.sign(
          checkpoint.signingBytes,
          keyPair: entry.value,
        )).bytes,
      ),
    );
  }
  return SignedLogCheckpoint(
    checkpoint: checkpoint,
    logSignature: signature.bytes,
    witnesses: witnesses,
  );
}

enum DeviceKeyAction { enroll, revoke }

/// A continuous per-account chain, authorized by an externally pinned identity
/// signing key. Revoked device records remain as tombstones; keys are never
/// silently replaced. An identity-key rotation requires explicit re-enrollment.
final class DeviceKeyStatement {
  DeviceKeyStatement({
    required String accountId,
    required String deviceId,
    required this.revision,
    required this.action,
    required List<int> deviceKey,
    required List<int> previousStatementHash,
    required this.createdAtMilliseconds,
    List<int>? linkSigningKey,
    List<int>? transportEndpointKey,
  }) : accountId = _id(accountId),
       deviceId = _id(deviceId),
       deviceKey = _bytes(deviceKey, 32),
       linkSigningKey = linkSigningKey == null
           ? null
           : _bytes(linkSigningKey, 32),
       transportEndpointKey = transportEndpointKey == null
           ? null
           : _bytes(transportEndpointKey, 32),
       previousStatementHash = _bytes(previousStatementHash, 32) {
    _counter(revision);
    if (revision < 1) throw ArgumentError('Revisions start at one');
    _counter(createdAtMilliseconds);
    if ((linkSigningKey == null) != (transportEndpointKey == null)) {
      throw ArgumentError(
        'Link signing and transport endpoint keys form one binding',
      );
    }
  }
  final String accountId;
  final String deviceId;
  final int revision;
  final DeviceKeyAction action;
  final Uint8List deviceKey;

  /// Separately provisioned Ed25519 key for Link operations and ACKs. MLS
  /// exporters are group secrets and cannot authenticate an individual device.
  final Uint8List? linkSigningKey;

  /// Native transport's Ed25519 endpoint identity, authorized by this account.
  final Uint8List? transportEndpointKey;
  final Uint8List previousStatementHash;
  final int createdAtMilliseconds;
  Uint8List get signingBytes => _encode([
    'nios-device-key-statement',
    linkSigningKey == null ? 1 : 2,
    accountId,
    deviceId,
    revision,
    action.name,
    base64Encode(deviceKey),
    base64Encode(previousStatementHash),
    createdAtMilliseconds,
    if (linkSigningKey != null) base64Encode(linkSigningKey!),
    if (transportEndpointKey != null) base64Encode(transportEndpointKey!),
  ]);
  Map<String, Object?> toJson() => {
    'account': accountId,
    'device': deviceId,
    'revision': revision,
    'action': action.name,
    'key': base64Encode(deviceKey),
    'previous': base64Encode(previousStatementHash),
    'time': createdAtMilliseconds,
    if (linkSigningKey != null) 'linkSigningKey': base64Encode(linkSigningKey!),
    if (transportEndpointKey != null)
      'transportEndpointKey': base64Encode(transportEndpointKey!),
  };
  factory DeviceKeyStatement.fromJson(Map<String, dynamic> value) =>
      DeviceKeyStatement(
        accountId: value['account'] as String,
        deviceId: value['device'] as String,
        revision: value['revision'] as int,
        action: DeviceKeyAction.values.byName(value['action'] as String),
        deviceKey: base64Decode(value['key'] as String),
        previousStatementHash: base64Decode(value['previous'] as String),
        createdAtMilliseconds: value['time'] as int,
        linkSigningKey: value['linkSigningKey'] == null
            ? null
            : base64Decode(value['linkSigningKey'] as String),
        transportEndpointKey: value['transportEndpointKey'] == null
            ? null
            : base64Decode(value['transportEndpointKey'] as String),
      );
}

final class AuthorizedDeviceStatement {
  AuthorizedDeviceStatement({
    required this.statement,
    required List<int> signature,
  }) : signature = _bytes(signature, 64);
  final DeviceKeyStatement statement;
  final Uint8List signature;
  Uint8List get logEntry => _encode([
    'nios-authorized-device',
    1,
    base64Encode(statement.signingBytes),
    base64Encode(signature),
  ]);
  Uint8List get hash => merkleLeafHash(logEntry);
  static Future<AuthorizedDeviceStatement> sign(
    DeviceKeyStatement statement,
    SimpleKeyPair identity,
  ) async => AuthorizedDeviceStatement(
    statement: statement,
    signature: (await Ed25519().sign(
      statement.signingBytes,
      keyPair: identity,
    )).bytes,
  );
}

final class ProvenDeviceStatement {
  ProvenDeviceStatement({
    required this.entry,
    required this.leafIndex,
    required List<List<int>> inclusionProof,
  }) : inclusionProof = List.unmodifiable(
         inclusionProof.map((n) => _bytes(n, 32)),
       ) {
    _counter(leafIndex);
    if (inclusionProof.length > 64) throw ArgumentError('Proof too long');
  }
  final AuthorizedDeviceStatement entry;
  final int leafIndex;
  final List<Uint8List> inclusionProof;
}

/// Storage receives one complete snapshot per transaction. The implementation
/// must atomically replace it and encrypt it at rest; callers supply its key.
abstract interface class TransparencyStateStore {
  Future<Map<String, dynamic>?> read();
  Future<void> write(Map<String, dynamic> value);
}

/// Account-isolated, encrypted Hive snapshot. Do not reuse a box name between
/// accounts or share a single database across concurrent client instances.
final class HiveTransparencyStateStore implements TransparencyStateStore {
  HiveTransparencyStateStore._(this._box);
  final Box<String> _box;
  static final Set<String> _openingNames = {};
  static Future<HiveTransparencyStateStore> open({
    required String path,
    required String boxName,
    required List<int> encryptionKey,
  }) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,120}$').hasMatch(boxName)) {
      throw ArgumentError('Invalid encrypted box name');
    }
    _bytes(encryptionKey, 32);
    final reservation = boxName.toLowerCase();
    if (Hive.isBoxOpen(boxName) || !_openingNames.add(reservation)) {
      throw const TransparencyException('storage_already_open');
    }
    try {
      await Directory(path).create(recursive: true);
      // Hive recovery must never truncate an existing journal on a wrong key.
      await verifyJournalKey(
        directory: path,
        name: boxName,
        key: encryptionKey,
      );
      final box = await Hive.openBox<String>(
        boxName,
        path: path,
        encryptionCipher: HiveAesCipher(encryptionKey),
      );
      return HiveTransparencyStateStore._(box);
    } finally {
      _openingNames.remove(reservation);
    }
  }

  @override
  Future<Map<String, dynamic>?> read() async {
    final encoded = _box.get('snapshot');
    return encoded == null ? null : jsonDecode(encoded) as Map<String, dynamic>;
  }

  @override
  Future<void> write(Map<String, dynamic> value) async {
    await _box.put('snapshot', jsonEncode(value));
    await _box.flush();
  }

  Future<void> close() => _box.close();
}

final class TrustedDeviceKey {
  TrustedDeviceKey._({
    required this.deviceId,
    required List<int> publicKey,
    required this.revoked,
    required this.revision,
    List<int>? linkSigningKey,
    List<int>? transportEndpointKey,
  }) : publicKey = _bytes(publicKey, 32),
       linkSigningKey = linkSigningKey == null
           ? null
           : _bytes(linkSigningKey, 32),
       transportEndpointKey = transportEndpointKey == null
           ? null
           : _bytes(transportEndpointKey, 32);
  final String deviceId;
  final Uint8List publicKey;
  final bool revoked;
  final int revision;
  final Uint8List? linkSigningKey;
  final Uint8List? transportEndpointKey;
}

final class _Account {
  _Account(
    this.identity, {
    this.revision = 0,
    List<int>? lastHash,
    this.lastLeaf = -1,
    this.lastTime = 0,
    Map<String, TrustedDeviceKey>? devices,
  }) : lastHash = lastHash ?? Uint8List(32),
       devices = devices ?? {};
  final Uint8List identity;
  int revision;
  List<int> lastHash;
  int lastLeaf;
  int lastTime;
  final Map<String, TrustedDeviceKey> devices;
  _Account copy() => _Account(
    identity,
    revision: revision,
    lastHash: lastHash,
    lastLeaf: lastLeaf,
    lastTime: lastTime,
    devices: {...devices},
  );
  Map<String, Object?> toJson() => {
    'identity': base64Encode(identity),
    'revision': revision,
    'hash': base64Encode(lastHash),
    'leaf': lastLeaf,
    'time': lastTime,
    'devices': {
      for (final d in devices.values)
        d.deviceId: {
          'key': base64Encode(d.publicKey),
          'revoked': d.revoked,
          'revision': d.revision,
          if (d.linkSigningKey != null)
            'linkSigningKey': base64Encode(d.linkSigningKey!),
          if (d.transportEndpointKey != null)
            'transportEndpointKey': base64Encode(d.transportEndpointKey!),
        },
    },
  };
  factory _Account.fromJson(Map<String, dynamic> value) {
    final devices = value['devices'] as Map<String, dynamic>;
    return _Account(
      _bytes(base64Decode(value['identity'] as String), 32),
      revision: value['revision'] as int,
      lastHash: _bytes(base64Decode(value['hash'] as String), 32),
      lastLeaf: value['leaf'] as int,
      lastTime: value['time'] as int,
      devices: {
        for (final entry in devices.entries)
          entry.key: TrustedDeviceKey._(
            deviceId: entry.key,
            publicKey: base64Decode((entry.value as Map)['key'] as String),
            revoked: (entry.value as Map)['revoked'] as bool,
            revision: (entry.value as Map)['revision'] as int,
            linkSigningKey: (entry.value as Map)['linkSigningKey'] == null
                ? null
                : base64Decode(
                    (entry.value as Map)['linkSigningKey'] as String,
                  ),
            transportEndpointKey:
                (entry.value as Map)['transportEndpointKey'] == null
                ? null
                : base64Decode(
                    (entry.value as Map)['transportEndpointKey'] as String,
                  ),
          ),
      },
    );
  }
}

/// Stateful verifier. Pins survive restarts; signatures cannot replace a known
/// account key. Consistency proofs are always relative to the last committed
/// checkpoint, including checkpoint-only gossip updates. Witnesses must be
/// independent; a quorum of copies operated by the log is not independence.
///
/// An append-only log proves history, not that an account result is the newest
/// possible result. Detecting withheld updates requires monitoring/gossip and
/// an application freshness policy. This API never claims proof of identity.
final class KeyTransparencyClient {
  KeyTransparencyClient._({
    required this.logId,
    required this.logPublicKey,
    required this.witnessPublicKeys,
    required this.witnessQuorum,
    required this.store,
    required this.maximumCheckpointAge,
    required this.maximumClockSkew,
    required this.now,
  });
  final String logId;
  final Uint8List logPublicKey;
  final Map<String, Uint8List> witnessPublicKeys;
  final int witnessQuorum;
  final TransparencyStateStore store;
  final Duration maximumCheckpointAge;
  final Duration maximumClockSkew;
  final DateTime Function() now;
  LogCheckpoint? _checkpoint;
  Map<String, _Account> _accounts = {};
  Future<void> _tail = Future.value();
  bool _storageFault = false;
  bool _closed = false;
  Future<void>? _closeFuture;

  static Future<KeyTransparencyClient> open({
    required String logId,
    required List<int> logPublicKey,
    required Map<String, List<int>> witnessPublicKeys,
    required int witnessQuorum,
    required TransparencyStateStore store,
    Duration maximumCheckpointAge = const Duration(days: 7),
    Duration maximumClockSkew = const Duration(minutes: 5),
    DateTime Function()? now,
  }) async {
    _id(logId);
    final pinnedLogKey = _bytes(logPublicKey, 32);
    if (witnessPublicKeys.length > 32 ||
        witnessQuorum < 1 ||
        witnessQuorum > witnessPublicKeys.length ||
        maximumCheckpointAge.isNegative ||
        maximumClockSkew.isNegative) {
      throw ArgumentError('Invalid independent witness/freshness policy');
    }
    final keys = <String, Uint8List>{};
    final uniqueKeys = <String>{base64Encode(pinnedLogKey)};
    for (final entry in witnessPublicKeys.entries) {
      final key = _bytes(entry.value, 32);
      if (!uniqueKeys.add(base64Encode(key))) {
        throw ArgumentError('Witnesses must have independent distinct keys');
      }
      keys[_id(entry.key)] = key;
    }
    final client = KeyTransparencyClient._(
      logId: logId,
      logPublicKey: pinnedLogKey,
      witnessPublicKeys: Map.unmodifiable(keys),
      witnessQuorum: witnessQuorum,
      store: store,
      maximumCheckpointAge: maximumCheckpointAge,
      maximumClockSkew: maximumClockSkew,
      now: now ?? DateTime.now,
    );
    final snapshot = await store.read();
    if (snapshot != null) {
      if (snapshot['version'] != 1 ||
          snapshot['log'] != logId ||
          snapshot['logKey'] != base64Encode(pinnedLogKey)) {
        throw const TransparencyException('storage_context_mismatch');
      }
      final checkpoint = snapshot['checkpoint'];
      client._checkpoint = checkpoint == null
          ? null
          : LogCheckpoint.fromJson(checkpoint as Map<String, dynamic>);
      client._accounts = {
        for (final entry
            in (snapshot['accounts'] as Map<String, dynamic>).entries)
          entry.key: _Account.fromJson(entry.value as Map<String, dynamic>),
      };
    }
    return client;
  }

  LogCheckpoint? get checkpoint => _checkpoint;
  List<TrustedDeviceKey> devices(
    String accountId, {
    bool includeRevoked = false,
  }) => List.unmodifiable(
    (_accounts[accountId]?.devices.values ?? <TrustedDeviceKey>[]).where(
      (device) => includeRevoked || !device.revoked,
    ),
  );

  Future<T> _serial<T>(Future<T> Function() action) {
    if (_closed) return Future.error(const TransparencyException('closed'));
    final result = _tail.then((_) {
      if (_storageFault) {
        throw const TransparencyException('storage_reopen_required');
      }
      return action();
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  /// Synchronously fences new mutations, then drains every admitted operation.
  /// The caller owns [store] and must close it only after this future completes.
  /// Already committed public key/checkpoint snapshots remain readable.
  Future<void> close() {
    _closed = true;
    return _closeFuture ??= _tail;
  }

  /// First pin must be obtained through an authenticated account enrollment,
  /// QR verification or another independently trusted channel.
  Future<void> pinAccount(String accountId, List<int> identityPublicKey) =>
      _serial(() async {
        _id(accountId);
        final key = _bytes(identityPublicKey, 32);
        final old = _accounts[accountId];
        if (old != null) {
          if (!sameDigest(old.identity, key)) {
            throw const TransparencyException('identity_key_changed');
          }
          return;
        }
        final next = {..._accounts, accountId: _Account(key)};
        await _save(_checkpoint, next);
        _accounts = next;
      });

  /// Atomically advances the checkpoint and authorized account histories.
  /// Supply all new statements of each account in revision/leaf order.
  Future<void> apply({
    required SignedLogCheckpoint signedCheckpoint,
    List<List<int>> consistencyProof = const [],
    List<ProvenDeviceStatement> statements = const [],
  }) => _serial(() async {
    if (statements.length > 4096) {
      throw const TransparencyException('batch_too_large');
    }
    final nextCheckpoint = signedCheckpoint.checkpoint;
    await _verifyCheckpoint(signedCheckpoint, consistencyProof);
    final next = {for (final e in _accounts.entries) e.key: e.value.copy()};
    for (final proven in statements) {
      final authorized = proven.entry;
      final statement = authorized.statement;
      final account = next[statement.accountId];
      if (account == null) {
        throw const TransparencyException('identity_not_pinned');
      }
      if (!verifyMerkleInclusion(
        leaf: authorized.logEntry,
        index: proven.leafIndex,
        size: nextCheckpoint.size,
        proof: proven.inclusionProof,
        root: nextCheckpoint.root,
      )) {
        throw const TransparencyException('invalid_inclusion_proof');
      }
      final valid = await Ed25519().verify(
        statement.signingBytes,
        signature: Signature(
          authorized.signature,
          publicKey: SimplePublicKey(
            account.identity,
            type: KeyPairType.ed25519,
          ),
        ),
      );
      if (!valid) {
        throw const TransparencyException('invalid_identity_signature');
      }
      if (statement.revision == account.revision &&
          sameDigest(authorized.hash, account.lastHash) &&
          proven.leafIndex == account.lastLeaf) {
        continue;
      }
      if (statement.revision != account.revision + 1 ||
          !sameDigest(statement.previousStatementHash, account.lastHash) ||
          proven.leafIndex <= account.lastLeaf ||
          statement.createdAtMilliseconds < account.lastTime ||
          statement.createdAtMilliseconds >
              nextCheckpoint.issuedAtMilliseconds) {
        throw const TransparencyException('account_history_not_contiguous');
      }
      final previous = account.devices[statement.deviceId];
      switch (statement.action) {
        case DeviceKeyAction.enroll:
          if (previous != null) {
            throw const TransparencyException('device_identifier_already_used');
          }
          account.devices[statement.deviceId] = TrustedDeviceKey._(
            deviceId: statement.deviceId,
            publicKey: statement.deviceKey,
            revoked: false,
            revision: statement.revision,
            linkSigningKey: statement.linkSigningKey,
            transportEndpointKey: statement.transportEndpointKey,
          );
        case DeviceKeyAction.revoke:
          if (previous == null ||
              previous.revoked ||
              !sameDigest(previous.publicKey, statement.deviceKey)) {
            throw const TransparencyException('invalid_device_revocation');
          }
          account.devices[statement.deviceId] = TrustedDeviceKey._(
            deviceId: statement.deviceId,
            publicKey: statement.deviceKey,
            revoked: true,
            revision: statement.revision,
            linkSigningKey: previous.linkSigningKey,
            transportEndpointKey: previous.transportEndpointKey,
          );
      }
      account.revision = statement.revision;
      account.lastHash = authorized.hash;
      account.lastLeaf = proven.leafIndex;
      account.lastTime = statement.createdAtMilliseconds;
    }
    await _save(nextCheckpoint, next);
    _checkpoint = nextCheckpoint;
    _accounts = next;
  });

  Future<void> _verifyCheckpoint(
    SignedLogCheckpoint signed,
    List<List<int>> proof,
  ) async {
    final cp = signed.checkpoint;
    if (cp.logId != logId) throw const TransparencyException('wrong_log');
    final time = now().millisecondsSinceEpoch;
    if (cp.issuedAtMilliseconds > time + maximumClockSkew.inMilliseconds ||
        cp.issuedAtMilliseconds < time - maximumCheckpointAge.inMilliseconds) {
      throw const TransparencyException('checkpoint_outside_freshness_policy');
    }
    final algorithm = Ed25519();
    if (!await algorithm.verify(
      cp.signingBytes,
      signature: Signature(
        signed.logSignature,
        publicKey: SimplePublicKey(logPublicKey, type: KeyPairType.ed25519),
      ),
    )) {
      throw const TransparencyException('invalid_log_signature');
    }
    final accepted = <String>{};
    for (final witness in signed.witnesses) {
      final key = witnessPublicKeys[witness.witnessId];
      if (key == null || accepted.contains(witness.witnessId)) continue;
      if (await algorithm.verify(
        cp.signingBytes,
        signature: Signature(
          witness.signature,
          publicKey: SimplePublicKey(key, type: KeyPairType.ed25519),
        ),
      )) {
        accepted.add(witness.witnessId);
      }
    }
    if (accepted.length < witnessQuorum) {
      throw const TransparencyException('independent_witness_quorum_missing');
    }
    final old = _checkpoint;
    if (old == null) {
      if (proof.isNotEmpty ||
          (cp.size == 0 &&
              !sameDigest(cp.root, TransparencyMerkleLog().root()))) {
        throw const TransparencyException('invalid_initial_checkpoint');
      }
      return;
    }
    if (cp.size < old.size ||
        cp.issuedAtMilliseconds < old.issuedAtMilliseconds) {
      throw const TransparencyException('checkpoint_rollback');
    }
    if (!verifyMerkleConsistency(
      oldSize: old.size,
      newSize: cp.size,
      oldRoot: old.root,
      newRoot: cp.root,
      proof: proof,
    )) {
      throw const TransparencyException('fork_or_invalid_consistency_proof');
    }
  }

  Future<void> _save(LogCheckpoint? cp, Map<String, _Account> accounts) async {
    try {
      await store.write({
        'version': 1,
        'log': logId,
        'logKey': base64Encode(logPublicKey),
        'checkpoint': cp?.toJson(),
        'accounts': {for (final e in accounts.entries) e.key: e.value.toJson()},
      });
    } catch (_) {
      _storageFault = true;
      rethrow;
    }
  }
}

/// An independent witness's persistent append-only monitor. Unlike the signing
/// helper, this refuses to co-sign a fork or a rollback, including after restart.
/// Operate witnesses in independent administrative/failure domains and exchange
/// signed checkpoints between clients/monitors; merely naming keys differently
/// does not create independence.
final class KeyTransparencyWitness {
  KeyTransparencyWitness._(
    this.witnessId,
    this.logId,
    this._logKey,
    this._signer,
    this._publicKey,
    this._store,
    this._now,
  );
  final String witnessId;
  final String logId;
  final Uint8List _logKey;
  final SimpleKeyPair _signer;
  final Uint8List _publicKey;
  final TransparencyStateStore _store;
  final DateTime Function() _now;
  LogCheckpoint? _checkpoint;
  Future<void> _tail = Future.value();
  bool _storageFault = false;
  LogCheckpoint? get checkpoint => _checkpoint;

  static Future<KeyTransparencyWitness> open({
    required String witnessId,
    required String logId,
    required List<int> logPublicKey,
    required SimpleKeyPair signingKey,
    required TransparencyStateStore store,
    DateTime Function()? now,
  }) async {
    final publicKey = _bytes((await signingKey.extractPublicKey()).bytes, 32);
    final logKey = _bytes(logPublicKey, 32);
    if (sameDigest(publicKey, logKey)) {
      throw ArgumentError('A log cannot witness its own checkpoint');
    }
    final witness = KeyTransparencyWitness._(
      _id(witnessId),
      _id(logId),
      logKey,
      signingKey,
      publicKey,
      store,
      now ?? DateTime.now,
    );
    final saved = await store.read();
    if (saved != null) {
      if (saved['version'] != 1 ||
          saved['kind'] != 'witness' ||
          saved['witness'] != witnessId ||
          saved['log'] != logId ||
          saved['logKey'] != base64Encode(logKey) ||
          saved['witnessKey'] != base64Encode(publicKey)) {
        throw const TransparencyException('witness_storage_context_mismatch');
      }
      witness._checkpoint = LogCheckpoint.fromJson(
        saved['checkpoint'] as Map<String, dynamic>,
      );
    }
    return witness;
  }

  Future<WitnessSignature> approve(
    SignedLogCheckpoint candidate, {
    List<List<int>> consistencyProof = const [],
  }) {
    final future = _tail.then((_) async {
      if (_storageFault) {
        throw const TransparencyException('storage_reopen_required');
      }
      final cp = candidate.checkpoint;
      if (cp.logId != logId) throw const TransparencyException('wrong_log');
      final time = _now().millisecondsSinceEpoch;
      if ((cp.issuedAtMilliseconds - time).abs() >
          const Duration(minutes: 5).inMilliseconds) {
        throw const TransparencyException('witness_checkpoint_not_current');
      }
      if (!await Ed25519().verify(
        cp.signingBytes,
        signature: Signature(
          candidate.logSignature,
          publicKey: SimplePublicKey(_logKey, type: KeyPairType.ed25519),
        ),
      )) {
        throw const TransparencyException('invalid_log_signature');
      }
      final old = _checkpoint;
      if (old != null) {
        if (cp.size < old.size ||
            cp.issuedAtMilliseconds < old.issuedAtMilliseconds) {
          throw const TransparencyException('checkpoint_rollback');
        }
        if (!verifyMerkleConsistency(
          oldSize: old.size,
          newSize: cp.size,
          oldRoot: old.root,
          newRoot: cp.root,
          proof: consistencyProof,
        )) {
          throw const TransparencyException(
            'fork_or_invalid_consistency_proof',
          );
        }
      } else if (consistencyProof.isNotEmpty ||
          (cp.size == 0 &&
              !sameDigest(cp.root, TransparencyMerkleLog().root()))) {
        throw const TransparencyException('invalid_initial_checkpoint');
      }
      final signature = await Ed25519().sign(cp.signingBytes, keyPair: _signer);
      // Persist BEFORE exposing the signature. A witness must never forget that
      // it vouched for a history, otherwise restart could let it sign a fork.
      try {
        await _store.write({
          'version': 1,
          'kind': 'witness',
          'witness': witnessId,
          'log': logId,
          'logKey': base64Encode(_logKey),
          'witnessKey': base64Encode(_publicKey),
          'checkpoint': cp.toJson(),
        });
      } catch (_) {
        _storageFault = true;
        rethrow;
      }
      _checkpoint = cp;
      return WitnessSignature(witnessId: witnessId, signature: signature.bytes);
    });
    _tail = future.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return future;
  }
}
