import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart';

class _DigestSink implements Sink<Digest> {
  Digest? _digest;
  Digest? get digest => _digest;

  @override
  void add(Digest data) {
    _digest = data;
  }

  @override
  void close() {}
}

/// Result of hashing a file prior to content-addressed upload.
@immutable
class BlobHashResult {
  const BlobHashResult({
    required this.contentHash,
    required this.chunkHashes,
    required this.fileSize,
    required this.chunkSize,
    required this.chunkCount,
  });

  final String contentHash;
  final List<String> chunkHashes;
  final int fileSize;
  final int chunkSize;
  final int chunkCount;
}

/// Helper input parameters for isolate computation.
class _HashInput {
  const _HashInput({
    this.filePath,
    this.bytes,
    required this.chunkSize,
  });

  final String? filePath;
  final Uint8List? bytes;
  final int chunkSize;
}

/// High-performance file hasher that runs in a background Dart Isolate
/// to prevent any UI frame drops or stuttering during large file transfers.
class BlobHasher {
  const BlobHasher._();

  /// Determines optimal chunk size based on file size.
  static int determineChunkSize(int fileSize) {
    if (fileSize <= 1024 * 1024) {
      return 256 * 1024; // 256 KB for files <= 1 MB
    } else if (fileSize <= 100 * 1024 * 1024) {
      return 1024 * 1024; // 1 MB for files <= 100 MB
    } else {
      return 4 * 1024 * 1024; // 4 MB for files > 100 MB
    }
  }

  /// Hashes file or in-memory bytes asynchronously in a background Isolate.
  static Future<BlobHashResult> hashFile({
    String? filePath,
    Uint8List? bytes,
    int? customChunkSize,
  }) async {
    int fileSize = 0;
    if (filePath != null && filePath.isNotEmpty) {
      final File file = File(filePath);
      if (await file.exists()) {
        fileSize = await file.length();
      }
    } else if (bytes != null) {
      fileSize = bytes.length;
    }

    if (fileSize == 0 && (bytes == null || bytes.isEmpty)) {
      return const BlobHashResult(
        contentHash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', // SHA-256 of empty
        chunkHashes: <String>[],
        fileSize: 0,
        chunkSize: 262144,
        chunkCount: 0,
      );
    }

    final int chunkSize = customChunkSize ?? determineChunkSize(fileSize);
    final _HashInput input = _HashInput(
      filePath: filePath,
      bytes: bytes,
      chunkSize: chunkSize,
    );

    return compute(_runHashingInIsolate, input);
  }

  /// Top-level function executed inside Dart Isolate.
  static Future<BlobHashResult> _runHashingInIsolate(_HashInput input) async {
    final _DigestSink fullSink = _DigestSink();
    final ByteConversionSink fullInput = sha256.startChunkedConversion(fullSink);

    final List<String> chunkHashes = <String>[];
    _DigestSink chunkSink = _DigestSink();
    ByteConversionSink chunkInput = sha256.startChunkedConversion(chunkSink);

    int totalBytesRead = 0;
    int currentChunkBytes = 0;

    void processBlock(List<int> block) {
      int offset = 0;
      while (offset < block.length) {
        final int remainingInChunk = input.chunkSize - currentChunkBytes;
        final int bytesToTake = (block.length - offset) < remainingInChunk
            ? (block.length - offset)
            : remainingInChunk;

        final List<int> slice = block.sublist(offset, offset + bytesToTake);
        fullInput.add(slice);
        chunkInput.add(slice);

        currentChunkBytes += bytesToTake;
        totalBytesRead += bytesToTake;
        offset += bytesToTake;

        if (currentChunkBytes >= input.chunkSize) {
          chunkInput.close();
          chunkHashes.add(chunkSink.digest.toString());
          chunkSink = _DigestSink();
          chunkInput = sha256.startChunkedConversion(chunkSink);
          currentChunkBytes = 0;
        }
      }
    }

    if (input.filePath != null && input.filePath!.isNotEmpty) {
      final File file = File(input.filePath!);
      final Stream<List<int>> stream = file.openRead();
      await for (final List<int> block in stream) {
        processBlock(block);
      }
    } else if (input.bytes != null) {
      processBlock(input.bytes!);
    }

    // Finalize last partial chunk if present
    if (currentChunkBytes > 0) {
      chunkInput.close();
      chunkHashes.add(chunkSink.digest.toString());
    }

    fullInput.close();
    final String contentHash = fullSink.digest.toString();

    return BlobHashResult(
      contentHash: contentHash,
      chunkHashes: chunkHashes,
      fileSize: totalBytesRead,
      chunkSize: input.chunkSize,
      chunkCount: chunkHashes.length,
    );
  }
}
