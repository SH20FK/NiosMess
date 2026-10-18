import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as digest;
import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:universal_io/io.dart';

import 'cancellation.dart';
import 'manifest.dart';
import 'source.dart';

final class PreparedStreamObject {
  final NiosStreamManifest manifest;
  final SecretKey key;
  final String directory;

  const PreparedStreamObject({
    required this.manifest,
    required this.key,
    required this.directory,
  });

  String get ciphertextPath => p.join(directory, 'content.nsc');
  FileCiphertextSource get ciphertextSource =>
      FileCiphertextSource(ciphertextPath);
}

/// Version 1 uses a unique AES-256-GCM key and random 64-bit nonce prefix for
/// each object; the last 32 nonce bits are the segment index. Applications must
/// carry [PreparedStreamObject.key] and its manifest hash in a trusted channel.
abstract final class NiosStream {
  static final _cipher = AesGcm.with256bits();

  static Future<PreparedStreamObject> prepareFile({
    required String inputPath,
    required String outputDirectory,
    int segmentSize = NiosStreamManifest.maximumSegmentSize,
    StreamCancellation? cancellation,
  }) async {
    if (segmentSize <= 0 ||
        segmentSize > NiosStreamManifest.maximumSegmentSize) {
      throw RangeError('Invalid segment size');
    }
    cancellation?.throwIfCancelled();
    final input = await File(inputPath).open();
    Directory? stage;
    RandomAccessFile? output;
    var committed = false;
    try {
      final length = await input.length();
      final count = (length + segmentSize - 1) ~/ segmentSize;
      if (length > NiosStreamManifest.maximumPlaintextLength ||
          count > NiosStreamManifest.maximumSegmentCount) {
        throw RangeError('File exceeds NiosStream version 1 bounds');
      }
      final random = Random.secure();
      final objectId = _randomHex(random, 16);
      final prefix = List<int>.generate(8, (_) => random.nextInt(256));
      final key = await _cipher.newSecretKey();
      final provisional = NiosStreamManifest(
        objectId: objectId,
        plaintextLength: length,
        segmentSize: segmentSize,
        noncePrefix: prefix,
        segmentHashes: List.filled(count, '0' * 64),
      );
      final parent = await Directory(outputDirectory).create(recursive: true);
      stage = await Directory(
        p.join(parent.path, '.$objectId.${_randomHex(random, 8)}.partial'),
      ).create();
      output = await File(
        p.join(stage.path, 'content.nsc'),
      ).open(mode: FileMode.write);
      final hashes = <String>[];
      for (var index = 0; index < count; index++) {
        cancellation?.throwIfCancelled();
        final plain = Uint8List(provisional.segmentPlaintextLength(index));
        try {
          await _readExactly(input, plain, cancellation);
          final box = await _cipher.encrypt(
            plain,
            secretKey: key,
            nonce: provisional.segmentNonce(index),
            aad: provisional.segmentAssociatedData(index),
          );
          cancellation?.throwIfCancelled();
          final bytes = Uint8List(box.cipherText.length + box.mac.bytes.length)
            ..setRange(0, box.cipherText.length, box.cipherText)
            ..setRange(
              box.cipherText.length,
              box.cipherText.length + 16,
              box.mac.bytes,
            );
          hashes.add(digest.sha256.convert(bytes).toString());
          await _writeChunks(output, bytes, cancellation);
        } finally {
          plain.fillRange(0, plain.length, 0);
        }
      }
      if (await input.length() != length) {
        throw const FileSystemException(
          'Input length changed during preparation',
        );
      }
      await output.flush();
      await output.close();
      output = null;
      final manifest = NiosStreamManifest(
        objectId: objectId,
        plaintextLength: length,
        segmentSize: segmentSize,
        noncePrefix: prefix,
        segmentHashes: hashes,
      );
      await _atomicWrite(
        p.join(stage.path, 'manifest.json'),
        manifest.canonicalBytes,
      );
      cancellation?.throwIfCancelled();
      final ready = await stage.rename(p.join(parent.path, objectId));
      committed = true;
      return PreparedStreamObject(
        manifest: manifest,
        key: key,
        directory: ready.path,
      );
    } finally {
      await output?.close();
      await input.close();
      if (!committed && stage != null && await stage.exists()) {
        await stage.delete(recursive: true);
      }
    }
  }

