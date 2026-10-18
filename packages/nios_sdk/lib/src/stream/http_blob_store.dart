import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as digest;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:universal_io/io.dart';

import 'cancellation.dart';
import 'crypto_executor.dart';
import 'manifest.dart';
import 'source.dart';

final class PublishedCiphertextBlob {
  final String manifestHash;
  final int ciphertextLength;
  final Uri uri;

  const PublishedCiphertextBlob({
    required this.manifestHash,
    required this.ciphertextLength,
    required this.uri,
  });
}

/// Publishes immutable ciphertext to an authenticated server. The server receipt
/// confirms its claimed durable storage; receivers still verify the trusted
/// manifest and AEAD before accepting any content.
final class HttpCiphertextBlobStore {
  final Uri baseUri;
  final String bearerToken;
  final Duration timeout;
  final bool _allowInsecureLoopback;
  final StreamCryptoExecutor cryptoExecutor;

  HttpCiphertextBlobStore({
    required this.baseUri,
    required this.bearerToken,
    this.timeout = const Duration(minutes: 5),
    bool allowInsecureLoopback = false,
    this.cryptoExecutor = executeStreamCrypto,
  }) : _allowInsecureLoopback = allowInsecureLoopback {
    final loopback = const {
      'localhost',
      '127.0.0.1',
      '::1',
    }.contains(baseUri.host);
    if ((baseUri.scheme != 'https' &&
            !(allowInsecureLoopback && loopback && baseUri.scheme == 'http')) ||
        baseUri.userInfo.isNotEmpty ||
        baseUri.host.isEmpty ||
        baseUri.hasQuery ||
        baseUri.hasFragment ||
        bearerToken.isEmpty ||
        bearerToken.length > 4096 ||
        timeout <= Duration.zero) {
      throw ArgumentError('Invalid authenticated ciphertext endpoint');
    }
  }

  Uri _manifestUri(String hash) => baseUri.resolve('/v1/manifests/$hash');
  Uri _blobUri(String hash) => baseUri.resolve('/v1/blobs/$hash');

  HttpRangeCiphertextSource sourceFor(NiosStreamManifest manifest) =>
      HttpRangeCiphertextSource(
        uri: _blobUri(manifest.hash),
        totalLength: manifest.ciphertextLength,
        headers: {'authorization': 'Bearer $bearerToken'},
        timeout: timeout,
        allowInsecureLoopback: _allowInsecureLoopback,
      );

  Future<PublishedCiphertextBlob> ensurePublished({
    required NiosStreamManifest manifest,
    required String ciphertextPath,
    StreamCancellation? cancellation,
  }) async {
    cancellation?.throwIfCancelled();
    final head = await _send(
      'HEAD',
      _blobUri(manifest.hash),
      cancellation: cancellation,
    );
    if (head.status == 200) return _receipt(manifest, head);
    if (head.status != 404) {
      throw CiphertextBlobException('head_${head.status}');
    }
    final file = File(ciphertextPath);
    if (await file.length() != manifest.ciphertextLength) {
      throw const FormatException('Prepared ciphertext length mismatch');
    }
    final canonicalManifest = manifest.canonicalBytes;
    final manifestResponse = await _send(
      'PUT',
      _manifestUri(manifest.hash),
      body: Stream.value(canonicalManifest),
      contentLength: canonicalManifest.length,
      cancellation: cancellation,
    );
    if (manifestResponse.status != 201 && manifestResponse.status != 200) {
      throw CiphertextBlobException('manifest_${manifestResponse.status}');
    }
    final response = await _send(
      'PUT',
      _blobUri(manifest.hash),
      body: _verifiedBody(file, manifest, cancellation),
      contentLength: manifest.ciphertextLength,
      cancellation: cancellation,
    );
    if (response.status != 201 && response.status != 200) {
      throw CiphertextBlobException('publish_${response.status}');
    }
    return _receipt(manifest, response);
  }

