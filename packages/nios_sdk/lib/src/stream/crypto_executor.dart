import 'dart:typed_data';

import 'package:crypto/crypto.dart' as digest;
import 'package:cryptography/cryptography.dart';

enum StreamCryptoOperation { encrypt, decrypt, hash }

/// Only primitive owned buffers cross an executor boundary. Executors must
/// preserve this standard AES-GCM/container format and must not retain keys.
final class StreamCryptoRequest {
  StreamCryptoRequest({
    required this.operation,
    required this.bytes,
    this.key,
    this.nonce,
    this.associatedData,
    this.expectedHash,
  });
  final StreamCryptoOperation operation;
  final Uint8List bytes;
  final Uint8List? key;
  final Uint8List? nonce;
  final Uint8List? associatedData;
  final String? expectedHash;
}

final class StreamCryptoResult {
  const StreamCryptoResult(this.bytes, this.hash);
  final Uint8List bytes;
  final String hash;
}

typedef StreamCryptoExecutor =
    Future<StreamCryptoResult> Function(StreamCryptoRequest request);

/// The portable executor. Native UI hosts can run this exact function in a
/// bounded worker isolate; pure Dart/web users retain the in-process default.
Future<StreamCryptoResult> executeStreamCrypto(
  StreamCryptoRequest request,
) async {
  final key = request.key;
  try {
    if (request.bytes.length > 1024 * 1024 + 16) {
      throw RangeError('Oversized stream crypto job');
    }
    if (request.operation == StreamCryptoOperation.hash) {
      return StreamCryptoResult(
        Uint8List(0),
        digest.sha256.convert(request.bytes).toString(),
      );
    }
    if (key == null ||
        key.length != 32 ||
        request.nonce?.length != 12 ||
        request.associatedData == null ||
        request.associatedData!.length > 4096) {
      throw const FormatException('Invalid stream crypto job');
    }
    final cipher = AesGcm.with256bits();
    if (request.operation == StreamCryptoOperation.encrypt) {
      if (request.bytes.length > 1024 * 1024) {
        throw RangeError('Oversized plaintext segment');
      }
      final box = await cipher.encrypt(
        request.bytes,
        secretKey: SecretKey(key),
        nonce: request.nonce!,
        aad: request.associatedData!,
      );
      final bytes = Uint8List(box.cipherText.length + 16)
        ..setRange(0, box.cipherText.length, box.cipherText)
        ..setRange(
          box.cipherText.length,
          box.cipherText.length + 16,
          box.mac.bytes,
        );
      return StreamCryptoResult(bytes, digest.sha256.convert(bytes).toString());
    }
    if (request.bytes.length < 16 ||
        digest.sha256.convert(request.bytes).toString() !=
            request.expectedHash) {
      throw const FormatException('Ciphertext segment integrity failure');
    }
    final split = request.bytes.length - 16;
    final plain = await cipher.decrypt(
      SecretBox(
        request.bytes.sublist(0, split),
        nonce: request.nonce!,
        mac: Mac(request.bytes.sublist(split)),
      ),
      secretKey: SecretKey(key),
      aad: request.associatedData!,
    );
    return StreamCryptoResult(Uint8List.fromList(plain), request.expectedHash!);
  } finally {
    key?.fillRange(0, key.length, 0);
    if (request.operation == StreamCryptoOperation.encrypt) {
      request.bytes.fillRange(0, request.bytes.length, 0);
    }
  }
}
