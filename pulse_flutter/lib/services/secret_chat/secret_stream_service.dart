import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;
import 'package:nios_sdk/media.dart';
import 'package:nios_sdk/stream.dart';
import 'package:path/path.dart' as p;
import 'package:universal_io/io.dart';

import '../../core/media/media_playback_source.dart';
import '../../core/media/background_stream_crypto.dart';

/// The descriptor is accepted only from the authenticated secret-chat journal.
/// Public blob endpoints are never a source of file keys or trusted manifests.
final class SecretStreamDescriptor {
  SecretStreamDescriptor._(this.manifest, this.key, this.mimeType);
  final NiosStreamManifest manifest;
  final Uint8List key;
  final String mimeType;

  factory SecretStreamDescriptor.fromFile(Map<String, dynamic> file) {
    final raw = file['stream'];
    if (raw is! Map || raw['v'] != 1 || raw['manifest'] is! Map) {
      throw const FormatException('secret_stream_descriptor_invalid');
    }
    final manifest = NiosStreamManifest.fromJson(
      Map<String, dynamic>.from(raw['manifest'] as Map),
      expectedHash: raw['manifest_hash'] as String,
    );
    final key = base64Decode(file['key'] as String);
    if (key.length != 32 ||
        (file['size'] != null && file['size'] != manifest.plaintextLength)) {
      key.fillRange(0, key.length, 0);
      throw const FormatException('secret_stream_key_invalid');
    }
    return SecretStreamDescriptor._(
      manifest,
      key,
      file['mime'] as String? ?? 'application/octet-stream',
    );
  }

  String get localUri => 'nios-stream://${manifest.objectId}/${manifest.hash}';

  void dispose() => key.fillRange(0, key.length, 0);
}