  Stream<List<int>> _verifiedBody(
    File source,
    NiosStreamManifest manifest,
    StreamCancellation? cancellation,
  ) async* {
    final file = await source.open();
    try {
      if (await file.length() != manifest.ciphertextLength) {
        throw const FormatException('Prepared ciphertext length changed');
      }
      for (var index = 0; index < manifest.segmentCount; index++) {
        cancellation?.throwIfCancelled();
        final segment = Uint8List(manifest.segmentCiphertextLength(index));
        var position = 0;
        while (position < segment.length) {
          cancellation?.throwIfCancelled();
          final read = await file.readInto(
            segment,
            position,
            min(position + 64 * 1024, segment.length),
          );
          if (read == 0) {
            throw const FormatException('Truncated prepared ciphertext');
          }
          position += read;
        }
        if ((await cryptoExecutor(
              StreamCryptoRequest(
                operation: StreamCryptoOperation.hash,
                bytes: segment,
              ),
            )).hash !=
            manifest.segmentHashes[index]) {
          throw const FormatException('Prepared ciphertext integrity failure');
        }
        cancellation?.throwIfCancelled();
        // Never hand an unchecked segment to the HTTP sink, even if a caller
        // accidentally supplied a different same-sized file or the disk broke.
        yield segment;
      }
      if (await file.length() != manifest.ciphertextLength) {
        throw const FormatException('Prepared ciphertext length changed');
      }
    } finally {
      await file.close();
    }
  }

  PublishedCiphertextBlob _receipt(
    NiosStreamManifest manifest,
    _BlobResponse response,
  ) {
    if (response.headers['x-nios-manifest-hash'] != manifest.hash ||
        response.headers['x-nios-ciphertext-length'] !=
            '${manifest.ciphertextLength}') {
      throw const FormatException('Invalid immutable blob receipt');
    }
    return PublishedCiphertextBlob(
      manifestHash: manifest.hash,
      ciphertextLength: manifest.ciphertextLength,
      uri: _blobUri(manifest.hash),
    );
  }

  Future<_BlobResponse> _send(
    String method,
    Uri uri, {
    Stream<List<int>>? body,
    int contentLength = 0,
    StreamCancellation? cancellation,
  }) async {
    final client = http.Client();
    final abort = Completer<void>();
    StreamIterator<List<int>>? producer;
    Future<void>? producerClosing;
    Object? producerFailure;
    StackTrace? producerStack;
    void cancel() {
      if (!abort.isCompleted) abort.complete();
      client.close();
    }

    void failProducer(Object error, StackTrace stack) {
      producerFailure ??= error;
      producerStack ??= stack;
      cancel();
    }

    Future<void> closeProducer() => producerClosing ??= () async {
      try {
        await producer?.cancel();
      } catch (error, stack) {
        // Cleanup errors belong to this operation as well, never to the HTTP
        // body stream or an unobserved sibling future.
        failProducer(error, stack);
      }
    }();

    Stream<List<int>> safeBody() async* {
      if (body == null || abort.isCompleted) return;
      final iterator = StreamIterator(body);
      producer = iterator;
      try {
        while (await iterator.moveNext()) {
          cancellation?.throwIfCancelled();
          if (abort.isCompleted) return;
          // Yielding directly preserves HTTP backpressure: only one verified
          // segment is live. Unlike StreamedRequest.sink.addStream, producer
          // errors are caught here before they can enter IOClient's body pipe.
          yield iterator.current;
        }
      } catch (error, stack) {
        failProducer(error, stack);
      } finally {
        await closeProducer();
      }
    }

    final unregister = cancellation?.onCancel(cancel);
    final deadline = Timer(timeout, cancel);
    try {
      cancellation?.throwIfCancelled();
      final request =
          _AbortableBlobRequest(method, uri, abort.future, safeBody())
            ..followRedirects = false
            ..headers['authorization'] = 'Bearer $bearerToken'
            ..headers['content-type'] = 'application/octet-stream'
            ..contentLength = contentLength;
      final response = await client.send(request).timeout(timeout);
      var received = 0;
      await for (final chunk in response.stream.timeout(timeout)) {
        cancellation?.throwIfCancelled();
        received += chunk.length;
        if (received > 4096) {
          throw const FormatException('Oversized blob receipt');
        }
      }
      cancellation?.throwIfCancelled();
      if (producerFailure != null) {
        Error.throwWithStackTrace(producerFailure!, producerStack!);
      }
      return _BlobResponse(response.statusCode, response.headers);
    } catch (_) {
      cancellation?.throwIfCancelled();
      if (producerFailure != null) {
        Error.throwWithStackTrace(producerFailure!, producerStack!);
      }
      rethrow;
    } finally {
      deadline.cancel();
      unregister?.call();
      cancel();
      // A cancelled async generator can still be finishing a disk read. Wait
      // for its single shared cleanup before account deletion may remove files.
      await closeProducer();
    }
  }
}

final class _AbortableBlobRequest extends http.BaseRequest with http.Abortable {
  final Stream<List<int>> _body;

  _AbortableBlobRequest(super.method, super.url, this.abortTrigger, this._body);

