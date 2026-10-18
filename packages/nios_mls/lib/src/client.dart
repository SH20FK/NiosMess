import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hashing;
import 'package:cryptography/cryptography.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:openmls/openmls.dart';
import 'package:universal_io/io.dart';

part 'delivery_coordinator.dart';
part 'http_delivery_api.dart';

final class NiosMlsException implements Exception {
  const NiosMlsException(this.code);
  final String code;
  @override
  String toString() => 'NiosMlsException($code)';
}

String _id(String value) {
  if (!RegExp(r'^[A-Za-z0-9._:@/-]{1,160}$').hasMatch(value)) {
    throw ArgumentError('Invalid account/device/operation identifier');
  }
  return value;
}

Uint8List _copy(List<int> value) =>
    Uint8List.fromList(value).asUnmodifiableView();
String _hash(List<int> value) => hashing.sha256.convert(value).toString();

/// Application-supplied trust decision for every member, including the creator
/// of a Welcome. Bind credentials to independently authenticated device keys
/// (for example a verified KeyTransparencyClient result).
typedef MlsDeviceAuthorizer =
    Future<bool> Function(
      String accountId,
      String deviceId,
      Uint8List signingPublicKey,
    );

/// Exposes process-crash boundaries to deterministic failure tests. Throwing
/// after publication makes the instance unusable until reopen.
typedef MlsFaultHook = Future<void> Function(String stage);

final class NiosMlsDevice {
  NiosMlsDevice({
    required this.accountId,
    required this.deviceId,
    required List<int> signingPublicKey,
    required this.leafIndex,
  }) : signingPublicKey = _copy(signingPublicKey);
  final String accountId;
  final String deviceId;
  final Uint8List signingPublicKey;
  final int leafIndex;
}

/// A durable idempotent result. The same operation ID always returns these
/// exact bytes; transport delivery/acknowledgement is separate from MLS.
final class NiosMlsOutbound {
  NiosMlsOutbound._(this.operationId, Map<String, dynamic> value)
    : groupId = _copy(base64Decode(value['group'] as String)),
      kind = value['kind'] as String,
      message = _copy(base64Decode(value['message'] as String)),
      welcome = value['welcome'] == null
          ? null
          : _copy(base64Decode(value['welcome'] as String)),
      baseEpoch = value['baseEpoch'] == null
          ? null
          : BigInt.parse(value['baseEpoch'] as String),
      epoch = value['epoch'] == null
          ? null
          : BigInt.parse(value['epoch'] as String),
      acknowledged = value['acknowledged'] as bool;
  final String operationId;
  final Uint8List groupId;
  final String kind;
  final Uint8List message;
  final Uint8List? welcome;

  /// Old v1 journal records lack epoch metadata and must be explicitly recovered
  /// rather than inferred from a later native group generation.
  final BigInt? baseEpoch;
  final BigInt? epoch;
  final bool acknowledged;
}

final class NiosMlsIncoming {
  NiosMlsIncoming._(Map<String, dynamic> value)
    : kind = value['kind'] as String,
      epoch = BigInt.parse(value['epoch'] as String),
      senderIndex = value['sender'] as int?,
      plaintext = value['plaintext'] == null
          ? null
          : _copy(base64Decode(value['plaintext'] as String));
  final String kind;
  final BigInt epoch;
  final int? senderIndex;
  final Uint8List? plaintext;
}