  /// Validates both the trusted manifest digest and the authenticated segment.
  /// No plaintext is returned before AES-GCM tag verification completes.
  static Future<Uint8List> decryptSegment({
    required NiosStreamManifest manifest,
    required SecretKey key,
    required int index,
    required List<int> ciphertext,
  }) async {
    if (ciphertext.length != manifest.segmentCiphertextLength(index) ||
        digest.sha256.convert(ciphertext).toString() !=
            manifest.segmentHashes[index]) {
      throw const FormatException('Ciphertext segment integrity failure');
    }
    final split = ciphertext.length - NiosStreamManifest.tagLength;
    final plain = await _cipher.decrypt(
      SecretBox(
        ciphertext.sublist(0, split),
        nonce: manifest.segmentNonce(index),
        mac: Mac(ciphertext.sublist(split)),
      ),
      secretKey: key,
      aad: manifest.segmentAssociatedData(index),
    );
    return Uint8List.fromList(plain);
  }
}

/// Ciphertext-only disk cache. Metadata is a progress bitmap and the public
/// manifest hash, never plaintext or encryption keys. Account owners should use
/// an account-specific directory and remove it when that account is removed.
///
/// One instance serializes all cache access. A directory belongs to exactly one
/// instance at a time (an OS file lock enforces this across processes).
final class NiosStreamDownload {
  static const int maximumReadRange = 8 * 1024 * 1024;
  static final Set<String> _openDirectories = {};

  final String directory;
  final NiosStreamManifest manifest;
  final SecretKey _key;
  final List<StreamCiphertextSource> sources;
  final Uint8List _bitmap;
  final RandomAccessFile _content;
  final RandomAccessFile _lock;
  final String _directoryLease;
  final StreamCancellation _lifetime = StreamCancellation();
  late final void Function()? _unregisterOwner;
  Future<void> _tail = Future.value();
  bool _closed = false;
  int? _pendingIndex;
  Future<void>? _closeFuture;

  NiosStreamDownload._({
    required this.directory,
    required this.manifest,
    required SecretKey key,
    required this.sources,
    required Uint8List bitmap,
    required RandomAccessFile content,
    required RandomAccessFile lock,
    required String directoryLease,
    required StreamCancellation? ownerCancellation,
  }) : _key = key,
       _bitmap = bitmap,
       _content = content,
       _lock = lock,
       _directoryLease = directoryLease {
    _unregisterOwner = ownerCancellation?.onCancel(_lifetime.cancel);
  }