  @override
  final Future<void> abortTrigger;

  @override
  http.ByteStream finalize() {
    super.finalize();
    return http.ByteStream(_body);
  }
}

final class _BlobResponse {
  final int status;
  final Map<String, String> headers;
  const _BlobResponse(this.status, this.headers);
}

final class CiphertextBlobException implements Exception {
  final String code;
  const CiphertextBlobException(this.code);
  @override
  String toString() => 'CiphertextBlobException($code)';
}

/// Loopback reference implementation for integration tests and embedded tools.
/// It is not a production deployment: no account provisioning, quota database,
/// TLS termination, retention policy or public listener is configured here.
/// Only public manifests and immutable ciphertext are accepted, never keys.
final class CiphertextBlobServer {
  static final Set<String> _openDirectories = {};
  final String directory;
  final String _bearerToken;
  final HttpServer _server;
  final int maximumCiphertextLength;
  final Duration requestTimeout;
  final bool _secure;
  final RandomAccessFile _directoryLock;
  final String _directoryLease;
  final Set<Future<void>> _handlers = {};
  final Map<String, Future<void>> _writes = {};
  bool _closed = false;
  Future<void>? _closing;

  CiphertextBlobServer._(
    this.directory,
    this._bearerToken,
    this._server,
    this.maximumCiphertextLength,
    this.requestTimeout,
    this._secure,
    this._directoryLock,
    this._directoryLease,
  ) {
    _server.listen((request) {
      if (_closed || _handlers.length >= 8) {
        request.response.statusCode = 503;
        request.response.persistentConnection = false;
        unawaited(request.response.close());
        return;
      }
      final handling = _handle(request);
      _handlers.add(handling);
      unawaited(handling.then((_) => _handlers.remove(handling)));
    });
  }

  static Future<CiphertextBlobServer> bind({
    required String directory,
    required String bearerToken,
    int port = 0,
    int maximumCiphertextLength = 1024 * 1024 * 1024,
    Duration requestTimeout = const Duration(seconds: 30),
    SecurityContext? securityContext,
  }) async {
    if (bearerToken.isEmpty ||
        bearerToken.length > 4096 ||
        maximumCiphertextLength < 0 ||
        requestTimeout <= Duration.zero) {
      throw ArgumentError('Invalid reference blob server configuration');
    }
    final root = await Directory(directory).create(recursive: true);
    final directoryLease = await root.resolveSymbolicLinks();
    if (!_openDirectories.add(directoryLease)) {
      throw StateError('This ciphertext blob directory is already open');
    }
    RandomAccessFile? directoryLock;
    try {
      directoryLock = await File(
        p.join(directory, 'blob-store.lock'),
      ).open(mode: FileMode.append);
      await directoryLock.lock(FileLock.exclusive);
      for (final name in ['manifests', 'blobs']) {
        final contents = await Directory(
          p.join(directory, name),
        ).create(recursive: true);
        // The exclusive owner may reclaim unfinished files after a killed
        // process. Never acknowledge or promote an unverified staging file.
        await for (final entry in contents.list(followLinks: false)) {
          if (entry is File &&
              RegExp(
                r'^[a-f0-9]{64}\.(json|nsc)\.\d+\.partial$',
              ).hasMatch(p.basename(entry.path))) {
            await entry.delete();
          }
        }
      }
      final server = securityContext == null
          ? await HttpServer.bind(InternetAddress.loopbackIPv4, port)
          : await HttpServer.bindSecure(
              InternetAddress.loopbackIPv4,
              port,
              securityContext,
            );
      return CiphertextBlobServer._(
        directory,
        bearerToken,
        server,
        maximumCiphertextLength,
        requestTimeout,
        securityContext != null,
        directoryLock,
        directoryLease,
      );
    } catch (_) {
      if (directoryLock != null) {
        try {
          await directoryLock.unlock();
        } on FileSystemException {
          // The lock may not have been acquired.
        }
        await directoryLock.close();
      }
      _openDirectories.remove(directoryLease);
      rethrow;
    }
  }

  Uri get baseUri =>
      Uri.parse('${_secure ? 'https' : 'http'}://127.0.0.1:${_server.port}/');

