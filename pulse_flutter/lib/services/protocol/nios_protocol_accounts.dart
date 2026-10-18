import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as hashing;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nios_mls/nios_mls.dart';
import 'package:nios_sdk/link.dart';
import 'package:nios_sdk/media.dart';
import 'package:nios_sdk/stream.dart';
import 'package:nios_sdk/trust.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:universal_io/io.dart';

/// Lazy account owner. Existing chat protocols are unaffected: a caller must
/// negotiate v1 and provide authenticated keys/transports before starting it.
final niosProtocolAccountsProvider = Provider<NiosProtocolAccounts>((ref) {
  final accounts = NiosProtocolAccounts();
  ref.onDispose(() => unawaited(accounts.close()));
  return accounts;
});

abstract interface class ProtocolSecretStore {
  Future<String?> read(String name);
  Future<void> write(String name, String value);
  Future<void> delete(String name);
}

final class _PlatformSecretStore implements ProtocolSecretStore {
  const _PlatformSecretStore();
  static const _storage = FlutterSecureStorage();
  @override
  Future<String?> read(String name) => _storage.read(key: name);
  @override
  Future<void> write(String name, String value) =>
      _storage.write(key: name, value: value);
  @override
  Future<void> delete(String name) => _storage.delete(key: name);
}

String _hash(String value) =>
    hashing.sha256.convert(utf8.encode(value)).toString();
String _randomId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

/// Operations for each account are serialized, including open vs logout. A
/// synchronous epoch fence prevents an open already in progress from escaping
/// a logout. Secrets are removed only after storage was successfully erased.
final class NiosProtocolAccounts {
  NiosProtocolAccounts({
    ProtocolSecretStore? secrets,
    Future<Directory> Function()? directory,
  }) : _secrets = secrets ?? const _PlatformSecretStore(),
       _directory = directory ?? getApplicationSupportDirectory;

  final ProtocolSecretStore _secrets;
  final Future<Directory> Function() _directory;
  final Map<String, Future<void>> _tails = {};
  final Map<String, int> _epochs = {};
  final Map<String, NiosProtocolAccount> _accounts = {};
  static final Set<String> _keyReservations = {};
  bool _closed = false;