  static Future<NiosStreamDownload> open({
    required String directory,
    required NiosStreamManifest manifest,
    required SecretKey key,
    required List<StreamCiphertextSource> sources,
    StreamCancellation? cancellation,
  }) async {
    cancellation?.throwIfCancelled();
    await Directory(directory).create(recursive: true);
    final lock = await File(
      p.join(directory, 'download.lock'),
    ).open(mode: FileMode.append);
    final directoryLease = await Directory(directory).resolveSymbolicLinks();
    if (!_openDirectories.add(directoryLease)) {
      await lock.close();
      throw StateError('This NiosStream cache is already open');
    }
    RandomAccessFile? content;
    NiosStreamDownload? opened;
    try {
      await lock.lock(FileLock.exclusive);
      final storedManifest = File(p.join(directory, 'manifest.json'));
      if (await storedManifest.exists()) {
        if (await storedManifest.length() > 80 * 1024 * 1024) {
          throw const FormatException('Oversized cached manifest');
        }
        final json = jsonDecode(await storedManifest.readAsString());
        if (json is! Map<String, dynamic>) {
          throw const FormatException('Invalid cached manifest');
        }
        NiosStreamManifest.fromJson(json, expectedHash: manifest.hash);
      } else {
        await _atomicWrite(storedManifest.path, manifest.canonicalBytes);
      }
      final contentFile = File(p.join(directory, 'content.nsc'));
      if (!await contentFile.exists()) await contentFile.create();
      content = await contentFile.open(mode: FileMode.append);
      // Append mode preserves existing data; explicit setPosition before every
      // write is honored by Dart RandomAccessFile (unlike a POSIX O_APPEND fd).
      final bitmap = Uint8List((manifest.segmentCount + 7) ~/ 8);
      int? pendingIndex;
      final progressFile = File(p.join(directory, 'download.json'));
      if (await progressFile.exists()) {
        if (await progressFile.length() > 2 * 1024 * 1024) {
          throw const FormatException('Oversized download progress');
        }
        final progress = jsonDecode(await progressFile.readAsString());
        if (progress is! Map<String, dynamic> ||
            progress['version'] != 1 ||
            progress['manifestHash'] != manifest.hash ||
            progress['verified'] is! String ||
            (progress['pendingIndex'] != null &&
                progress['pendingIndex'] is! int)) {
          throw const FormatException('Invalid download progress');
        }
        final persistedBitmap = base64Decode(progress['verified'] as String);
        if (persistedBitmap.length != bitmap.length) {
          throw const FormatException('Invalid download bitmap length');
        }
        bitmap.setAll(0, persistedBitmap);
        pendingIndex = progress['pendingIndex'] as int?;
        if (pendingIndex != null &&
            (pendingIndex < 0 || pendingIndex >= manifest.segmentCount)) {
          throw const FormatException('Invalid pending segment index');
        }
      }
      final download = NiosStreamDownload._(
        directory: directory,
        manifest: manifest,
        key: key,
        sources: List.unmodifiable(sources),
        bitmap: bitmap,
        content: content,
        lock: lock,
        directoryLease: directoryLease,
        ownerCancellation: cancellation,
      );
      opened = download;
      final fileLength = await content.length();
      // Recheck claimed ranges and the write-ahead pending index. An interrupted
      // sparse download must not scan terabytes of zero-filled missing ranges.
      for (var index = 0; index < manifest.segmentCount; index++) {
        cancellation?.throwIfCancelled();
        if (!download.isSegmentVerified(index) && index != pendingIndex) {
          continue;
        }
        download._setVerified(index, false);
        final end =
            manifest.segmentCiphertextOffset(index) +
            manifest.segmentCiphertextLength(index);
        if (end > fileLength) continue;
        try {
          final cipher = await download._readCached(index, cancellation);
          final plain = await NiosStream.decryptSegment(
            manifest: manifest,
            key: key,
            index: index,
            ciphertext: cipher,
          );
          plain.fillRange(0, plain.length, 0);
          download._setVerified(index, true);
        } on FormatException {
          // A damaged or uncommitted range is fetched again on demand.
        }
      }
      await download._persistBitmap();
      cancellation?.throwIfCancelled();
      return download;
    } catch (_) {
      opened?._lifetime.cancel();
      opened?._unregisterOwner?.call();
      await content?.close();
      try {
        await lock.unlock();
      } on FileSystemException {
        // Lock acquisition may itself have failed.
      }
      await lock.close();
      _openDirectories.remove(directoryLease);
      rethrow;
    }
  }

  int get verifiedSegmentCount {
    var count = 0;
    for (var index = 0; index < manifest.segmentCount; index++) {
      if (isSegmentVerified(index)) count++;
    }
    return count;
  }

  bool get isComplete => verifiedSegmentCount == manifest.segmentCount;