  Future<void> _handle(HttpRequest request) async {
    try {
      if (!_tokenEquals(
        request.headers.value('authorization') ?? '',
        'Bearer $_bearerToken',
      )) {
        request.response.statusCode = 401;
        request.response.persistentConnection = false;
        return;
      }
      final parts = request.uri.pathSegments;
      if (request.uri.hasQuery ||
          parts.length != 3 ||
          parts[0] != 'v1' ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(parts[2])) {
        request.response.statusCode = 404;
        return;
      }
      final hash = parts[2];
      if (parts[1] == 'manifests' && request.method == 'PUT') {
        await _serialized('manifest:$hash', () => _putManifest(request, hash));
      } else if (parts[1] == 'blobs') {
        if (request.method == 'PUT') {
          await _serialized('blob:$hash', () => _putBlob(request, hash));
        } else if (request.method == 'HEAD' || request.method == 'GET') {
          await _getBlob(request, hash);
        } else {
          request.response.statusCode = 405;
        }
      } else {
        request.response.statusCode = 404;
      }
    } on FormatException {
      request.response.statusCode = 422;
      request.response.persistentConnection = false;
    } catch (_) {
      try {
        request.response.statusCode = 500;
        request.response.persistentConnection = false;
      } catch (_) {
        // A response may already be in flight when a client disconnects.
      }
    } finally {
      try {
        await request.response.close();
      } catch (_) {
        // Aborted sockets do not change immutable publication state.
      }
    }
  }

