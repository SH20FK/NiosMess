import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:nios_sdk/stream.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('nios_stream_test_');
  });
  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  Future<PreparedStreamObject> prepare(
    List<int> bytes, {
    int size = 1024,
  }) async {
    final input = File(p.join(directory.path, 'input'));
    await input.writeAsBytes(bytes, flush: true);
    return NiosStream.prepareFile(
      inputPath: input.path,
      outputDirectory: p.join(directory.path, 'prepared'),
      segmentSize: size,
    );
  }

  Future<NiosStreamDownload> open(
    PreparedStreamObject object, {
    List<StreamCiphertextSource>? sources,
    String? cache,
  }) => NiosStreamDownload.open(
    directory: cache ?? p.join(directory.path, 'download'),
    manifest: object.manifest,
    key: object.key,
    sources: sources ?? [object.ciphertextSource],
  );

  test(
    'manifest trust is external, strict and separate from secret key',
    () async {
      final object = await prepare([1, 2, 3]);
      final json = object.manifest.toJson();
      final restored = NiosStreamManifest.fromJson(
        json,
        expectedHash: object.manifest.hash,
      );
      expect(restored.canonicalBytes, object.manifest.canonicalBytes);
      expect(json.keys, isNot(contains('key')));
      expect(
        () => NiosStreamManifest.fromJson(json, expectedHash: '0' * 64),
        throwsFormatException,
      );
      expect(
        () => NiosStreamManifest.fromJson({
          ...json,
          'plaintextLength': 4,
        }, expectedHash: object.manifest.hash),
        throwsFormatException,
      );
      final exposedPrefix = restored.noncePrefix;
      exposedPrefix[0] ^= 255;
      expect(restored.hash, object.manifest.hash);
      final exposedManifest = restored.canonicalBytes;
      exposedManifest[0] ^= 255;
      expect(restored.canonicalBytes, object.manifest.canonicalBytes);
      expect(restored.hash, object.manifest.hash);
    },
  );

  test(
    'empty and final partial segments round trip without plaintext cache',
    () async {
      for (final length in [0, 1, 1024, 1025, 4097]) {
        final data = List<int>.generate(length, (index) => index % 251);
        final object = await prepare(data);
        final cache = p.join(directory.path, 'cache_$length');
        final download = await open(object, cache: cache);
        try {
          await download.downloadAll();
          expect(download.isComplete, isTrue);
          expect(await download.readRange(0, length), data);
          expect(
            await File(p.join(cache, 'content.nsc')).length(),
            object.manifest.ciphertextLength,
          );
          final metadata = await File(
            p.join(cache, 'download.json'),
          ).readAsString();
          expect(metadata, isNot(contains('key')));
          if (data.length > 32) {
            final cipher = await File(
              p.join(cache, 'content.nsc'),
            ).readAsBytes();
            expect(cipher.take(32), isNot(data.take(32)));
          }
        } finally {
          await download.close();
        }
      }
    },
  );

  test(
    'preparation creates independent keys and nonce identities for same file',
    () async {
      final first = await prepare(List.filled(500, 7));
      final second = await prepare(List.filled(500, 7));
      expect(first.manifest.objectId, isNot(second.manifest.objectId));
      expect(first.manifest.noncePrefix, isNot(second.manifest.noncePrefix));
      expect(
        await first.key.extractBytes(),
        isNot(await second.key.extractBytes()),
      );
      expect(first.manifest.hash, isNot(second.manifest.hash));
    },
  );

  test(
    'cross-segment seeks download only required segments and survive reopen',
    () async {
      final data = List<int>.generate(10000, (index) => index % 251);
      final object = await prepare(data);
      final source = _CountingSource(object.ciphertextSource);
      var download = await open(object, sources: [source]);
      expect(await download.readRange(2040, 2060), data.sublist(2040, 2060));
      expect(source.calls, 2);
      expect(download.verifiedSegmentCount, 2);
      await download.close();
      download = await open(object, sources: []);
      try {
        expect(download.verifiedSegmentCount, 2);
        expect(await download.readRange(2040, 2060), data.sublist(2040, 2060));
        expect(download.isComplete, isFalse);
        await expectLater(
          download.readRange(0, 1),
          throwsA(isA<StreamSourceException>()),
        );
      } finally {
        await download.close();
      }
    },
  );

  test(
    'out-of-order sparse writes retain correct earlier segment positions',
    () async {
      final data = List<int>.generate(20000, (index) => (index * 7) % 251);
      final object = await prepare(data);
      final download = await open(object);
      try {
        expect(
          await download.fetchSegment(15),
          data.sublist(15 * 1024, 16 * 1024),
        );
        expect(await download.fetchSegment(0), data.sublist(0, 1024));
        expect(
          await download.fetchSegment(8),
          data.sublist(8 * 1024, 9 * 1024),
        );
        expect(await download.readRange(0, 1024), data.sublist(0, 1024));
        expect(download.verifiedSegmentCount, 3);
      } finally {
        await download.close();
      }
    },
  );

  test(
    'wrong key cannot reset a previously verified download bitmap',
    () async {
      final data = List<int>.generate(3000, (index) => index % 251);
      final object = await prepare(data);
      var download = await open(object);
      await download.downloadAll();
      await download.close();
      final progress = File(
        p.join(directory.path, 'download', 'download.json'),
      );
      final before = await progress.readAsBytes();
      await expectLater(
        NiosStreamDownload.open(
          directory: p.join(directory.path, 'download'),
          manifest: object.manifest,
          key: await AesGcm.with256bits().newSecretKey(),
          sources: [],
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      expect(await progress.readAsBytes(), before);
      download = await open(object, sources: []);
      try {
        expect(download.isComplete, isTrue);
        expect(await download.readRange(0, data.length), data);
      } finally {
        await download.close();
      }
    },
  );

  test(
    'same cache cannot be concurrently opened by another instance',
    () async {
      final object = await prepare([1, 2, 3]);
      final download = await open(object);
      try {
        await expectLater(open(object), throwsStateError);
      } finally {
        await download.close();
      }
      final reopened = await open(object);
      await reopened.close();
    },
  );

  test('ciphertext damage is detected on reopen and fetched again', () async {
    final data = List<int>.generate(4000, (index) => index % 251);
    final object = await prepare(data);
    var download = await open(object);
    await download.downloadAll();
    await download.close();
    final file = await File(
      p.join(directory.path, 'download', 'content.nsc'),
    ).open(mode: FileMode.append);
    await file.setPosition(object.manifest.segmentCiphertextOffset(1));
    final originalByte = await file.readByte();
    await file.setPosition(object.manifest.segmentCiphertextOffset(1));
    await file.writeByte(originalByte ^ 255);
    await file.flush();
    await file.close();
    final source = _CountingSource(object.ciphertextSource);
    download = await open(object, sources: [source]);
    try {
      expect(download.verifiedSegmentCount, object.manifest.segmentCount - 1);
      expect(await download.readRange(0, data.length), data);
      expect(source.calls, 1);
    } finally {
      await download.close();
    }
  });

  test(
    'write-ahead pending segment survives flush before bitmap commit',
    () async {
      final data = List<int>.generate(7000, (index) => index % 239);
      final object = await prepare(data);
      var download = await open(object);
      await download.close();
      final index = 4;
      final start = object.manifest.segmentCiphertextOffset(index);
      final ciphertext = await object.ciphertextSource.readRange(
        start,
        start + object.manifest.segmentCiphertextLength(index),
      );
      final cacheFile = await File(
        p.join(directory.path, 'download', 'content.nsc'),
      ).open(mode: FileMode.append);
      await cacheFile.setPosition(start);
      await cacheFile.writeFrom(ciphertext);
      await cacheFile.flush();
      await cacheFile.close();
      final progressFile = File(
        p.join(directory.path, 'download', 'download.json'),
      );
      final progress =
          jsonDecode(await progressFile.readAsString()) as Map<String, dynamic>;
      progress['pendingIndex'] = index;
      await progressFile.writeAsString(jsonEncode(progress), flush: true);
      download = await open(object, sources: []);
      try {
        expect(download.verifiedSegmentCount, 1);
        expect(await download.fetchSegment(index), data.sublist(4096, 5120));
      } finally {
        await download.close();
      }
    },
  );

  test(
    'tampered, reordered, cross-object and wrong-key segments never decrypt',
    () async {
      final object = await prepare(
        List<int>.generate(3000, (index) => index % 251),
      );
      final manifest = object.manifest;
      final first = await object.ciphertextSource.readRange(
        0,
        manifest.segmentCiphertextLength(0),
      );
      final secondStart = manifest.segmentCiphertextOffset(1);
      final second = await object.ciphertextSource.readRange(
        secondStart,
        secondStart + manifest.segmentCiphertextLength(1),
      );
      final tampered = Uint8List.fromList(first)..[0] ^= 1;
      await expectLater(
        NiosStream.decryptSegment(
          manifest: manifest,
          key: object.key,
          index: 0,
          ciphertext: tampered,
        ),
        throwsFormatException,
      );
      await expectLater(
        NiosStream.decryptSegment(
          manifest: manifest,
          key: object.key,
          index: 0,
          ciphertext: first.sublist(1),
        ),
        throwsFormatException,
      );
      final reordered = NiosStreamManifest(
        objectId: manifest.objectId,
        plaintextLength: manifest.plaintextLength,
        segmentSize: manifest.segmentSize,
        noncePrefix: manifest.noncePrefix,
        segmentHashes: [
          manifest.segmentHashes[1],
          manifest.segmentHashes[0],
          manifest.segmentHashes[2],
        ],
      );
      await expectLater(
        NiosStream.decryptSegment(
          manifest: reordered,
          key: object.key,
          index: 0,
          ciphertext: second,
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      final otherObject = NiosStreamManifest(
        objectId: 'a' * 32,
        plaintextLength: manifest.plaintextLength,
        segmentSize: manifest.segmentSize,
        noncePrefix: manifest.noncePrefix,
        segmentHashes: manifest.segmentHashes,
      );
      await expectLater(
        NiosStream.decryptSegment(
          manifest: otherObject,
          key: object.key,
          index: 0,
          ciphertext: first,
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      await expectLater(
        NiosStream.decryptSegment(
          manifest: manifest,
          key: await AesGcm.with256bits().newSecretKey(),
          index: 0,
          ciphertext: first,
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    },
  );

  test(
    'source failover cannot substitute a different ciphertext identity',
    () async {
      final data = List<int>.generate(2200, (index) => index % 251);
      final first = await prepare(data);
      final other = await prepare(data);
      final firstSource = _CountingSource(other.ciphertextSource);
      final secondSource = _CountingSource(first.ciphertextSource);
      final download = await open(first, sources: [firstSource, secondSource]);
      try {
        expect(await download.readRange(0, data.length), data);
        expect(firstSource.calls, first.manifest.segmentCount);
        expect(secondSource.calls, first.manifest.segmentCount);
      } finally {
        await download.close();
      }
    },
  );

  test(
    'concurrent seeks serialize cache writes and deduplicate ranges',
    () async {
      final data = List<int>.generate(4000, (index) => index % 241);
      final object = await prepare(data);
      final source = _CountingSource(object.ciphertextSource);
      final download = await open(object, sources: [source]);
      try {
        final results = await Future.wait(
          List.generate(20, (_) => download.readRange(100, 900)),
        );
        expect(results, everyElement(data.sublist(100, 900)));
        expect(source.calls, 1);
      } finally {
        await download.close();
      }
    },
  );

  test(
    'cancelled preparation publishes no ready object or partial file',
    () async {
      final input = File(p.join(directory.path, 'cancelled-input'));
      await input.writeAsBytes(List.filled(200000, 9));
      final token = StreamCancellation();
      final preparing = NiosStream.prepareFile(
        inputPath: input.path,
        outputDirectory: p.join(directory.path, 'cancelled-output'),
        segmentSize: 1024,
        cancellation: token,
      );
      Timer(const Duration(milliseconds: 1), token.cancel);
      await expectLater(preparing, throwsA(isA<StreamCancelledException>()));
      final output = Directory(p.join(directory.path, 'cancelled-output'));
      if (await output.exists()) expect(await output.list().toList(), isEmpty);
    },
  );

  test('integer and allocation bounds reject malformed requests', () async {
    final object = await prepare([1, 2]);
    final download = await open(object);
    try {
      await expectLater(download.readRange(-1, 1), throwsRangeError);
      await expectLater(download.readRange(0, 3), throwsRangeError);
      await expectLater(download.fetchSegment(1), throwsRangeError);
      final json = object.manifest.toJson();
      expect(
        () => NiosStreamManifest.fromJson({
          ...json,
          'segmentSize': 1.5,
        }, expectedHash: object.manifest.hash),
        throwsFormatException,
      );
    } finally {
      await download.close();
    }
    await expectLater(download.readRange(0, 1), throwsStateError);
  });

  test('large file processing uses bounded source range requests', () async {
    final random = Random(42);
    final input = File(p.join(directory.path, 'large-input'));
    final file = await input.open(mode: FileMode.write);
    final block = Uint8List.fromList(
      List.generate(65536, (_) => random.nextInt(256)),
    );
    for (var i = 0; i < 80; i++) {
      await file.writeFrom(block);
    }
    await file.close();
    final object = await NiosStream.prepareFile(
      inputPath: input.path,
      outputDirectory: p.join(directory.path, 'large-prepared'),
    );
    final source = _CountingSource(object.ciphertextSource);
    final download = await open(object, sources: [source]);
    try {
      await download.downloadAll();
      expect(source.maximumRequested, lessThanOrEqualTo(1024 * 1024 + 16));
      expect(await download.readRange(65530, 65545), [
        ...block.sublist(65530),
        ...block.sublist(0, 9),
      ]);
    } finally {
      await download.close();
    }
  });

  test(
    'actual killed process leaves authenticated cache recoverable',
    () async {
      final data = List<int>.generate(5000, (index) => index % 251);
      final object = await prepare(data);
      final keyFile = File(p.join(directory.path, 'key'));
      await keyFile.writeAsString(
        base64Encode(await object.key.extractBytes()),
      );
      final cache = p.join(directory.path, 'killed-cache');
      final process = await Process.start(Platform.resolvedExecutable, [
        'run',
        'test/stream/support/crash_download.dart',
        p.join(object.directory, 'manifest.json'),
        object.manifest.hash,
        keyFile.path,
        object.ciphertextPath,
        cache,
      ]);
      final errors = StringBuffer();
      process.stderr.transform(utf8.decoder).listen(errors.write);
      try {
        final line = await process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .first
            .timeout(const Duration(seconds: 30));
        expect(line, 'READY', reason: errors.toString());
        process.kill(ProcessSignal.sigkill);
        await process.exitCode.timeout(const Duration(seconds: 10));
        final download = await open(object, cache: cache, sources: []);
        try {
          expect(download.verifiedSegmentCount, 1);
          expect(
            await download.readRange(1024, 2048),
            data.sublist(1024, 2048),
          );
        } finally {
          await download.close();
        }
      } finally {
        process.kill(ProcessSignal.sigkill);
      }
    },
    timeout: const Timeout(Duration(minutes: 1)),
  );
}

final class _CountingSource implements StreamCiphertextSource {
  final StreamCiphertextSource delegate;
  int calls = 0;
  int maximumRequested = 0;

  _CountingSource(this.delegate);

  @override
  Future<Uint8List> readRange(
    int start,
    int endExclusive, {
    StreamCancellation? cancellation,
  }) {
    calls++;
    maximumRequested = max(maximumRequested, endExclusive - start);
    return delegate.readRange(start, endExclusive, cancellation: cancellation);
  }
}