  bool isSegmentVerified(int index) {
    RangeError.checkValidIndex(index, manifest.segmentHashes, 'index');
    return (_bitmap[index ~/ 8] & (1 << (index % 8))) != 0;
  }

  /// A single authenticated segment. The caller owns and should discard the
  /// returned plaintext once consumed. It is never written to a disk cache.
  Future<Uint8List> fetchSegment(
    int index, {
    StreamCancellation? cancellation,
  }) => _serialize(
    (linked) => _fetchSegment(index, linked),
    cancellation: cancellation,
  );

  /// End is exclusive. The explicit result bound prevents a player from
  /// accidentally materializing an entire large file in memory.
  Future<Uint8List> readRange(
    int start,
    int endExclusive, {
    StreamCancellation? cancellation,
  }) => _serialize((linked) async {
    if (start < 0 ||
        endExclusive < start ||
        endExclusive > manifest.plaintextLength ||
        endExclusive - start > maximumReadRange) {
      throw RangeError('Invalid or oversized plaintext range');
    }
    linked.throwIfCancelled();
    final result = Uint8List(endExclusive - start);
    if (result.isEmpty) return result;
    try {
      var cursor = start;
      while (cursor < endExclusive) {
        linked.throwIfCancelled();
        final index = cursor ~/ manifest.segmentSize;
        final plain = await _fetchSegment(index, linked);
        try {
          final localStart = cursor % manifest.segmentSize;
          final length = min(plain.length - localStart, endExclusive - cursor);
          result.setRange(
            cursor - start,
            cursor - start + length,
            plain,
            localStart,
          );
          cursor += length;
        } finally {
          plain.fillRange(0, plain.length, 0);
        }
      }
      linked.throwIfCancelled();
      return result;
    } catch (_) {
      result.fillRange(0, result.length, 0);
      rethrow;
    }
  }, cancellation: cancellation);

  Future<void> downloadAll({StreamCancellation? cancellation}) =>
      _serialize((linked) async {
        for (var index = 0; index < manifest.segmentCount; index++) {
          final plain = await _fetchSegment(index, linked);
          plain.fillRange(0, plain.length, 0);
        }
      }, cancellation: cancellation);

  Future<void> close() {
    if (_closeFuture != null) return _closeFuture!;
    _closed = true;
    // Cancellation happens before awaiting queued work, so a source stalled on
    // a network response cannot hold account logout or cache disposal hostage.
    _lifetime.cancel();
    _unregisterOwner?.call();
    return _closeFuture = _close();
  }

  Future<void> _close() async {
    await _tail;
    try {
      await _content.close();
    } finally {
      try {
        await _lock.unlock();
      } finally {
        await _lock.close();
        _openDirectories.remove(_directoryLease);
      }
    }
  }

  Future<Uint8List> _fetchSegment(
    int index,
    StreamCancellation? cancellation,
  ) async {
    RangeError.checkValidIndex(index, manifest.segmentHashes, 'index');
    cancellation?.throwIfCancelled();
    if (isSegmentVerified(index)) {
      try {
        final plaintext = await NiosStream.decryptSegment(
          manifest: manifest,
          key: _key,
          index: index,
          ciphertext: await _readCached(index, cancellation),
        );
        if (cancellation?.isCancelled ?? false) {
          plaintext.fillRange(0, plaintext.length, 0);
          cancellation!.throwIfCancelled();
        }
        return plaintext;
      } on FormatException {
        _setVerified(index, false);
        await _persistBitmap();
      }
    }
    Object? lastError;
    for (final source in sources) {
      cancellation?.throwIfCancelled();
      Uint8List? plaintext;
      try {
        final start = manifest.segmentCiphertextOffset(index);
        final ciphertext = await source.readRange(
          start,
          start + manifest.segmentCiphertextLength(index),
          cancellation: cancellation,
        );
        plaintext = await NiosStream.decryptSegment(
          manifest: manifest,
          key: _key,
          index: index,
          ciphertext: ciphertext,
        );
        cancellation?.throwIfCancelled();
        await _content.setPosition(start);
        _pendingIndex = index;
        await _persistBitmap();
        await _writeChunks(_content, ciphertext, cancellation);
        await _content.flush();
        cancellation?.throwIfCancelled();
        _setVerified(index, true);
        _pendingIndex = null;
        try {
          await _persistBitmap();
        } catch (_) {
          _setVerified(index, false);
          rethrow;
        }
        cancellation?.throwIfCancelled();
        return plaintext;
      } on StreamCancelledException {
        plaintext?.fillRange(0, plaintext.length, 0);
        rethrow;
      } catch (error) {
        plaintext?.fillRange(0, plaintext.length, 0);
        lastError = error;
      }
    }
    throw StreamSourceException(index, lastError);
  }