/// Native secret attachments use an immutable segmented ciphertext container.
/// Playback authenticates individual segments in RAM; only ciphertext and a
/// verified download bitmap are retained in this account's directory.
final class SecretStreamService {
  SecretStreamService({
    required this.accountId,
    required this.origin,
    required this.token,
    required this.directory,
    required this.ensureRegistered,
    this.allowInsecureLoopback = false,
    http.Client? client,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null {
    final loopback = const {
      '127.0.0.1',
      'localhost',
      '::1',
    }.contains(origin.host);
    if (accountId <= 0 ||
        origin.host.isEmpty ||
        origin.userInfo.isNotEmpty ||
        origin.hasQuery ||
        origin.hasFragment ||
        (origin.scheme != 'https' &&
            !(allowInsecureLoopback && loopback && origin.scheme == 'http'))) {
      throw ArgumentError('Invalid authenticated stream origin');
    }
  }

  final int accountId;
  final Uri origin;
  final String? Function() token;
  final Future<Directory> Function() directory;
  final Future<void> Function() ensureRegistered;
  final bool allowInsecureLoopback;
  final http.Client _client;
  final bool _ownsClient;
  final _cancellation = StreamCancellation();
  final _crypto = BackgroundStreamCrypto();
  final Map<String, Future<_Download>> _downloads = {};
  final Map<String, Future<void>> _closingDownloads = {};
  final Set<String> _prepared = {};
  final Set<AuthenticatedMediaGateway> _gateways = {};
  final Set<Future<void>> _jobs = {};
  Future<void>? _closing;
  Future<bool>? _capabilities;

  void _checkOpen() {
    if (_closing != null) throw StateError('secret_stream_account_stopped');
    _cancellation.throwIfCancelled();
  }

  String _token() {
    _checkOpen();
    final value = token();
    if (value == null || value.isEmpty) {
      throw StateError('secret_stream_session_missing');
    }
    return value;
  }

  HttpCiphertextBlobStore _store() => HttpCiphertextBlobStore(
    baseUri: origin,
    bearerToken: _token(),
    allowInsecureLoopback: allowInsecureLoopback,
    cryptoExecutor: _crypto.run,
  );

  Future<T> _job<T>(Future<T> Function() action) {
    _checkOpen();
    final result = Future<T>.sync(action);
    final settled = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _jobs.add(settled);
    unawaited(settled.whenComplete(() => _jobs.remove(settled)));
    return result;
  }

  /// Unknown/offline/older services preserve the existing compatible route.
  /// This probe never turns a previously prepared stream into plaintext.
  Future<bool> isSupported() => _job(() async {
    final pending = _capabilities ??= () async {
      try {
        final response = await _request('GET', origin.resolve('/v1/protocols'));
        if (response.statusCode != 200) return false;
        final body = jsonDecode(response.body) as Map;
        final protocols = body['protocols'] is Map
            ? body['protocols'] as Map
            : body;
        return (protocols['stream'] as List? ?? const []).contains(1);
      } on Exception {
        return false;
      }
    }();
    final supported = await pending;
    if (!supported) _capabilities = null;
    return supported;
  });

  Future<void> registerDevice() => _job(() async {
    await ensureRegistered();
    _checkOpen();
  });

  Future<Map<String, dynamic>> prepareFile({
    required String inputPath,
    required String filename,
    required String mimeType,
    required String subtype,
  }) => _job(() async {
    final root = await directory();
    _checkOpen();
    final prepared = await NiosStream.prepareFile(
      inputPath: inputPath,
      outputDirectory: p.join(root.path, 'secret_stream', 'outgoing'),
      cancellation: _cancellation,
      cryptoExecutor: _crypto.run,
    );
    _checkOpen();
    final key = Uint8List.fromList(await prepared.key.extractBytes());
    try {
      _prepared.add(prepared.manifest.objectId);
      return {
        'attachment_id': 'stream_${prepared.manifest.objectId}',
        'key': base64Encode(key),
        'name': filename,
        'size': prepared.manifest.plaintextLength,
        'mime': mimeType,
        'subtype': subtype,
        'stream': {
          'v': 1,
          'manifest': prepared.manifest.toJson(),
          'manifest_hash': prepared.manifest.hash,
        },
      };
    } finally {
      key.fillRange(0, key.length, 0);
    }
  });

  Future<String> upload(Map<String, dynamic> file, {required int chatId}) =>
      _job(() async {
        final descriptor = SecretStreamDescriptor.fromFile(file);
        try {
          await ensureRegistered();
          _checkOpen();
          final root = await directory();
          await _store().ensurePublished(
            manifest: descriptor.manifest,
            ciphertextPath: p.join(
              root.path,
              'secret_stream',
              'outgoing',
              descriptor.manifest.objectId,
              'content.nsc',
            ),
            cancellation: _cancellation,
          );
          final response = await _request(
            'POST',
            origin.resolve('/v1/blobs/${descriptor.manifest.hash}/grants'),
            body: {'chat_id': chatId},
          );
          if (response.statusCode != 200 && response.statusCode != 201) {
            throw StateError('secret_stream_grant_${response.statusCode}');
          }
          _checkOpen();
          return 'nios-stream:${descriptor.manifest.hash}';
        } finally {
          descriptor.dispose();
        }
      });

  Future<http.Response> _request(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
  }) async {
    final abort = Completer<void>();
    final unregister = _cancellation.onCancel(() {
      if (!abort.isCompleted) abort.complete();
    });
    final deadline = Timer(const Duration(seconds: 20), () {
      if (!abort.isCompleted) abort.complete();
    });
    try {
      final request =
          http.AbortableRequest(method, uri, abortTrigger: abort.future)
            ..followRedirects = false
            ..headers['Authorization'] = 'Bearer ${_token()}';
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 20));
      final bytes = <int>[];
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 20),
      )) {
        _checkOpen();
        if (bytes.length + chunk.length > 64 * 1024) {
          throw const FormatException('secret_stream_response_too_large');
        }
        bytes.addAll(chunk);
      }
      return http.Response.bytes(
        bytes,
        response.statusCode,
        headers: response.headers,
      );
    } finally {
      deadline.cancel();
      unregister();
    }
  }

  Future<_Download> _acquire(Map<String, dynamic> file) async {
    _checkOpen();
    final descriptor = SecretStreamDescriptor.fromFile(file);
    final hash = descriptor.manifest.hash;
    try {
      await _closingDownloads[hash];
      _checkOpen();
    } catch (_) {
      descriptor.dispose();
      rethrow;
    }
    final existing = _downloads[hash];
    if (existing != null) {
      try {
        final download = await existing;
        _checkOpen();
        if (!_sameBytes(download.key, descriptor.key)) {
          throw const FormatException('secret_stream_key_changed');
        }
        download.references++;
        return download;
      } finally {
        descriptor.dispose();
      }
    }
    final opening = () async {
      try {
        final root = await directory();
        _checkOpen();
        final local = File(
          p.join(
            root.path,
            'secret_stream',
            'outgoing',
            descriptor.manifest.objectId,
            'content.nsc',
          ),
        );
        final sources = <StreamCiphertextSource>[];
        if (await local.exists()) sources.add(FileCiphertextSource(local.path));
        // The server authenticates the enrolled device and checks its grant.
        // A local authored copy can be played even while enrollment is offline.
        if (sources.isEmpty) await ensureRegistered();
        sources.add(_store().sourceFor(descriptor.manifest));
        final downloadKey = Uint8List.fromList(descriptor.key);
        NiosStreamDownload? download;
        try {
          download = await NiosStreamDownload.open(
            directory: p.join(root.path, 'secret_stream', 'downloads', hash),
            manifest: descriptor.manifest,
            key: SecretKey(downloadKey),
            sources: sources,
            cancellation: _cancellation,
            cryptoExecutor: _crypto.run,
          );
          _checkOpen();
          return _Download(download, downloadKey);
        } catch (_) {
          await download?.close();
          downloadKey.fillRange(0, downloadKey.length, 0);
          rethrow;
        }
      } finally {
        descriptor.dispose();
      }
    }();
    _downloads[hash] = opening;
    try {
      return await opening;
    } catch (_) {
      if (identical(_downloads[hash], opening)) _downloads.remove(hash);
      rethrow;
    }
  }

  Future<void> _release(String hash, _Download entry) async {
    entry.references--;
    if (entry.references != 0 || _closing != null) return;
    _downloads.remove(hash);
    final closing = entry.download.close().whenComplete(
      () => entry.key.fillRange(0, entry.key.length, 0),
    );
    _closingDownloads[hash] = closing;
    try {
      await closing;
    } finally {
      if (identical(_closingDownloads[hash], closing)) {
        _closingDownloads.remove(hash);
      }
    }
  }

  void markJournaled(Map<String, dynamic> file) {
    final descriptor = SecretStreamDescriptor.fromFile(file);
    _prepared.remove(descriptor.manifest.objectId);
    descriptor.dispose();
  }

  /// Collection follows a successful journal restore/commit. Preparations stay
  /// reserved until their caller has recorded the descriptor durably.
  Future<void> retainOutgoing(Set<String> retainedAttachmentIds) => _job(
    () async {
      final root = Directory(
        p.join((await directory()).path, 'secret_stream', 'outgoing'),
      );
      if (!await root.exists()) return;
      final resolvedRoot = await root.resolveSymbolicLinks();
      await for (final entity in root.list(followLinks: false)) {
        if (entity is! Directory) continue;
        final id = p.basename(entity.path);
        if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(id) ||
            _prepared.contains(id) ||
            retainedAttachmentIds.contains('stream_$id')) {
          continue;
        }
        _checkOpen();
        final resolved = await entity.resolveSymbolicLinks();
        if (!p.isWithin(resolvedRoot, resolved) || p.basename(resolved) != id) {
          throw StateError('secret_stream_cleanup_path_invalid');
        }
        await Directory(resolved).delete(recursive: true);
      }
    },
  );

  Future<MediaPlaybackSource> openPlayback(Map<String, dynamic> file) =>
      _job(() async {
        final descriptor = SecretStreamDescriptor.fromFile(file);
        final hash = descriptor.manifest.hash;
        final mime = descriptor.mimeType;
        descriptor.dispose();
        final entry = await _acquire(file);
        AuthenticatedMediaGateway? gateway;
        try {
          gateway = await AuthenticatedMediaGateway.bind(
            download: entry.download,
            mimeType: mime,
          );
          _gateways.add(gateway);
          _checkOpen();
          final openedGateway = gateway;
          return MediaPlaybackSource.network(
            openedGateway.uri,
            release: () async {
              await openedGateway.close();
              _gateways.remove(openedGateway);
              await _release(hash, entry);
            },
          );
        } catch (_) {
          await gateway?.close();
          _gateways.remove(gateway);
          await _release(hash, entry);
          rethrow;
        }
      });

  /// Images/documents that require an in-memory buffer still use the same
  /// resumable authenticated cache. Native video/audio use [openPlayback].
  Future<Uint8List> readBytes(
    Map<String, dynamic> file, {
    int maximumBytes = 64 * 1024 * 1024,
  }) => _job(() async {
    final descriptor = SecretStreamDescriptor.fromFile(file);
    final manifest = descriptor.manifest;
    descriptor.dispose();
    if (manifest.plaintextLength > maximumBytes) {
      throw StateError('secret_stream_explicit_export_required');
    }
    final entry = await _acquire(file);
    final bytes = Uint8List(manifest.plaintextLength);
    try {
      var cursor = 0;
      while (cursor < bytes.length) {
        final end = (cursor + 256 * 1024).clamp(0, bytes.length);
        final part = await entry.download.readRange(
          cursor,
          end,
          cancellation: _cancellation,
        );
        try {
          bytes.setRange(cursor, end, part);
        } finally {
          part.fillRange(0, part.length, 0);
        }
        cursor = end;
      }
      return bytes;
    } catch (_) {
      bytes.fillRange(0, bytes.length, 0);
      rethrow;
    } finally {
      await _release(manifest.hash, entry);
    }
  });

  /// An explicitly requested export is streamed to one account-private staging
  /// file for the native save/share dialog. It is removed after that dialog
  /// copies it, including errors. This is never used by a media player.
  Future<void> withExport(
    Map<String, dynamic> file,
    Future<void> Function(String path) consume,
  ) => _job(() async {
    final descriptor = SecretStreamDescriptor.fromFile(file);
    final manifest = descriptor.manifest;
    descriptor.dispose();
    final entry = await _acquire(file);
    Directory? staging;
    try {
      final root = Directory(
        p.join((await directory()).path, 'secret_stream', 'exports'),
      );
      await root.create(recursive: true);
      staging = await root.createTemp('export_');
      final filename = p
          .basename(file['name'] as String? ?? 'attachment')
          .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_');
      final output = await File(
        p.join(
          staging.path,
          filename.isEmpty || filename == '.' || filename == '..'
              ? 'attachment'
              : filename,
        ),
      ).open(mode: FileMode.write);
      try {
        for (var index = 0; index < manifest.segmentCount; index++) {
          final bytes = await entry.download.fetchSegment(
            index,
            cancellation: _cancellation,
          );
          try {
            await output.writeFrom(bytes);
          } finally {
            bytes.fillRange(0, bytes.length, 0);
          }
        }
        await output.flush();
      } finally {
        await output.close();
      }
      _checkOpen();
      final stopped = Completer<void>();
      final unregister = _cancellation.onCancel(() {
        if (!stopped.isCompleted) stopped.complete();
      });
      try {
        await Future.any<void>([
          consume(output.path),
          stopped.future.then((_) => _cancellation.throwIfCancelled()),
        ]);
      } finally {
        unregister();
      }
    } finally {
      try {
        if (staging != null && await staging.exists()) {
          final parent = await staging.parent.resolveSymbolicLinks();
          final resolved = await staging.resolveSymbolicLinks();
          if (!p.isWithin(parent, resolved) ||
              !p.basename(resolved).startsWith('export_')) {
            throw StateError('secret_stream_export_path_invalid');
          }
          await Directory(resolved).delete(recursive: true);
        }
      } finally {
        await _release(manifest.hash, entry);
      }
    }
  });

  Future<void> close() {
    if (_closing != null) return _closing!;
    final done = Completer<void>();
    _closing = done.future;
    _cancellation.cancel();
    final cryptoStopped = _crypto.close();
    if (_ownsClient) _client.close();
    unawaited(
      () async {
        await Future.wait(_gateways.map((g) => g.close()));
        await Future.wait(List.of(_jobs));
        await cryptoStopped;
        await Future.wait(List.of(_closingDownloads.values));
        for (final pending in _downloads.values.toList()) {
          try {
            final entry = await pending;
            await entry.download.close();
            entry.key.fillRange(0, entry.key.length, 0);
          } catch (_) {
            /* An opening operation already reports its failure. */
          }
        }
        _downloads.clear();
        _gateways.clear();
      }().then(done.complete, onError: done.completeError),
    );
    return done.future;
  }
}

final class _Download {
  _Download(this.download, this.key);
  final NiosStreamDownload download;
  final Uint8List key;
  int references = 1;
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var difference = 0;
  for (var i = 0; i < a.length; i++) {
    difference |= a[i] ^ b[i];
  }
  return difference == 0;
}