  Future<T> _serial<T>(String account, Future<T> Function() action) {
    final result = (_tails[account] ?? Future<void>.value()).then(
      (_) => action(),
    );
    _tails[account] = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<NiosProtocolAccount> openAccount(String accountId) {
    if (accountId.isEmpty || accountId.length > 160) {
      throw ArgumentError.value(accountId, 'accountId');
    }
    final epoch = _epochs[accountId] ?? 0;
    return _serial(accountId, () async {
      if (_closed || (_epochs[accountId] ?? 0) != epoch) {
        throw StateError('protocol_account_stopped');
      }
      final existing = _accounts[accountId];
      if (existing != null) return existing;
      if (kIsWeb) throw UnsupportedError('protocol_native_storage_required');
      final root = Directory(
        p.join((await _directory()).path, 'nios_protocol'),
      );
      final directory = Directory(p.join(root.path, _hash(accountId)));
      final name = 'nios.protocol.v1.${_hash(accountId)}';
      final encoded = await _loadKeyMaterial(name, directory);
      final value = jsonDecode(encoded) as Map<String, dynamic>;
      final key = Uint8List.fromList(base64Decode(value['key'] as String));
      final device = value['device'] as String;
      if (value['v'] != 1 ||
          key.length != 32 ||
          !RegExp(r'^[a-f0-9]{32}$').hasMatch(device)) {
        key.fillRange(0, key.length, 0);
        throw StateError('protocol_storage_key_invalid');
      }
      if (_closed || (_epochs[accountId] ?? 0) != epoch) {
        key.fillRange(0, key.length, 0);
        throw StateError('protocol_account_stopped');
      }
      await directory.create(recursive: true);
      final account = NiosProtocolAccount._(accountId, device, directory, key);
      if (_closed || (_epochs[accountId] ?? 0) != epoch) {
        await account.close();
        throw StateError('protocol_account_stopped');
      }
      _accounts[accountId] = account;
      return account;
    });
  }

  Future<String> _loadKeyMaterial(String name, Directory directory) async {
    final reservation = p.normalize(directory.absolute.path);
    if (!_keyReservations.add(reservation)) {
      throw StateError('protocol_key_creation_busy');
    }
    RandomAccessFile? lock;
    var locked = false;
    try {
      await directory.parent.create(recursive: true);
      lock = await File(
        '${directory.path}.keylock',
      ).open(mode: FileMode.append);
      await lock.lock(FileLock.exclusive);
      locked = true;
      final existing = await _secrets.read(name);
      if (existing != null) return existing;
      // A lost wrapping key must not be silently replaced over existing data.
      if (await directory.exists() && !await directory.list().isEmpty) {
        throw StateError('protocol_storage_key_missing');
      }
      final random = Random.secure();
      final encoded = jsonEncode({
        'v': 1,
        'device': _randomId(),
        'key': base64Encode(List.generate(32, (_) => random.nextInt(256))),
      });
      await _secrets.write(name, encoded);
      return encoded;
    } finally {
      try {
        if (locked) await lock!.unlock();
      } finally {
        await lock?.close();
        _keyReservations.remove(reservation);
      }
    }
  }

  Future<void> shutdownAccount(String accountId, {required bool erase}) {
    _epochs[accountId] = (_epochs[accountId] ?? 0) + 1;
    // Set the runtime fence immediately, before awaiting disk/native work.
    final stopping = _accounts[accountId]?.close();
    return _serial(accountId, () async {
      await stopping;
      _accounts.remove(accountId);
      if (!erase || kIsWeb) return;
      final root = Directory(
        p.join((await _directory()).path, 'nios_protocol'),
      );
      final target = Directory(p.join(root.path, _hash(accountId)));
      if (await target.exists()) {
        final resolvedRoot = await root.resolveSymbolicLinks();
        final resolvedTarget = await target.resolveSymbolicLinks();
        if (!p.isWithin(resolvedRoot, resolvedTarget) ||
            p.basename(resolvedTarget) != _hash(accountId)) {
          throw StateError('protocol_erase_path_invalid');
        }
        await Directory(resolvedTarget).delete(recursive: true);
      }
      await _secrets.delete('nios.protocol.v1.${_hash(accountId)}');
    });
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final ids = {..._tails.keys, ..._accounts.keys};
    await Future.wait(ids.map((id) => shutdownAccount(id, erase: false)));
  }
}

typedef ProtocolTransportFactory =
    Future<List<LinkTransport>> Function(
      Future<EncryptedEnvelope> Function(EncryptedEnvelope) receive,
      Future<void> Function(EncryptedEnvelope) acknowledge,
    );

final class NiosProtocolAccount {
  NiosProtocolAccount._(
    this.accountId,
    this.deviceId,
    this.directory,
    this._rootKey,
  );
  final String accountId;
  final String deviceId;
  final Directory directory;
  final Uint8List _rootKey;
  DurableSession? _delivery;
  NiosMlsClient? _groups;
  HiveTransparencyStateStore? _trustStore;
  KeyTransparencyClient? _trust;
  final _cancellation = StreamCancellation();
  final Set<NiosStreamDownload> _downloads = {};
  final Set<AuthenticatedMediaGateway> _gateways = {};
  final Set<Future<void> Function()> _resources = {};
  Future<void> _tail = Future<void>.value();
  Future<void>? _closing;

  DurableSession? get delivery => _delivery;
  KeyTransparencyClient? get transparency => _trust;

  /// Bind consumers of this directory so logout releases every file/socket
  /// lease before erasing the account, including concurrent owner shutdowns.
  VoidCallback bindResource(Future<void> Function() close) {
    _checkOpen();
    _resources.add(close);
    return () => _resources.remove(close);
  }

  /// Enrollment can sign device statements without exposing the wrapping key
  /// or raw derived seeds to the HTTP/bootstrap layer.
  Future<Uint8List> protocolPublicKey({required String purpose}) =>
      _serial(() async {
        return _withProtocolSigningPair(
          purpose,
          (pair) async =>
              Uint8List.fromList((await pair.extractPublicKey()).bytes),
        );
      });

  Future<Uint8List> signProtocol(
    List<int> message, {
    required String purpose,
  }) => _serial(() async {
    return _withProtocolSigningPair(
      purpose,
      (pair) async => Uint8List.fromList(
        (await Ed25519().sign(message, keyPair: pair)).bytes,
      ),
    );
  });