  Future<Uint8List> _readCached(
    int index,
    StreamCancellation? cancellation,
  ) async {
    final result = Uint8List(manifest.segmentCiphertextLength(index));
    await _content.setPosition(manifest.segmentCiphertextOffset(index));
    await _readExactly(_content, result, cancellation);
    return result;
  }

  void _setVerified(int index, bool verified) {
    final mask = 1 << (index % 8);
    if (verified) {
      _bitmap[index ~/ 8] |= mask;
    } else {
      _bitmap[index ~/ 8] &= ~mask;
    }
  }

  Future<void> _persistBitmap() => _atomicWrite(
    p.join(directory, 'download.json'),
    utf8.encode(
      jsonEncode({
        'version': 1,
        'manifestHash': manifest.hash,
        'verified': base64Encode(_bitmap),
        'pendingIndex': _pendingIndex,
      }),
    ),
  );

  Future<T> _serialize<T>(
    Future<T> Function(StreamCancellation) action, {
    StreamCancellation? cancellation,
  }) {
    if (_closed) {
      return Future.error(StateError('NiosStreamDownload is closed'));
    }
    final result = _tail.then((_) async {
      final linked = StreamCancellation();
      final unregisterLifetime = _lifetime.onCancel(linked.cancel);
      final unregisterOperation = cancellation?.onCancel(linked.cancel);
      try {
        linked.throwIfCancelled();
        return await action(linked);
      } finally {
        unregisterLifetime();
        unregisterOperation?.call();
      }
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}

final class StreamSourceException implements Exception {
  final int segmentIndex;
  final Object? cause;

  const StreamSourceException(this.segmentIndex, this.cause);

  @override
  String toString() => 'StreamSourceException(segment: $segmentIndex)';
}

Future<void> _readExactly(
  RandomAccessFile file,
  Uint8List buffer,
  StreamCancellation? cancellation,
) async {
  var position = 0;
  while (position < buffer.length) {
    cancellation?.throwIfCancelled();
    final end = min(position + 64 * 1024, buffer.length);
    final count = await file.readInto(buffer, position, end);
    if (count == 0) {
      throw const FormatException('Truncated ciphertext or input');
    }
    position += count;
  }
}

Future<void> _writeChunks(
  RandomAccessFile file,
  List<int> buffer,
  StreamCancellation? cancellation,
) async {
  for (var position = 0; position < buffer.length; position += 64 * 1024) {
    cancellation?.throwIfCancelled();
    await file.writeFrom(
      buffer,
      position,
      min(position + 64 * 1024, buffer.length),
    );
  }
}

Future<void> _atomicWrite(String path, List<int> bytes) async {
  final temporary = File('$path.${_randomHex(Random.secure(), 8)}.partial');
  RandomAccessFile? file;
  try {
    file = await temporary.open(mode: FileMode.write);
    await _writeChunks(file, bytes, null);
    await file.flush();
    await file.close();
    file = null;
    await temporary.rename(path);
  } finally {
    await file?.close();
    if (await temporary.exists()) await temporary.delete();
  }
}

String _randomHex(Random random, int length) => List.generate(
  length,
  (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();