/// Crash-consistent reference adapter around real OpenMLS.
///
/// Native OpenMLS commits its own SQLCipher DB. Dart cannot put its application
/// journal in that SQL transaction. Therefore mutations use a CLOSED database
/// copy and publish the new generation + outbound/inbound result in ONE encrypted
/// Hive record. No ciphertext/plaintext is returned before publication. A crash
/// leaves either the previous generation or the complete new generation.
///
/// Tradeoff: native state is copied on each mutation (O(database size)). This is
/// deliberately explicit; a high-throughput implementation should move the
/// application journal into the Rust SQL transaction rather than weaken the
/// durability guarantee. Requires a native filesystem; the upstream Web engine
/// does not expose transactional export and is not silently substituted here.
final class NiosMlsClient {
  NiosMlsClient._(
    this._directory,
    this.accountId,
    this.deviceId,
    this._sqlKey,
    this._box,
    this._state,
    this.authorizeDevice,
    this.faultHook,
  );
  static const _suite = MlsCiphersuite.mls128DhkemX25519Aes128GcmSha256Ed25519;
  static final Set<String> _openPaths = {};
  final Directory _directory;
  final String accountId;
  final String deviceId;
  final Uint8List _sqlKey;
  final Box<String> _box;
  Map<String, dynamic> _state;
  final MlsDeviceAuthorizer authorizeDevice;
  final MlsFaultHook? faultHook;
  Future<void> _tail = Future.value();
  bool _closed = false;
  bool _closing = false;
  Future<void>? _closeFuture;
  bool _poisoned = false;

  static Future<NiosMlsClient> open({
    required String path,
    required List<int> storageKey,
    required String accountId,
    required String deviceId,
    required MlsDeviceAuthorizer authorizeDevice,
    MlsFaultHook? faultHook,
  }) async {
    final directory = await Directory(path).absolute.create(recursive: true);
    final resolved = await directory.resolveSymbolicLinks();
    final reservation = Platform.isWindows ? resolved.toLowerCase() : resolved;
    if (!_openPaths.add(reservation)) {
      throw const NiosMlsException('storage_already_open');
    }
    try {
      return await _open(
        path: resolved,
        storageKey: storageKey,
        accountId: accountId,
        deviceId: deviceId,
        authorizeDevice: authorizeDevice,
        faultHook: faultHook,
      );
    } catch (_) {
      _openPaths.remove(reservation);
      rethrow;
    }
  }