  Future<T> _withProtocolSigningPair<T>(
    String purpose,
    Future<T> Function(SimpleKeyPair) action,
  ) async {
    if (purpose != 'account-identity' && purpose != 'link-signing') {
      throw ArgumentError.value(purpose, 'purpose');
    }
    final seed = await _key('enrollment-$purpose');
    try {
      return await action(await Ed25519().newKeyPairFromSeed(seed));
    } finally {
      seed.fillRange(0, seed.length, 0);
    }
  }

  void _checkOpen() {
    if (_closing != null) throw StateError('protocol_account_stopped');
  }

  Future<T> _serial<T>(Future<T> Function() action) {
    _checkOpen();
    final result = _tail.then((_) {
      _checkOpen();
      return action();
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<Uint8List> _key(String purpose) async => Uint8List.fromList(
    await (await Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
      secretKey: SecretKey(_rootKey),
      nonce: utf8.encode(
        jsonEncode(['nios-app-account-v1', accountId, deviceId]),
      ),
      info: utf8.encode(purpose),
    )).extractBytes(),
  );

  /// Called only after both endpoints and the mailbox advertise Link v1. The
  /// cipher must authenticate device identities; a missing trusted peer key
  /// may throw while sealing without preventing durable local enqueue.
  Future<DurableSession> startDelivery({
    required int negotiatedVersion,
    required EnvelopeCipher cipher,
    required ProtocolTransportFactory transports,
    required OperationReducer reducer,
    HttpCiphertextBlobStore? blobs,
  }) => _serial(() async {
    if (negotiatedVersion != 1) {
      throw UnsupportedError('link_version_unsupported');
    }
    if (_delivery != null) return _delivery!;
    final ready = Completer<DurableSession>();
    // The factory is invoked before a native endpoint can dispatch its events.
    // Attaching an error handler also covers failure before any event arrives.
    unawaited(
      ready.future.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
    List<LinkTransport> routes = [];
    try {
      routes = await transports(
        (message) async => (await ready.future).receive(message),
        (ack) async => (await ready.future).acceptAcknowledgement(ack),
      );
      _checkOpen();
      final session = await DurableSession.open(
        directory: p.join(directory.path, 'link'),
        accountId: accountId,
        journalKey: await _key('link-journal'),
        deviceId: deviceId,
        cipher: cipher,
        reducer: reducer,
        autoStart: false,
        transports: routes
            .map(
              (route) => _BlobBeforeEnvelopeTransport(
                route,
                ready.future,
                directory,
                blobs,
                _cancellation,
              ),
            )
            .toList(),
      );
      _delivery = session;
      ready.complete(session);
      await _collectUnreferencedAttachments(session);
      _checkOpen();
      session.start();
      return session;
    } catch (error, stack) {
      if (!ready.isCompleted) ready.completeError(error, stack);
      if (_closing == null && _delivery != null) {
        final failed = _delivery!;
        _delivery = null;
        await failed.close();
      } else {
        await Future.wait(routes.map((route) => route.close()));
      }
      rethrow;
    }
  });

  Future<SavedOperation> enqueue({
    required String peerDeviceId,
    required String sessionId,
    required Map<String, dynamic> payload,
    String? operationId,
  }) => _serial(
    () => _requireDelivery().enqueue(
      peerId: peerDeviceId,
      sessionId: sessionId,
      payload: payload,
      operationId: operationId,
      prepareImmediately: false,
    ),
  );

  DurableSession _requireDelivery() =>
      _delivery ?? (throw StateError('protocol_delivery_not_configured'));

  // Only run after a successful encrypted journal restore, before starting the
  // pump. Failed/uncertain journal writes are never followed by eager deletion.
  Future<void> _collectUnreferencedAttachments(DurableSession session) async {
    final root = Directory(p.join(directory.path, 'attachments'));
    if (!await root.exists()) return;
    final referenced = <String>{};
    for (final operation in session.operations) {
      final payload = session.savedPayload(operation.operationId);
      if (payload?['type'] == 'nios.stream') {
        referenced.add(_attachmentManifest(payload!).objectId);
      }
    }
    final resolvedRoot = await root.resolveSymbolicLinks();
    await for (final entity in root.list(followLinks: false)) {
      _checkOpen();
      if (entity is! Directory) continue;
      final name = p.basename(entity.path);
      if (referenced.contains(name)) continue;
      if (!RegExp(
        r'^(?:[a-f0-9]{32}|\.[a-f0-9]{32}\.[a-f0-9]{16}\.partial)$',
      ).hasMatch(name)) {
        continue;
      }
      final resolved = await entity.resolveSymbolicLinks();
      if (!p.isWithin(resolvedRoot, resolved) || p.basename(resolved) != name) {
        throw StateError('protocol_attachment_path_invalid');
      }
      await Directory(resolved).delete(recursive: true);
    }
  }

  /// Only the encrypted container is copied into account-owned storage. The
  /// file key and captions enter the encrypted durable journal before success.
  Future<SavedOperation> enqueueAttachment({
    required String inputPath,
    required String peerDeviceId,
    required String sessionId,
    String caption = '',
    String? filename,
  }) => _serial(() async {
    final delivery = _requireDelivery();
    final prepared = await NiosStream.prepareFile(
      inputPath: inputPath,
      outputDirectory: p.join(directory.path, 'attachments'),
      cancellation: _cancellation,
    );
    _checkOpen();
    return delivery.enqueue(
      peerId: peerDeviceId,
      sessionId: sessionId,
      operationId: prepared.manifest.objectId,
      prepareImmediately: false,
      payload: {
        'type': 'nios.stream',
        'v': 1,
        'manifest': prepared.manifest.toJson(),
        'manifestHash': prepared.manifest.hash,
        'key': base64Encode(await prepared.key.extractBytes()),
        'filename': filename ?? p.basename(inputPath),
        'caption': caption,
      },
    );
  });

  /// [payload] must come from an authenticated Link/MLS operation, never a
  /// public manifest endpoint. Caches contain ciphertext and a verified bitmap.
  Future<NiosStreamDownload> openAttachment({
    required Map<String, dynamic> payload,
    required List<StreamCiphertextSource> sources,
  }) => _serial(() async {
    final manifest = _attachmentManifest(payload);
    final key = base64Decode(payload['key'] as String);
    if (key.length != 32) throw const FormatException('Invalid file key');
    final download = await NiosStreamDownload.open(
      directory: p.join(directory.path, 'downloads', manifest.objectId),
      manifest: manifest,
      key: SecretKey(key),
      sources: sources,
      cancellation: _cancellation,
    );
    _downloads.add(download);
    _checkOpen();
    return download;
  });

  Future<AuthenticatedMediaGateway> openMedia({
    required NiosStreamDownload download,
    required String mimeType,
  }) => _serial(() async {
    if (!_downloads.contains(download)) {
      throw StateError('foreign_account_download');
    }
    final gateway = await AuthenticatedMediaGateway.bind(
      download: download,
      mimeType: mimeType,
    );
    _gateways.add(gateway);
    _checkOpen();
    return gateway;
  });

  Future<KeyTransparencyClient> configureTransparency({
    required String logId,
    required List<int> logPublicKey,
    required Map<String, List<int>> witnessPublicKeys,
    required int witnessQuorum,
  }) => _serial(() async {
    if (_trust != null) throw StateError('protocol_trust_already_configured');
    final store = await HiveTransparencyStateStore.open(
      path: p.join(directory.path, 'trust'),
      boxName: 'nios_app_kt_${_hash(accountId).substring(0, 32)}',
      encryptionKey: await _key('transparency-state'),
    );
    try {
      final trust = await KeyTransparencyClient.open(
        logId: logId,
        logPublicKey: logPublicKey,
        witnessPublicKeys: witnessPublicKeys,
        witnessQuorum: witnessQuorum,
        store: store,
      );
      _trustStore = store;
      _trust = trust;
      _checkOpen();
      return trust;
    } catch (_) {
      if (_trustStore != store) await store.close();
      rethrow;
    }
  });

  /// The caller must bind credentials to a pinned account identity or a verified
  /// transparency bundle. There is deliberately no permissive default callback.
  Future<NiosMlsClient> openGroups({
    required MlsDeviceAuthorizer authorizeDevice,
  }) => _serial(() async {
    final groups = _groups ??= await NiosMlsClient.open(
      path: p.join(directory.path, 'mls'),
      storageKey: await _key('mls-state'),
      accountId: accountId,
      deviceId: deviceId,
      authorizeDevice: authorizeDevice,
    );
    _checkOpen();
    return groups;
  });

  Future<void> close() {
    if (_closing != null) return _closing!;
    final completion = Completer<void>();
    _closing = completion.future;
    _cancellation.cancel();
    final resourcesStopped = _resources
        .map((stop) => Future<void>.sync(stop))
        .toList();
    for (final stopped in resourcesStopped) {
      unawaited(
        stopped.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
      );
    }
    final deliveryStopped = _delivery?.close();
    if (deliveryStopped != null) {
      unawaited(
        deliveryStopped.then<void>(
          (_) {},
          onError: (Object _, StackTrace _) {},
        ),
      );
    }
    unawaited(
      _close(
        deliveryStopped,
        resourcesStopped,
      ).then(completion.complete, onError: completion.completeError),
    );
    return completion.future;
  }

  Future<void> _close(
    Future<void>? deliveryStopped,
    List<Future<void>> resourcesStopped,
  ) async {
    await _tail;
    Object? firstError;
    StackTrace? firstStack;
    Future<void> attempt(Future<void> Function() stop) async {
      try {
        await stop();
      } catch (error, stack) {
        firstError ??= error;
        firstStack ??= stack;
      }
    }

    try {
      await Future.wait(
        resourcesStopped.map((stopped) => attempt(() => stopped)),
      );
      _resources.clear();
      // Gateways release their range reads before download locks and journals.
      await Future.wait(_gateways.map((gateway) => attempt(gateway.close)));
      await Future.wait(_downloads.map((download) => attempt(download.close)));
      await attempt(() async {
        if (deliveryStopped != null) {
          await deliveryStopped;
        } else {
          await _delivery?.close();
        }
      });
      await attempt(() async {
        await _groups?.close();
      });
      await attempt(() async {
        await _trust?.close();
      });
      await attempt(() async {
        await _trustStore?.close();
      });
    } finally {
      _rootKey.fillRange(0, _rootKey.length, 0);
    }
    if (firstError != null) Error.throwWithStackTrace(firstError!, firstStack!);
  }
}

NiosStreamManifest _attachmentManifest(Map<String, dynamic> payload) {
  if (payload['type'] != 'nios.stream' || payload['v'] != 1) {
    throw const FormatException('Unsupported attachment');
  }
  return NiosStreamManifest.fromJson(
    Map<String, dynamic>.from(payload['manifest'] as Map),
    expectedHash: payload['manifestHash'] as String,
  );
}

final class _BlobBeforeEnvelopeTransport implements LinkTransport {
  _BlobBeforeEnvelopeTransport(
    this._route,
    this._session,
    this._directory,
    this._blobs,
    this._cancellation,
  );
  final LinkTransport _route;
  final Future<DurableSession> _session;
  final Directory _directory;
  final HttpCiphertextBlobStore? _blobs;
  final StreamCancellation _cancellation;
  final Set<String> _published = {};

  @override
  Future<TransportReceipt> deliver(EncryptedEnvelope envelope) async {
    final payload = (await _session).savedPayload(envelope.context.operationId);
    if (payload?['type'] == 'nios.stream') {
      final manifest = _attachmentManifest(payload!);
      if (!_published.contains(manifest.hash)) {
        if (_blobs == null) {
          throw const LinkTransportException('blob_service_unavailable');
        }
        await _blobs.ensurePublished(
          manifest: manifest,
          ciphertextPath: p.join(
            _directory.path,
            'attachments',
            manifest.objectId,
            'content.nsc',
          ),
          cancellation: _cancellation,
        );
        _published.add(manifest.hash);
      }
    }
    _cancellation.throwIfCancelled();
    return _route.deliver(envelope);
  }

  @override
  Future<void> publishAcknowledgement(EncryptedEnvelope acknowledgement) =>
      _route.publishAcknowledgement(acknowledgement);
  @override
  Future<List<EncryptedEnvelope>> poll(String deviceId) =>
      _route.poll(deviceId);
  @override
  Future<void> confirmReceived(EncryptedEnvelope envelope) =>
      _route.confirmReceived(envelope);
  @override
  Future<void> close() => _route.close();
}