  Future<void> _putManifest(HttpRequest request, String hash) async {
    const bound = 80 * 1024 * 1024;
    if (request.contentLength < 0 || request.contentLength > bound) {
      throw const FormatException('Invalid manifest length');
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in request.timeout(requestTimeout)) {
      if (bytes.length + chunk.length > bound) {
        throw const FormatException('Oversized manifest');
      }
      bytes.add(chunk);
    }
    final json = jsonDecode(utf8.decode(bytes.takeBytes()));
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Invalid manifest');
    }
    final manifest = NiosStreamManifest.fromJson(json, expectedHash: hash);
    if (manifest.ciphertextLength > maximumCiphertextLength) {
      throw const FormatException('Blob quota exceeded');
    }
    final target = File(p.join(directory, 'manifests', '$hash.json'));
    if (await target.exists()) {
      final existing = await _loadManifest(hash);
      if (existing.hash != manifest.hash) {
        throw const FormatException('Manifest collision');
      }
      request.response.statusCode = 200;
      return;
    }
    await _atomicBlobWrite(target.path, Stream.value(manifest.canonicalBytes));
    request.response.statusCode = 201;
  }

  Future<NiosStreamManifest> _loadManifest(String hash) async {
    final file = File(p.join(directory, 'manifests', '$hash.json'));
    if (!await file.exists() || await file.length() > 80 * 1024 * 1024) {
      throw const FormatException('Missing or oversized manifest');
    }
    final json = jsonDecode(await file.readAsString());
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Invalid stored manifest');
    }
    return NiosStreamManifest.fromJson(json, expectedHash: hash);
  }

  Future<void> _putBlob(HttpRequest request, String hash) async {
    final manifest = await _loadManifest(hash);
    if (request.contentLength != manifest.ciphertextLength) {
      throw const FormatException('Ciphertext upload length mismatch');
    }
    final target = File(p.join(directory, 'blobs', '$hash.nsc'));
    final temporary = File(
      '${target.path}.${Random.secure().nextInt(1 << 32)}.partial',
    );
    RandomAccessFile? file;
    try {
      file = await temporary.open(mode: FileMode.write);
      var segmentIndex = 0;
      var segment = manifest.segmentCount == 0
          ? Uint8List(0)
          : Uint8List(manifest.segmentCiphertextLength(0));
      var position = 0;
      var total = 0;
      var integrityFailure = false;
      await for (final chunk in request.timeout(requestTimeout)) {
        if (total + chunk.length > manifest.ciphertextLength) {
          throw const FormatException('Oversized ciphertext upload');
        }
        var cursor = 0;
        while (cursor < chunk.length) {
          final count = min(segment.length - position, chunk.length - cursor);
          if (count <= 0) {
            throw const FormatException('Unexpected ciphertext segment');
          }
          segment.setRange(position, position + count, chunk, cursor);
          cursor += count;
          position += count;
          if (position == segment.length) {
            if (digest.sha256.convert(segment).toString() !=
                manifest.segmentHashes[segmentIndex]) {
              integrityFailure = true;
            }
            // Consume the declared bounded request before returning 422. An
            // early cancellation of HttpRequest's body stream resets its TCP
            // socket and can discard the error response before the client
            // receives it. Once integrity fails no more bytes reach disk.
            if (!integrityFailure) {
              for (
                var offset = 0;
                offset < segment.length;
                offset += 64 * 1024
              ) {
                await file.writeFrom(
                  segment,
                  offset,
                  min(offset + 64 * 1024, segment.length),
                );
              }
            }
            segmentIndex++;
            position = 0;
            if (segmentIndex < manifest.segmentCount) {
              segment = Uint8List(
                manifest.segmentCiphertextLength(segmentIndex),
              );
            }
          }
        }
        total += chunk.length;
      }
      if (total != manifest.ciphertextLength ||
          position != 0 ||
          segmentIndex != manifest.segmentCount) {
        throw const FormatException('Truncated ciphertext upload');
      }
      if (integrityFailure) {
        throw const FormatException(
          'Ciphertext segment upload integrity failure',
        );
      }
      await file.flush();
      await file.close();
      file = null;
      // Repeated PUT is verified before acknowledging the existing immutable
      // identity. Atomic replacement also repairs an existing damaged disk file.
      final existed = await target.exists();
      await temporary.rename(target.path);
      request.response.statusCode = existed ? 200 : 201;
      _setReceipt(request.response, manifest);
    } finally {
      await file?.close();
      if (await temporary.exists()) await temporary.delete();
    }
  }

  Future<void> _getBlob(HttpRequest request, String hash) async {
    final file = File(p.join(directory, 'blobs', '$hash.nsc'));
    if (!await file.exists()) {
      request.response.statusCode = 404;
      return;
    }
    final manifest = await _loadManifest(hash);
    if (await file.length() != manifest.ciphertextLength) {
      throw const FormatException('Stored ciphertext length mismatch');
    }
    _setReceipt(request.response, manifest);
    request.response.headers.set('accept-ranges', 'bytes');
    request.response.headers.set('cache-control', 'private, immutable');
    if (request.method == 'HEAD') {
      request.response.contentLength = manifest.ciphertextLength;
      return;
    }
    final range = request.headers.value('range');
    final match = range == null
        ? null
        : RegExp(r'^bytes=(\d+)-(\d+)$').firstMatch(range);
    final start = match == null ? null : int.tryParse(match[1]!);
    final end = match == null ? null : int.tryParse(match[2]!);
    if (start == null ||
        end == null ||
        start < 0 ||
        end < start ||
        end >= manifest.ciphertextLength ||
        end - start + 1 > NiosStreamManifest.maximumSegmentSize + 16) {
      request.response.statusCode = 416;
      request.response.headers.set(
        'content-range',
        'bytes */${manifest.ciphertextLength}',
      );
      return;
    }
    request.response
      ..statusCode = 206
      ..contentLength = end - start + 1
      ..headers.set(
        'content-range',
        'bytes $start-$end/${manifest.ciphertextLength}',
      );
    await request.response.addStream(file.openRead(start, end + 1));
  }

  void _setReceipt(HttpResponse response, NiosStreamManifest manifest) {
    response.headers.set('x-nios-manifest-hash', manifest.hash);
    response.headers.set(
      'x-nios-ciphertext-length',
      '${manifest.ciphertextLength}',
    );
  }

  Future<void> _serialized(
    String identity,
    Future<void> Function() action,
  ) async {
    final previous = _writes[identity] ?? Future<void>.value();
    final current = previous.then((_) => action());
    final tail = current.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _writes[identity] = tail;
    try {
      await current;
    } finally {
      if (identical(_writes[identity], tail)) _writes.remove(identity);
    }
  }

  Future<void> close() {
    if (_closing != null) return _closing!;
    _closed = true;
    return _closing = () async {
      try {
        await _server.close(force: true);
        await Future.wait(_handlers.toList());
      } finally {
        try {
          await _directoryLock.unlock();
        } finally {
          await _directoryLock.close();
          _openDirectories.remove(_directoryLease);
        }
      }
    }();
  }
}

Future<void> _atomicBlobWrite(String path, Stream<List<int>> contents) async {
  final temporary = File('$path.${Random.secure().nextInt(1 << 32)}.partial');
  RandomAccessFile? file;
  try {
    file = await temporary.open(mode: FileMode.write);
    await for (final chunk in contents) {
      await file.writeFrom(chunk);
    }
    await file.flush();
    await file.close();
    file = null;
    await temporary.rename(path);
  } finally {
    await file?.close();
    if (await temporary.exists()) await temporary.delete();
  }
}

bool _tokenEquals(String left, String right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left.codeUnitAt(index) ^ right.codeUnitAt(index);
  }
  return difference == 0;
}
