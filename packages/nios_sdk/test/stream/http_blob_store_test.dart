import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:nios_sdk/stream.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

const _token = 'loopback-test-token-not-a-production-credential';

void main() {
  late Directory temporary;
  late SecurityContext tls;
  final servers = <CiphertextBlobServer>[];

  setUpAll(() {
    // Only this isolated test process trusts the public test fixture. Normal
    // TLS host/certificate verification remains enabled for every HTTP client.
    SecurityContext.defaultContext.setTrustedCertificates(
      'test/stream/support/localhost-test-cert.pem',
    );
  });
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('nios_blob_test_');
    tls = SecurityContext()
      ..useCertificateChain('test/stream/support/localhost-test-cert.pem')
      ..usePrivateKey('test/stream/support/localhost-test-key.pem');
  });
  tearDown(() async {
    for (final server in servers.reversed) {
      await server.close();
    }
    servers.clear();
    if (await temporary.exists()) await temporary.delete(recursive: true);
  });

  Future<PreparedStreamObject> prepare({int length = 12345}) async {
    final input = File(p.join(temporary.path, 'input'));
    await input.writeAsBytes(
      List.generate(length, (index) => (index * 13) % 251),
      flush: true,
    );
    return NiosStream.prepareFile(
      inputPath: input.path,
      outputDirectory: p.join(temporary.path, 'prepared'),
      segmentSize: 1024,
    );
  }

  Future<CiphertextBlobServer> serve({
    String name = 'server',
    int? quota,
  }) async {
    final server = await CiphertextBlobServer.bind(
      directory: p.join(temporary.path, name),
      bearerToken: _token,
      securityContext: tls,
      maximumCiphertextLength: quota ?? 1024 * 1024 * 1024,
    );
    servers.add(server);
    return server;
  }

  HttpCiphertextBlobStore store(CiphertextBlobServer server) =>
      HttpCiphertextBlobStore(baseUri: server.baseUri, bearerToken: _token);

  test(
    'real HTTPS publication is immutable, reusable and survives restart',
    () async {
      final object = await prepare();
      var server = await serve();
      var publisher = store(server);
      final receipt = await publisher.ensurePublished(
        manifest: object.manifest,
        ciphertextPath: object.ciphertextPath,
      );
      expect(receipt.uri.scheme, 'https');
      expect(receipt.manifestHash, object.manifest.hash);
      expect(receipt.ciphertextLength, object.manifest.ciphertextLength);
      final stored = File(
        p.join(server.directory, 'blobs', '${object.manifest.hash}.nsc'),
      );
      final original = await stored.readAsBytes();
      final modified = await stored.lastModified();
      expect(original, await File(object.ciphertextPath).readAsBytes());
      final repeated = await publisher.ensurePublished(
        manifest: object.manifest,
        // HEAD must reuse durable ciphertext even if a local source was removed.
        ciphertextPath: p.join(temporary.path, 'no-longer-present'),
      );
      expect(repeated.manifestHash, receipt.manifestHash);
      expect(await stored.lastModified(), modified);
      await server.close();
      server = await serve();
      publisher = store(server);
      final download = await NiosStreamDownload.open(
        directory: p.join(temporary.path, 'download'),
        manifest: object.manifest,
        key: object.key,
        sources: [publisher.sourceFor(object.manifest)],
      );
      try {
        expect(await download.readRange(2040, 4090), [
          for (var index = 2040; index < 4090; index++) (index * 13) % 251,
        ]);
        expect(download.verifiedSegmentCount, 3);
      } finally {
        await download.close();
      }
      expect(await stored.readAsBytes(), original);
    },
  );

  test(
    'empty object publishes and returns a durable zero-length HEAD',
    () async {
      final object = await prepare(length: 0);
      final server = await serve();
      final publisher = store(server);
      await publisher.ensurePublished(
        manifest: object.manifest,
        ciphertextPath: object.ciphertextPath,
      );
      final response = await _request(
        'HEAD',
        server.baseUri.resolve('/v1/blobs/${object.manifest.hash}'),
      );
      expect(response.status, 200);
      expect(response.headers['x-nios-ciphertext-length'], '0');
      expect(response.bytes, isEmpty);
    },
  );

  test(
    'authentication fails closed without creating manifest or blob',
    () async {
      final object = await prepare();
      final server = await serve();
      await expectLater(
        HttpCiphertextBlobStore(
          baseUri: server.baseUri,
          bearerToken: 'wrong-token',
        ).ensurePublished(
          manifest: object.manifest,
          ciphertextPath: object.ciphertextPath,
        ),
        throwsA(
          isA<CiphertextBlobException>().having(
            (error) => error.code,
            'code',
            'head_401',
          ),
        ),
      );
      for (final name in ['manifests', 'blobs']) {
        expect(
          await Directory(p.join(server.directory, name)).list().toList(),
          isEmpty,
        );
      }
      await expectLater(
        HttpRangeCiphertextSource(
          uri: server.baseUri.resolve('/v1/blobs/${object.manifest.hash}'),
          totalLength: object.manifest.ciphertextLength,
        ).readRange(0, object.manifest.segmentCiphertextLength(0)),
        throwsFormatException,
      );
    },
  );

  test('corrupt upload never publishes and cleans its staging file', () async {
    final object = await prepare();
    final server = await serve();
    final broken = File(p.join(temporary.path, 'broken.nsc'));
    final bytes = await File(object.ciphertextPath).readAsBytes();
    bytes[0] ^= 255;
    await broken.writeAsBytes(bytes, flush: true);
    await expectLater(
      store(
        server,
      ).ensurePublished(manifest: object.manifest, ciphertextPath: broken.path),
      throwsFormatException,
    );
    expect(
      await Directory(p.join(server.directory, 'blobs')).list().toList(),
      isEmpty,
    );
    await store(server).ensurePublished(
      manifest: object.manifest,
      ciphertextPath: object.ciphertextPath,
    );
  });

  test(
    'wrong same-sized local input sends no unchecked bytes and fails promptly',
    () async {
      final object = await prepare();
      final wrong = File(p.join(temporary.path, 'wrong-same-size-file'));
      await wrong.writeAsBytes(
        List.filled(object.manifest.ciphertextLength, 0),
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var uncheckedBytes = 0;
      server.listen((request) async {
        if (request.method == 'HEAD') {
          request.response.statusCode = 404;
          await request.response.close();
        } else if (request.uri.path.contains('/manifests/')) {
          await request.drain<void>();
          request.response.statusCode = 201;
          await request.response.close();
        } else {
          request.listen(
            (bytes) => uncheckedBytes += bytes.length,
            onError: (Object _) {},
          );
          // Do not send a response: a producer error must abort this request
          // immediately rather than wait for the five-minute HTTP timeout.
        }
      });
      try {
        await expectLater(
          HttpCiphertextBlobStore(
            baseUri: Uri.parse('http://127.0.0.1:${server.port}/'),
            bearerToken: _token,
            allowInsecureLoopback: true,
          ).ensurePublished(
            manifest: object.manifest,
            ciphertextPath: wrong.path,
          ),
          throwsFormatException,
        ).timeout(const Duration(seconds: 2));
        expect(uncheckedBytes, 0);
      } finally {
        await server.close(force: true);
      }
    },
  );

  test(
    'GET range is bounded and repeated PUT cannot overwrite valid identity',
    () async {
      final object = await prepare();
      final server = await serve();
      final publisher = store(server);
      await publisher.ensurePublished(
        manifest: object.manifest,
        ciphertextPath: object.ciphertextPath,
      );
      final uri = server.baseUri.resolve('/v1/blobs/${object.manifest.hash}');
      final bytes = await File(object.ciphertextPath).readAsBytes();
      final range = await _request(
        'GET',
        uri,
        headers: {'range': 'bytes=99-200'},
      );
      expect(range.status, 206);
      expect(range.headers['content-range'], 'bytes 99-200/${bytes.length}');
      expect(range.bytes, bytes.sublist(99, 201));
      for (final invalid in [
        null,
        'bytes=2-1',
        'bytes=0-',
        'bytes=0-9999999',
        'bytes=1-2,4-5',
      ]) {
        final result = await _request('GET', uri, headers: {'range': ?invalid});
        expect(result.status, 416);
        expect(result.headers['content-range'], 'bytes */${bytes.length}');
      }
      final rejected = await _request(
        'PUT',
        uri,
        body: [...bytes]..[100] ^= 255,
      );
      expect(rejected.status, 422);
      final valid = await _request('PUT', uri, body: bytes);
      expect(valid.status, 200);
      expect(valid.headers['x-nios-manifest-hash'], object.manifest.hash);
      expect(
        await publisher.sourceFor(object.manifest).readRange(0, 1024),
        bytes.sublist(0, 1024),
      );
      expect(
        await Directory(p.join(server.directory, 'blobs')).list().toList(),
        hasLength(1),
      );
    },
  );

  test(
    'upload size and configured quota are enforced before publication',
    () async {
      final object = await prepare();
      final server = await serve(quota: 100);
      await expectLater(
        store(server).ensurePublished(
          manifest: object.manifest,
          ciphertextPath: object.ciphertextPath,
        ),
        throwsA(
          isA<CiphertextBlobException>().having(
            (error) => error.code,
            'code',
            'manifest_422',
          ),
        ),
      );
      expect(
        await Directory(p.join(server.directory, 'manifests')).list().toList(),
        isEmpty,
      );
      final other = await serve(name: 'other');
      final short = File(p.join(temporary.path, 'short'));
      await short.writeAsBytes([1, 2]);
      await expectLater(
        store(other).ensurePublished(
          manifest: object.manifest,
          ciphertextPath: short.path,
        ),
        throwsFormatException,
      );
      expect(
        await Directory(p.join(other.directory, 'manifests')).list().toList(),
        isEmpty,
      );
    },
  );

  test(
    'authenticated downloads fail over after corruption and resume offline',
    () async {
      final object = await prepare();
      final first = await serve(name: 'first');
      final second = await serve(name: 'second');
      for (final server in [first, second]) {
        await store(server).ensurePublished(
          manifest: object.manifest,
          ciphertextPath: object.ciphertextPath,
        );
      }
      final corrupt = File(
        p.join(first.directory, 'blobs', '${object.manifest.hash}.nsc'),
      );
      final bytes = await corrupt.readAsBytes();
      bytes[100] ^= 255;
      await corrupt.writeAsBytes(bytes, flush: true);
      final cache = p.join(temporary.path, 'download');
      var download = await NiosStreamDownload.open(
        directory: cache,
        manifest: object.manifest,
        key: object.key,
        sources: [
          store(first).sourceFor(object.manifest),
          store(second).sourceFor(object.manifest),
        ],
      );
      expect(await download.readRange(90, 120), [
        for (var index = 90; index < 120; index++) (index * 13) % 251,
      ]);
      await download.close();
      download = await NiosStreamDownload.open(
        directory: cache,
        manifest: object.manifest,
        key: object.key,
        sources: [],
      );
      try {
        expect(download.verifiedSegmentCount, 1);
        expect(await download.readRange(90, 120), [
          for (var index = 90; index < 120; index++) (index * 13) % 251,
        ]);
        final cached = await File(p.join(cache, 'content.nsc')).readAsBytes();
        expect(cached, await object.ciphertextSource.readRange(0, 1040));
      } finally {
        await download.close();
      }
    },
  );

  test('redirects do not send bearer tokens to another endpoint', () async {
    final object = await prepare();
    var escaped = false;
    final target = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirector = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    target.listen((request) {
      escaped = true;
      unawaited(request.response.close());
    });
    redirector.listen((request) {
      request.response
        ..statusCode = 307
        ..headers.set('location', 'http://127.0.0.1:${target.port}/stolen');
      unawaited(request.response.close());
    });
    try {
      final publisher = HttpCiphertextBlobStore(
        baseUri: Uri.parse('http://127.0.0.1:${redirector.port}/'),
        bearerToken: _token,
        allowInsecureLoopback: true,
      );
      await expectLater(
        publisher.ensurePublished(
          manifest: object.manifest,
          ciphertextPath: object.ciphertextPath,
        ),
        throwsA(isA<CiphertextBlobException>()),
      );
      await expectLater(
        publisher.sourceFor(object.manifest).readRange(0, 10),
        throwsFormatException,
      );
      expect(escaped, isFalse);
    } finally {
      await redirector.close(force: true);
      await target.close(force: true);
    }
  });

  test(
    'untrusted receipt cannot turn HEAD into a successful publication',
    () async {
      final object = await prepare();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var puts = 0;
      server.listen((request) {
        if (request.method == 'PUT') puts++;
        request.response
          ..statusCode = 200
          ..headers.set('x-nios-manifest-hash', object.manifest.hash)
          ..headers.set(
            'x-nios-ciphertext-length',
            '${object.manifest.ciphertextLength + 1}',
          );
        unawaited(request.response.close());
      });
      try {
        await expectLater(
          HttpCiphertextBlobStore(
            baseUri: Uri.parse('http://127.0.0.1:${server.port}/'),
            bearerToken: _token,
            allowInsecureLoopback: true,
          ).ensurePublished(
            manifest: object.manifest,
            ciphertextPath: object.ciphertextPath,
          ),
          throwsFormatException,
        );
        expect(puts, 0);
      } finally {
        await server.close(force: true);
      }
    },
  );

  test('cancelling an in-flight upload aborts the socket promptly', () async {
    final object = await prepare(length: 2 * 1024 * 1024);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final arrived = Completer<void>();
    server.listen((request) async {
      if (request.method == 'HEAD') {
        request.response.statusCode = 404;
        await request.response.close();
      } else if (request.uri.path.contains('/manifests/')) {
        await request.drain<void>();
        request.response.statusCode = 201;
        await request.response.close();
      } else {
        arrived.complete();
        // Deliberately do not consume the body or provide a response.
      }
    });
    final cancellation = StreamCancellation();
    try {
      final future =
          HttpCiphertextBlobStore(
            baseUri: Uri.parse('http://127.0.0.1:${server.port}/'),
            bearerToken: _token,
            allowInsecureLoopback: true,
          ).ensurePublished(
            manifest: object.manifest,
            ciphertextPath: object.ciphertextPath,
            cancellation: cancellation,
          );
      final assertion = expectLater(
        future,
        throwsA(isA<StreamCancelledException>()),
      );
      await arrived.future.timeout(const Duration(seconds: 5));
      cancellation.cancel();
      await assertion.timeout(const Duration(seconds: 2));
    } finally {
      await server.close(force: true);
    }
  });

  test(
    'repeated cancellation after body bytes owns producer errors and teardown',
    () async {
      final object = await prepare(length: 2 * 1024 * 1024);
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      late StreamCancellation activeCancellation;
      late Completer<void> activeStarted;
      server.listen((request) async {
        if (request.method == 'HEAD') {
          request.response.statusCode = 404;
          await request.response.close();
        } else if (request.uri.path.contains('/manifests/')) {
          await request.drain<void>();
          request.response.statusCode = 201;
          await request.response.close();
        } else {
          final cancellation = activeCancellation;
          final started = activeStarted;
          request.listen((_) {
            if (!started.isCompleted) {
              started.complete();
              // Cancel while later verified segments can still be in disk
              // IO. On Linux this used to inject a second unhandled error
              // through StreamedRequest.sink.addStream into IOClient.pipe.
              cancellation.cancel();
            }
          }, onError: (Object _) {});
        }
      });
      try {
        final publisher = HttpCiphertextBlobStore(
          baseUri: Uri.parse('http://127.0.0.1:${server.port}/'),
          bearerToken: _token,
          allowInsecureLoopback: true,
        );
        for (var attempt = 0; attempt < 10; attempt++) {
          activeCancellation = StreamCancellation();
          activeStarted = Completer<void>();
          final cancelled = expectLater(
            publisher.ensurePublished(
              manifest: object.manifest,
              ciphertextPath: object.ciphertextPath,
              cancellation: activeCancellation,
            ),
            throwsA(isA<StreamCancelledException>()),
          );
          await activeStarted.future.timeout(const Duration(seconds: 5));
          await cancelled.timeout(const Duration(seconds: 2));
          // Completion must include producer cleanup, allowing immediate file
          // ownership changes rather than leaving a detached reader behind.
          final moved = await File(
            object.ciphertextPath,
          ).rename(p.join(object.directory, 'cancelled-$attempt.nsc'));
          await moved.rename(object.ciphertextPath);
        }
      } finally {
        await server.close(force: true);
      }
    },
  );

  test(
    'directory ownership and stale staging recovery never promote partial data',
    () async {
      final object = await prepare();
      final server = await serve();
      await expectLater(serve(), throwsStateError);
      await server.close();
      final partial = File(
        p.join(
          server.directory,
          'blobs',
          '${object.manifest.hash}.nsc.1234.partial',
        ),
      );
      await partial.writeAsBytes([1, 2, 3], flush: true);
      final unrelated = File(
        p.join(server.directory, 'blobs', 'user-file.partial'),
      );
      await unrelated.writeAsBytes([4, 5, 6]);
      final reopened = await serve();
      expect(await partial.exists(), isFalse);
      expect(await unrelated.exists(), isTrue);
      final head = await _request(
        'HEAD',
        reopened.baseUri.resolve('/v1/blobs/${object.manifest.hash}'),
      );
      expect(head.status, 404);
      await store(reopened).ensurePublished(
        manifest: object.manifest,
        ciphertextPath: object.ciphertextPath,
      );
    },
  );

  test(
    'a killed publication keeps only staging data and recovers on restart',
    () async {
      final object = await prepare();
      final root = p.join(temporary.path, 'crashed');
      final child = await Process.start(Platform.resolvedExecutable, [
        'run',
        'test/stream/support/crash_blob_server.dart',
        root,
      ]);
      final errors = StringBuffer();
      child.stderr.transform(utf8.decoder).listen(errors.write);
      Socket? socket;
      try {
        final line = await child.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .first
            .timeout(const Duration(seconds: 30));
        final uri = Uri.parse(line);
        final manifest = await _request(
          'PUT',
          uri.resolve('/v1/manifests/${object.manifest.hash}'),
          body: object.manifest.canonicalBytes,
        );
        expect(manifest.status, 201, reason: errors.toString());
        socket = await Socket.connect(uri.host, uri.port);
        socket.listen((_) {}, onError: (Object _) {});
        socket.write(
          'PUT /v1/blobs/${object.manifest.hash} HTTP/1.1\r\n'
          'Host: ${uri.host}\r\nAuthorization: Bearer $_token\r\n'
          'Content-Length: ${object.manifest.ciphertextLength}\r\n'
          'Connection: close\r\n\r\n',
        );
        socket.add(await object.ciphertextSource.readRange(0, 100));
        await socket.flush();
        final blobs = Directory(p.join(root, 'blobs'));
        final deadline = DateTime.now().add(const Duration(seconds: 5));
        while ((await blobs.list().toList()).isEmpty) {
          if (DateTime.now().isAfter(deadline)) {
            fail('Partial ciphertext was not staged: $errors');
          }
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        child.kill(ProcessSignal.sigkill);
        await child.exitCode.timeout(const Duration(seconds: 10));
        socket.destroy();
        expect(
          await File(
            p.join(blobs.path, '${object.manifest.hash}.nsc'),
          ).exists(),
          isFalse,
        );
        expect(await blobs.list().toList(), hasLength(1));
        final recovered = await serve(name: 'crashed');
        expect(await blobs.list().toList(), isEmpty);
        await store(recovered).ensurePublished(
          manifest: object.manifest,
          ciphertextPath: object.ciphertextPath,
        );
        expect(await blobs.list().toList(), hasLength(1));
      } finally {
        socket?.destroy();
        child.kill(ProcessSignal.sigkill);
      }
    },
    timeout: const Timeout(Duration(minutes: 1)),
  );

  test(
    'oversized publication receipts are rejected with bounded buffering',
    () async {
      final object = await prepare();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        await request.drain<void>();
        if (request.method == 'HEAD') {
          request.response.statusCode = 404;
        } else {
          request.response.statusCode = 201;
          if (request.uri.path.contains('/blobs/')) {
            request.response
              ..headers.set('x-nios-manifest-hash', object.manifest.hash)
              ..headers.set(
                'x-nios-ciphertext-length',
                '${object.manifest.ciphertextLength}',
              )
              ..add(Uint8List(4097));
          }
        }
        await request.response.close();
      });
      try {
        await expectLater(
          HttpCiphertextBlobStore(
            baseUri: Uri.parse('http://127.0.0.1:${server.port}/'),
            bearerToken: _token,
            allowInsecureLoopback: true,
          ).ensurePublished(
            manifest: object.manifest,
            ciphertextPath: object.ciphertextPath,
          ),
          throwsFormatException,
        );
      } finally {
        await server.close(force: true);
      }
    },
  );

  test('publication deadline aborts a server stalled before headers', () async {
    final object = await prepare();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((_) {});
    try {
      final assertion = expectLater(
        HttpCiphertextBlobStore(
          baseUri: Uri.parse('http://127.0.0.1:${server.port}/'),
          bearerToken: _token,
          timeout: const Duration(milliseconds: 100),
          allowInsecureLoopback: true,
        ).ensurePublished(
          manifest: object.manifest,
          ciphertextPath: object.ciphertextPath,
        ),
        throwsA(anything),
      );
      await assertion.timeout(const Duration(seconds: 2));
    } finally {
      await server.close(force: true);
    }
  });

  test(
    'endpoint configuration requires HTTPS with an explicit loopback exception',
    () {
      for (final uri in [
        'http://example.com/',
        'http://127.0.0.1/',
        'https://user:password@example.com/',
        'https://example.com/?token=private',
        'https://example.com/#fragment',
        'https:/missing-host',
      ]) {
        expect(
          () => HttpCiphertextBlobStore(
            baseUri: Uri.parse(uri),
            bearerToken: _token,
          ),
          throwsArgumentError,
        );
      }
      expect(
        () => HttpCiphertextBlobStore(
          baseUri: Uri.parse('http://example.com/'),
          bearerToken: _token,
          allowInsecureLoopback: true,
        ),
        throwsArgumentError,
      );
      expect(
        () => HttpRangeCiphertextSource(
          uri: Uri.parse('http://example.com/content'),
          totalLength: 1,
          allowInsecureLoopback: true,
        ),
        throwsArgumentError,
      );
    },
  );
}

Future<({int status, Map<String, String> headers, Uint8List bytes})> _request(
  String method,
  Uri uri, {
  List<int>? body,
  Map<String, String> headers = const {},
}) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(method, uri);
    request.followRedirects = false;
    request.headers.set('authorization', 'Bearer $_token');
    headers.forEach(request.headers.set);
    if (body != null) {
      request.contentLength = body.length;
      request.add(body);
    }
    final response = await request.close();
    final fields = <String, String>{};
    response.headers.forEach((name, values) => fields[name] = values.join(','));
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response) {
      bytes.add(chunk);
    }
    return (
      status: response.statusCode,
      headers: fields,
      bytes: bytes.takeBytes(),
    );
  } finally {
    client.close(force: true);
  }
}
