import 'dart:typed_data';

import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/gcm.dart';
import 'package:universal_io/io.dart';

/// Constant-working-set I/O for the existing nonce12/ciphertext/tag16 envelope.
/// GCM/GHASH and tag verification are supplied by PointyCastle, not app code.
abstract final class E2eeStreamingFileCipher {
  static const nonceBytes = 12;
  static const macBytes = 16;
  static const chunkBytes = 64 * 1024;

  // PointyCastle 4.0.0 GCM.doFinal stores only the low uint32 of the bit length.
  // At 2^29 bytes that wraps. Keep larger legacy files on cryptography's correct
  // implementation; do not silently generate a non-interoperable tag.
  static const maxPlaintextBytes = (1 << 29) - 1;

  static bool supportsPlaintextLength(int length) =>
      length >= 0 && length <= maxPlaintextBytes;

  static bool supportsEnvelopeLength(int length) =>
      supportsPlaintextLength(length - nonceBytes - macBytes);

  static Future<void> encrypt({
    required String plainPath,
    required String outputPath,
    required Uint8List key,
    required Uint8List nonce,
  }) => _transform(plainPath, outputPath, key, nonce, true);

  static Future<void> decrypt({
    required String encryptedPath,
    required String outputPath,
    required Uint8List key,
  }) => _transform(encryptedPath, outputPath, key, null, false);

  static Future<int> _readChunk(
    RandomAccessFile file,
    Uint8List buffer,
    int count,
  ) async {
    var read = 0;
    while (read < count) {
      final next = await file.readInto(buffer, read, count);
      if (next == 0) break;
      read += next;
    }
    return read;
  }

  static Future<void> _transform(
    String inputPath,
    String outputPath,
    Uint8List key,
    Uint8List? nonce,
    bool encrypting,
  ) async {
    if (key.length != 32) throw ArgumentError('E2EE file key must be 32 bytes');
    if (encrypting && nonce?.length != nonceBytes) {
      throw ArgumentError('E2EE file nonce must be 12 bytes');
    }
    final source = File(inputPath);
    final destination = File(outputPath);
    if (source.absolute.path == destination.absolute.path) {
      throw ArgumentError('E2EE input and output paths must differ');
    }
    if (await destination.exists()) throw StateError('E2EE destination exists');
    RandomAccessFile? input;
    RandomAccessFile? output;
    Directory? staging;
    final inputBuffer = Uint8List(chunkBytes);
    final outputBuffer = Uint8List(chunkBytes + 2 * macBytes);
    final localKey = Uint8List.fromList(key);
    try {
      input = await source.open();
      final inputLength = await input.length();
      final plainLength = encrypting
          ? inputLength
          : inputLength - nonceBytes - macBytes;
      if (!supportsPlaintextLength(plainLength)) {
        throw const FormatException('E2EE file size outside streaming cipher range');
      }
      final fileNonce = nonce == null
          ? Uint8List(nonceBytes)
          : Uint8List.fromList(nonce);
      if (!encrypting &&
          await _readChunk(input, fileNonce, nonceBytes) != nonceBytes) {
        throw const FormatException('E2EE file nonce truncated');
      }
      final cipher = GCMBlockCipher(AESEngine())
        ..init(
          encrypting,
          AEADParameters(
            KeyParameter(localKey),
            macBytes * 8,
            fileNonce,
            Uint8List(0),
          ),
        );
      await destination.parent.create(recursive: true);
      staging = await destination.parent.createTemp('.nios_gcm_');
      final partial = File('${staging.path}/payload.partial');
      output = await partial.open(mode: FileMode.write);
      if (encrypting) await output.writeFrom(fileNonce);
      var remaining = encrypting ? inputLength : inputLength - nonceBytes;
      while (remaining > 0) {
        final length = remaining < chunkBytes ? remaining : chunkBytes;
        if (await _readChunk(input, inputBuffer, length) != length) {
          throw const FormatException(
            'E2EE source truncated during processing',
          );
        }
        // Non-final chunks are exactly 64 KiB and therefore block-aligned.
        // This also avoids PointyCastle 4.0.0's partial-block processBytes bug.
        final written = cipher.processBytes(
          inputBuffer,
          0,
          length,
          outputBuffer,
          0,
        );
        if (written > 0) await output.writeFrom(outputBuffer, 0, written);
        remaining -= length;
      }
      if (await input.readByte() != -1) {
        throw const FormatException('E2EE source grew during processing');
      }
      // On decrypt this verifies the entire tag. Until then any intermediate
      // clear bytes live only in a private quarantine file, never a player path.
      final finalBytes = cipher.doFinal(outputBuffer, 0);
      if (finalBytes > 0) await output.writeFrom(outputBuffer, 0, finalBytes);
      await output.flush();
      await output.close();
      output = null;
      await input.close();
      input = null;
      if (await destination.exists()) {
        throw StateError('E2EE destination exists');
      }
      await partial.rename(destination.path);
    } finally {
      inputBuffer.fillRange(0, inputBuffer.length, 0);
      outputBuffer.fillRange(0, outputBuffer.length, 0);
      localKey.fillRange(0, localKey.length, 0);
      try {
        await input?.close();
      } finally {
        try {
          await output?.close();
        } finally {
          if (staging != null && await staging.exists()) {
            await staging.delete(recursive: true);
          }
        }
      }
    }
  }
}