  static Future<NiosMlsClient> _open({
    required String path,
    required List<int> storageKey,
    required String accountId,
    required String deviceId,
    required MlsDeviceAuthorizer authorizeDevice,
    MlsFaultHook? faultHook,
  }) async {
    _id(accountId);
    _id(deviceId);
    if (storageKey.length != 32) {
      throw ArgumentError('storageKey must contain 32 bytes');
    }
    final directory = Directory(path).absolute;
    await directory.create(recursive: true);
    await Openmls.init();
    final context = utf8.encode(
      jsonEncode(['nios-mls-storage-v1', accountId, deviceId]),
    );
    Future<Uint8List> derive(String purpose) async => Uint8List.fromList(
      await (await Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
        secretKey: SecretKey(storageKey),
        nonce: context,
        info: utf8.encode(purpose),
      )).extractBytes(),
    );
    final sqlKey = await derive('sqlcipher');
    final journalKey = await derive('journal');
    final boxName =
        'mls_${_hash(utf8.encode(directory.path)).substring(0, 24)}';
    await _verifyJournalKey(directory.path, boxName, journalKey);
    final box = await Hive.openBox<String>(
      boxName,
      path: directory.path,
      encryptionCipher: HiveAesCipher(journalKey),
    );
    journalKey.fillRange(0, journalKey.length, 0);
    try {
      final encoded = box.get('state');
      Map<String, dynamic> state;
      if (encoded == null) {
        final pair = MlsSignatureKeyPair.generate(ciphersuite: _suite);
        final private = pair.privateKey();
        final signer = serializeSigner(
          ciphersuite: _suite,
          privateKey: private,
          publicKey: pair.publicKey(),
        );
        state = {
          'version': 1,
          'account': accountId,
          'device': deviceId,
          'database': null,
          'signer': base64Encode(signer),
          'publicKey': base64Encode(pair.publicKey()),
          'groups': <String, dynamic>{},
          'outbound': <String, dynamic>{},
          'inbound': <String, dynamic>{},
        };
        private.fillRange(0, private.length, 0);
        signer.fillRange(0, signer.length, 0);
        await box.put('state', jsonEncode(state));
        await box.flush();
      } else {
        state = jsonDecode(encoded) as Map<String, dynamic>;
      }
      if (state['version'] != 1 ||
          state['account'] != accountId ||
          state['device'] != deviceId) {
        throw const NiosMlsException('storage_identity_mismatch');
      }
      final database = state['database'];
      if (database != null &&
          (database is! String ||
              !RegExp(r'^state-[a-f0-9]{32}\.db$').hasMatch(database) ||
              !await File('${directory.path}/$database').exists())) {
        throw const NiosMlsException('committed_database_missing');
      }
      final result = NiosMlsClient._(
        directory,
        accountId,
        deviceId,
        sqlKey,
        box,
        state,
        authorizeDevice,
        faultHook,
      );
      await result._cleanupOrphans();
      return result;
    } catch (_) {
      await box.close();
      sqlKey.fillRange(0, sqlKey.length, 0);
      rethrow;
    }
  }

  static Future<void> _verifyJournalKey(
    String path,
    String name,
    List<int> key,
  ) async {
    // The commitment precedes Hive's own lock. Simultaneous first opens by
    // different processes must not publish commitments for different keys.
    final guard = await File(
      '$path/$name.keycheck.lock',
    ).open(mode: FileMode.append);
    try {
      await guard.lock(FileLock.exclusive);
      try {
        await _verifyLockedJournalKey(path, name, key);
      } finally {
        await guard.unlock();
      }
    } finally {
      await guard.close();
    }
  }

  static Future<void> _verifyLockedJournalKey(
    String path,
    String name,
    List<int> key,
  ) async {
    final file = File('$path/$name.keycheck');
    final expected = hashing.Hmac(
      hashing.sha256,
      key,
    ).convert(utf8.encode('nios-mls-journal-key-v1:$name')).bytes;
    if (await file.exists()) {
      final actual = await file.readAsBytes();
      var mismatch = actual.length ^ expected.length;
      for (var i = 0; i < expected.length; i++) {
        mismatch |= expected[i] ^ (i < actual.length ? actual[i] : 0);
      }
      if (mismatch != 0) throw const NiosMlsException('storage_key_mismatch');
    } else {
      if (await File('$path/$name.hive').exists()) {
        throw const NiosMlsException('storage_key_commitment_missing');
      }
      final stage = File('${file.path}.partial');
      await stage.writeAsBytes(expected, flush: true);
      await stage.rename(file.path);
    }
  }

  Uint8List get signingPublicKey =>
      _copy(base64Decode(_state['publicKey'] as String));
  List<NiosMlsOutbound> get pendingOperations {
    _checkOpen();
    return List.unmodifiable(
      (_state['outbound'] as Map<String, dynamic>).entries
          .where((e) => !(e.value as Map)['acknowledged'])
          .map(
            (e) => NiosMlsOutbound._(e.key, e.value as Map<String, dynamic>),
          ),
    );
  }

  /// Includes acknowledged tombstones so a recovering application bridge can
  /// finish its own journal after an interrupted acknowledgement.
  NiosMlsOutbound? outboundOperation(String operationId) {
    _checkOpen();
    final value = (_state['outbound'] as Map)[operationId];
    return value == null
        ? null
        : NiosMlsOutbound._(operationId, value as Map<String, dynamic>);
  }

  Uint8List get _credential => Uint8List.fromList(
    utf8.encode(jsonEncode(['nios-device', 1, accountId, deviceId])),
  );
  Uint8List _signer(Map<String, dynamic> state) =>
      base64Decode(state['signer'] as String);
  MlsGroupConfig get _config {
    final defaults = MlsGroupConfig.defaultConfig(ciphersuite: _suite);
    return MlsGroupConfig(
      ciphersuite: _suite,
      wireFormatPolicy: defaults.wireFormatPolicy,
      useRatchetTreeExtension: true,
      maxPastEpochs: 2,
      paddingSize: defaults.paddingSize,
      senderRatchetMaxOutOfOrder: 256,
      senderRatchetMaxForwardDistance: 4096,
      numberOfResumptionPsks: defaults.numberOfResumptionPsks,
    );
  }

  MlsCapabilities get _capabilities => MlsCapabilities(
    versions: Uint16List.fromList([1]),
    ciphersuites: Uint16List.fromList([1]),
    extensions: Uint16List(0),
    proposals: Uint16List(0),
    credentials: Uint16List.fromList([1]),
  );

  void _checkOpen() {
    if (_closed || _closing) throw const NiosMlsException('closed');
    if (_poisoned) {
      throw const NiosMlsException('reopen_required_after_storage_failure');
    }
  }

  Future<T> _serial<T>(Future<T> Function() action) {
    if (_closed || _closing) {
      return Future.error(const NiosMlsException('closed'));
    }
    final result = _tail.then((_) {
      _checkOpen();
      return action();
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  String _generation() =>
      'state-${List.generate(16, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join()}.db';

  Future<T> _transaction<T>(
    Future<T> Function(MlsEngine engine, Map<String, dynamic> state) action,
  ) async {
    final name = _generation();
    final file = File('${_directory.path}/$name');
    final previous = _state['database'] as String?;
    final next = jsonDecode(jsonEncode(_state)) as Map<String, dynamic>;
    MlsEngine? engine;
    var publicationStarted = false;
    try {
      if (previous != null) {
        await File('${_directory.path}/$previous').copy(file.path);
      }
      engine = await MlsEngine.create(
        dbPath: file.path,
        encryptionKey: _sqlKey,
      );
      final result = await action(engine, next);
      await engine.close();
      engine = null;
      // SQLCipher uses DELETE journal mode and FULL synchronous commits. Close
      // before snapshot publication: no live WAL or engine may mutate the file.
      final handle = await file.open(mode: FileMode.append);
      try {
        await handle.flush();
      } finally {
        await handle.close();
      }
      await faultHook?.call('native_state_closed');
      next['database'] = name;
      publicationStarted = true;
      await _box.put('state', jsonEncode(next));
      await _box.flush();
      await faultHook?.call('journal_published');
      _state = next;
      await _cleanupOrphans();
      return result;
    } catch (_) {
      await engine?.close();
      if (publicationStarted) {
        // A failed flush may still have published the record. Keep both DBs;
        // only a fresh read may decide which generation is authoritative.
        _poisoned = true;
      } else {
        await _deleteGeneration(name);
      }
      rethrow;
    }
  }

  Future<void> _cleanupOrphans() async {
    final keep = _state['database'];
    await for (final entity in _directory.list()) {
      final name = entity.path.split(Platform.pathSeparator).last;
      if (entity is File &&
          RegExp(
            r'^state-[a-f0-9]{32}\.db(?:\.lock|-journal)?$',
          ).hasMatch(name)) {
        final base = name.replaceFirst(RegExp(r'(\.lock|-journal)$'), '');
        if (base != keep) await entity.delete();
      }
    }
  }

  Future<void> _deleteGeneration(String name) async {
    for (final suffix in ['', '.lock', '-journal']) {
      final f = File('${_directory.path}/$name$suffix');
      if (await f.exists()) await f.delete();
    }
  }

  Future<T> _query<T>(Future<T> Function(MlsEngine) action) async {
    final current = _state['database'] as String?;
    if (current == null) throw const NiosMlsException('group_not_found');
    final engine = await MlsEngine.create(
      dbPath: '${_directory.path}/$current',
      encryptionKey: _sqlKey,
    );
    try {
      return await action(engine);
    } finally {
      await engine.close();
    }
  }

  Future<List<NiosMlsDevice>> _verifyMembers(
    MlsEngine engine,
    List<int> groupId, {
    bool requireAuthorization = true,
  }) async {
    if (await engine.groupCiphersuite(groupIdBytes: groupId) != _suite) {
      throw const NiosMlsException('unsupported_ciphersuite');
    }
    final result = <NiosMlsDevice>[];
    for (final member in await engine.groupMembers(groupIdBytes: groupId)) {
      final credential = MlsCredential.deserialize(bytes: member.credential);
      final decoded = jsonDecode(utf8.decode(credential.identity()));
      if (decoded is! List ||
          decoded.length != 4 ||
          decoded[0] != 'nios-device' ||
          decoded[1] != 1 ||
          decoded[2] is! String ||
          decoded[3] is! String) {
        throw const NiosMlsException('unsupported_credential');
      }
      final account = _id(decoded[2] as String);
      final device = _id(decoded[3] as String);
      final key = _copy(member.signatureKey);
      final isOwn =
          account == accountId &&
          device == deviceId &&
          base64Encode(key) == _state['publicKey'];
      if (requireAuthorization &&
          !isOwn &&
          !await authorizeDevice(account, device, key)) {
        throw const NiosMlsException('device_not_authorized');
      }
      result.add(
        NiosMlsDevice(
          accountId: account,
          deviceId: device,
          signingPublicKey: key,
          leafIndex: member.index,
        ),
      );
    }
    return result;
  }

  Future<Uint8List> createKeyPackage() => _serial(
    () => _transaction((engine, state) async {
      final signer = _signer(state);
      try {
        final result = await engine.createKeyPackageWithOptions(
          ciphersuite: _suite,
          signerBytes: signer,
          credentialIdentity: _credential,
          signerPublicKey: signingPublicKey,
          options: KeyPackageOptions(
            lastResort: false,
            capabilities: _capabilities,
            lifetimeSeconds: BigInt.from(604800),
          ),
        );
        return _copy(result.keyPackageBytes);
      } finally {
        signer.fillRange(0, signer.length, 0);
      }
    }),
  );

  Future<Uint8List> createGroup({required List<int> groupId}) => _serial(
    () => _transaction((engine, state) async {
      if (groupId.isEmpty || groupId.length > 128) {
        throw ArgumentError('Invalid group ID');
      }
      final encoded = base64Encode(groupId);
      if ((state['groups'] as Map).containsKey(encoded)) return _copy(groupId);
      final signer = _signer(state);
      try {
        final result = await engine.createGroupWithBuilder(
          config: _config,
          signerBytes: signer,
          credentialIdentity: _credential,
          signerPublicKey: signingPublicKey,
          groupId: _copy(groupId),
          capabilities: _capabilities,
        );
        (state['groups'] as Map)[encoded] = true;
        return _copy(result.groupId);
      } finally {
        signer.fillRange(0, signer.length, 0);
      }
    }),
  );

  Future<Uint8List> join({
    required List<int> welcome,
    List<int>? expectedGroupId,
    BigInt? expectedEpoch,
  }) {
    final stableWelcome = _copy(welcome);
    final expectedGroup = expectedGroupId == null
        ? null
        : _copy(expectedGroupId);
    return _serial(() async {
      if (stableWelcome.isEmpty || stableWelcome.length > 4 * 1024 * 1024) {
        throw ArgumentError('Invalid Welcome size');
      }
      final digest = _hash(stableWelcome);
      final previous = (_state['welcomes'] as Map?)?[digest] as Map?;
      if (previous != null) {
        final group = base64Decode(previous['group'] as String);
        if ((expectedGroup != null &&
                base64Encode(expectedGroup) != previous['group']) ||
            (expectedEpoch != null &&
                expectedEpoch.toString() != previous['epoch'])) {
          throw const NiosMlsException('welcome_context_mismatch');
        }
        return _copy(group);
      }
      return _transaction((engine, state) async {
        final signer = _signer(state);
        try {
          final result = await engine.joinGroupFromWelcome(
            config: _config,
            welcomeBytes: stableWelcome,
            signerBytes: signer,
          );
          await _verifyMembers(engine, result.groupId);
          final epoch = await engine.groupEpoch(groupIdBytes: result.groupId);
          if ((expectedGroup != null &&
                  base64Encode(result.groupId) !=
                      base64Encode(expectedGroup)) ||
              (expectedEpoch != null && epoch != expectedEpoch)) {
            throw const NiosMlsException('welcome_context_mismatch');
          }
          (state['groups'] as Map)[base64Encode(result.groupId)] = true;
          (state.putIfAbsent('welcomes', () => <String, dynamic>{})
              as Map)[digest] = {
            'group': base64Encode(result.groupId),
            'epoch': epoch.toString(),
          };
          return _copy(result.groupId);
        } finally {
          signer.fillRange(0, signer.length, 0);
        }
      });
    });
  }

  Future<NiosMlsOutbound> _outbound(
    String operationId,
    List<int> groupId,
    String kind,
    List<int> requestHash,
    Future<(Uint8List, Uint8List?)> Function(MlsEngine, Uint8List) produce, {
    bool verifyBefore = true,
  }) => _serial(() async {
    _id(operationId);
    final fingerprint = _hash(
      utf8.encode(
        jsonEncode([
          'nios-mls-request',
          1,
          kind,
          base64Encode(groupId),
          base64Encode(requestHash),
        ]),
      ),
    );
    final previous =
        (_state['outbound'] as Map)[operationId] as Map<String, dynamic>?;
    if (previous != null) {
      if (previous['fingerprint'] != fingerprint) {
        throw const NiosMlsException('operation_id_conflict');
      }
      return NiosMlsOutbound._(operationId, previous);
    }
    return _transaction((engine, state) async {
      if (verifyBefore) await _verifyMembers(engine, groupId);
      final baseEpoch = await engine.groupEpoch(groupIdBytes: groupId);
      final signer = _signer(state);
      try {
        final result = await produce(engine, signer);
        await _verifyMembers(engine, groupId);
        final value = <String, dynamic>{
          'group': base64Encode(groupId),
          'kind': kind,
          'message': base64Encode(result.$1),
          'welcome': result.$2 == null ? null : base64Encode(result.$2!),
          'baseEpoch': baseEpoch.toString(),
          'epoch': (await engine.groupEpoch(groupIdBytes: groupId)).toString(),
          'acknowledged': false,
          'fingerprint': fingerprint,
        };
        (state['outbound'] as Map)[operationId] = value;
        return NiosMlsOutbound._(operationId, value);
      } finally {
        signer.fillRange(0, signer.length, 0);
      }
    });
  });

  Future<NiosMlsOutbound> addDevices({
    required String operationId,
    required List<int> groupId,
    required List<Uint8List> keyPackages,
    List<String>? expectedDeviceIds,
  }) {
    if (keyPackages.isEmpty ||
        keyPackages.length > 64 ||
        keyPackages.any((p) => p.isEmpty || p.length > 65536)) {
      throw ArgumentError('Expected 1..64 bounded key packages');
    }
    final stableGroup = _copy(groupId);
    final stablePackages = keyPackages.map(_copy).toList(growable: false);
    final expected = expectedDeviceIds == null
        ? null
        : Set<String>.from(expectedDeviceIds.map(_id));
    if (expected != null &&
        (expected.length != keyPackages.length ||
            expected.length != expectedDeviceIds!.length)) {
      throw ArgumentError('One expected device per key package is required');
    }
    final request = utf8.encode(
      jsonEncode(
        expected == null
            ? stablePackages.map(base64Encode).toList()
            : {
                'packages': stablePackages.map(base64Encode).toList(),
                'expectedDevices': expected.toList()..sort(),
              },
      ),
    );
    return _outbound(operationId, stableGroup, 'commit', request, (
      engine,
      signer,
    ) async {
      final before = expected == null
          ? null
          : (await _verifyMembers(
              engine,
              stableGroup,
            )).map((m) => m.deviceId).toSet();
      final result = await engine.addMembers(
        groupIdBytes: stableGroup,
        signerBytes: signer,
        keyPackagesBytes: stablePackages,
      );
      await engine.mergePendingCommit(groupIdBytes: stableGroup);
      if (expected != null) {
        final members = await _verifyMembers(engine, stableGroup);
        final after = members.map((m) => m.deviceId).toSet();
        final added = after.difference(before!);
        if (after.length != members.length ||
            before.intersection(expected).isNotEmpty ||
            !after.containsAll(before) ||
            added.length != expected.length ||
            !added.containsAll(expected)) {
          throw const NiosMlsException('keypackage_device_binding_mismatch');
        }
      }
      return (result.commit, result.welcome);
    });
  }

  Future<NiosMlsOutbound> removeDevices({
    required String operationId,
    required List<int> groupId,
    required List<int> leafIndices,
  }) {
    if (leafIndices.isEmpty ||
        leafIndices.length > 64 ||
        leafIndices.any((i) => i < 0)) {
      throw ArgumentError('Invalid removal');
    }
    final stableGroup = _copy(groupId);
    final stableIndices = List<int>.unmodifiable(leafIndices);
    return _outbound(
      operationId,
      stableGroup,
      'commit',
      utf8.encode(jsonEncode(stableIndices)),
      (engine, signer) async {
        final result = await engine.removeMembers(
          groupIdBytes: stableGroup,
          signerBytes: signer,
          memberIndices: stableIndices,
        );
        await engine.mergePendingCommit(groupIdBytes: stableGroup);
        return (result.commit, result.welcome);
      },
      verifyBefore: false,
    );
  }

  Future<NiosMlsOutbound> encrypt({
    required String operationId,
    required List<int> groupId,
    required List<int> plaintext,
  }) {
    if (plaintext.length > 1024 * 1024) {
      throw ArgumentError('Use NiosStream for attachments');
    }
    final stableGroup = _copy(groupId);
    final stablePlaintext = _copy(plaintext);
    return _outbound(operationId, stableGroup, 'application', stablePlaintext, (
      engine,
      signer,
    ) async {
      final result = await engine.createMessage(
        groupIdBytes: stableGroup,
        signerBytes: signer,
        message: stablePlaintext,
      );
      return (result.ciphertext, null);
    });
  }

  Future<NiosMlsIncoming> receive({
    required List<int> groupId,
    required List<int> message,
    BigInt? expectedEpoch,
  }) {
    final stableGroup = _copy(groupId);
    final stableMessage = _copy(message);
    return _receive(stableGroup, stableMessage, expectedEpoch);
  }

  Future<NiosMlsIncoming> _receive(
    List<int> groupId,
    List<int> message,
    BigInt? expectedEpoch,
  ) => _serial(() async {
    if (message.isEmpty || message.length > 4 * 1024 * 1024) {
      throw ArgumentError('Invalid message size');
    }
    final id = _hash(
      utf8.encode(jsonEncode([base64Encode(groupId), base64Encode(message)])),
    );
    final old = (_state['inbound'] as Map)[id] as Map<String, dynamic>?;
    if (old != null) {
      if (expectedEpoch != null &&
          old['groupEpoch'] != expectedEpoch.toString()) {
        throw const NiosMlsException('incoming_epoch_context_mismatch');
      }
      return NiosMlsIncoming._(old);
    }
    return _transaction((engine, state) async {
      // A catalog revocation can arrive before the corresponding removal
      // commit. Read the old credentials without trusting revoked members;
      // only an authorized committer may transition to an authorized tree.
      // This runs on a private generation, so rejection publishes neither
      // a ratchet advancement nor application plaintext.
      final previousMembers = await _verifyMembers(
        engine,
        groupId,
        requireAuthorization: false,
      );
      final unauthorized = <int>{};
      for (final member in previousMembers) {
        final own =
            member.accountId == accountId &&
            member.deviceId == deviceId &&
            base64Encode(member.signingPublicKey) == _state['publicKey'];
        if (!own &&
            !await authorizeDevice(
              member.accountId,
              member.deviceId,
              member.signingPublicKey,
            )) {
          unauthorized.add(member.leafIndex);
        }
      }
      final result = await engine.processMessage(
        groupIdBytes: groupId,
        messageBytes: message,
      );
      if (unauthorized.isNotEmpty &&
          (result.messageType != ProcessedMessageType.stagedCommit ||
              result.senderIndex == null ||
              unauthorized.contains(result.senderIndex) ||
              !previousMembers.any((m) => m.leafIndex == result.senderIndex))) {
        throw const NiosMlsException('device_not_authorized');
      }
      // The Rust wrapper merges a staged commit transactionally. Verify the
      // resulting membership before publishing the cloned generation.
      if (await engine.groupIsActive(groupIdBytes: groupId)) {
        await _verifyMembers(engine, groupId);
      }
      final resultingEpoch = await engine.groupEpoch(groupIdBytes: groupId);
      if (expectedEpoch != null && expectedEpoch != resultingEpoch) {
        throw const NiosMlsException('incoming_epoch_context_mismatch');
      }
      final value = <String, dynamic>{
        'kind': result.messageType.name,
        'epoch': result.epoch.toString(),
        'groupEpoch': resultingEpoch.toString(),
        'sender': result.senderIndex,
        'plaintext': result.applicationMessage == null
            ? null
            : base64Encode(result.applicationMessage!),
      };
      (state['inbound'] as Map)[id] = value;
      return NiosMlsIncoming._(value);
    });
  });

  Future<List<NiosMlsDevice>> members(List<int> groupId) =>
      _serial(() => _query((engine) => _verifyMembers(engine, groupId)));

  /// Native-authenticated old credentials for selecting leaves to REMOVE.
  /// This does not authorize those devices for sending or joining. Revocation
  /// must not make it impossible to find the revoked leaf's removal index.
  Future<List<NiosMlsDevice>> membersForRemoval(List<int> groupId) => _serial(
    () => _query(
      (engine) => _verifyMembers(engine, groupId, requireAuthorization: false),
    ),
  );
  Future<BigInt> epoch(List<int> groupId) => _serial(
    () => _query((engine) => engine.groupEpoch(groupIdBytes: groupId)),
  );
  Future<bool> isActive(List<int> groupId) => _serial(
    () => _query((engine) => engine.groupIsActive(groupIdBytes: groupId)),
  );

  /// Derives an epoch-scoped subprotocol key using the RFC 9420 exporter.
  /// Group membership authorizes every member to know it; this is a pairwise
  /// Link key only for a group containing exactly those two devices. Include
  /// the epoch in the calling subprotocol and retain old keys for old queued
  /// envelopes; never reinterpret a changed epoch as the same symmetric key.
  Future<SecretKey> deriveApplicationKey({
    required List<int> groupId,
    required String label,
    List<int> context = const [],
  }) {
    if (!RegExp(r'^[a-zA-Z0-9._/-]{1,64}$').hasMatch(label) ||
        context.length > 1024) {
      throw ArgumentError('Invalid exporter context');
    }
    final stableGroup = _copy(groupId);
    final stableContext = _copy(context);
    return _serial(
      () => _query((engine) async {
        await _verifyMembers(engine, stableGroup);
        return SecretKey(
          await engine.exportSecret(
            groupIdBytes: stableGroup,
            label: 'nios-application-v1/$label',
            context: stableContext,
            keyLength: 32,
          ),
        );
      }),
    );
  }

  /// Retain the operation tombstone and bytes for idempotent API retries.
  Future<void> acknowledge(String operationId) => _serial(() async {
    final operation = (_state['outbound'] as Map)[operationId] as Map?;
    if (operation == null || operation['acknowledged'] == true) return;
    final next = jsonDecode(jsonEncode(_state)) as Map<String, dynamic>;
    ((next['outbound'] as Map)[operationId] as Map)['acknowledged'] = true;
    try {
      await _box.put('state', jsonEncode(next));
      await _box.flush();
      _state = next;
    } catch (_) {
      _poisoned = true;
      rethrow;
    }
  });

  Future<void> close() {
    if (_closeFuture != null) return _closeFuture!;
    _closing = true;
    return _closeFuture = _close();
  }

  Future<void> _close() async {
    await _tail;
    if (_closed) return;
    _closed = true;
    await _box.close();
    _openPaths.remove(
      Platform.isWindows ? _directory.path.toLowerCase() : _directory.path,
    );
    _sqlKey.fillRange(0, _sqlKey.length, 0);
    _state = {};
  }
}
