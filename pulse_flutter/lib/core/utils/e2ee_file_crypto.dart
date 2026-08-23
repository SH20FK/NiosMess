import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Client-side encryption for media files in E2EE (secret) chats.
///
/// Files are encrypted before upload and decrypted after download with a
/// random per-file AES-256-GCM key. The key travels only inside the
/// Double-Ratchet-encrypted message envelope, never in the clear.
///
/// Blob layout on the server: `[nonce 12B][ciphertext|tag]`.
class E2eeFileCrypto {
  const E2eeFileCrypto._();

  static const int nonceBytes = 12;
  static const int macBytes = 16;

  /// Generates a fresh 256-bit file key.
  static Uint8List generateFileKey() {
    final Random random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
  }

  static Future<Uint8List> encrypt(Uint8List plain, Uint8List key) async {
    final SecretBox box = await AesGcm.with256bits().encrypt(
      plain,
      secretKey: SecretKey(key),
    );
    final Uint8List out = Uint8List(
      nonceBytes + box.cipherText.length + box.mac.bytes.length,
    );
    out.setRange(0, nonceBytes, box.nonce);
    out.setRange(nonceBytes, nonceBytes + box.cipherText.length, box.cipherText);
    out.setRange(nonceBytes + box.cipherText.length, out.length, box.mac.bytes);
    return out;
  }

  static Future<Uint8List> decrypt(Uint8List blob, Uint8List key, {Uint8List? iv}) async {
    if (iv != null && iv.length == nonceBytes) {
      if (blob.length < macBytes) {
        throw const FormatException('E2EE file blob too short');
      }
      final Uint8List ct = Uint8List.sublistView(blob, 0, blob.length - macBytes);
      final Uint8List mac = Uint8List.sublistView(blob, blob.length - macBytes);
      final List<int> clear = await AesGcm.with256bits().decrypt(
        SecretBox(ct, nonce: iv, mac: Mac(mac)),
        secretKey: SecretKey(key),
      );
      return Uint8List.fromList(clear);
    }

    if (blob.length <= nonceBytes + macBytes) {
      throw const FormatException('E2EE file blob too short');
    }
    final Uint8List nonce = Uint8List.sublistView(blob, 0, nonceBytes);
    final Uint8List ct = Uint8List.sublistView(
      blob,
      nonceBytes,
      blob.length - macBytes,
    );
    final Uint8List mac = Uint8List.sublistView(blob, blob.length - macBytes);
    final List<int> clear = await AesGcm.with256bits().decrypt(
      SecretBox(ct, nonce: nonce, mac: Mac(mac)),
      secretKey: SecretKey(key),
    );
    return Uint8List.fromList(clear);
  }
}
