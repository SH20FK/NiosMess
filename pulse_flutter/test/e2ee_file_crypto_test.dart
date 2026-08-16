import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/utils/e2ee_file_crypto.dart';

void main() {
  group('E2eeFileCrypto', () {
    test('roundtrips bytes', () async {
      final key = E2eeFileCrypto.generateFileKey();
      expect(key.length, 32);

      final plain = Uint8List.fromList(
        List<int>.generate(1024, (int i) => i % 251),
      );
      final blob = await E2eeFileCrypto.encrypt(plain, key);

      // [nonce 12][ciphertext|tag]
      expect(blob.length, 12 + plain.length + 16);

      final decrypted = await E2eeFileCrypto.decrypt(blob, key);
      expect(decrypted, plain);
    });

    test('different keys cannot decrypt each other', () async {
      final key1 = E2eeFileCrypto.generateFileKey();
      final key2 = E2eeFileCrypto.generateFileKey();
      final blob =
          await E2eeFileCrypto.encrypt(Uint8List.fromList(<int>[1, 2, 3]), key1);

      expect(
        () => E2eeFileCrypto.decrypt(blob, key2),
        throwsA(anything),
      );
    });

    test('tampered ciphertext fails authentication', () async {
      final key = E2eeFileCrypto.generateFileKey();
      final blob = await E2eeFileCrypto.encrypt(
        Uint8List.fromList(List<int>.filled(500, 7)),
        key,
      );
      blob[20] = blob[20] ^ 0xFF;

      expect(
        () => E2eeFileCrypto.decrypt(blob, key),
        throwsA(anything),
      );
    });

    test('rejects too-short blobs', () async {
      final key = E2eeFileCrypto.generateFileKey();
      expect(
        () => E2eeFileCrypto.decrypt(Uint8List(10), key),
        throwsA(isA<FormatException>()),
      );
    });

    test('generated keys are unique', () {
      final a = E2eeFileCrypto.generateFileKey();
      final b = E2eeFileCrypto.generateFileKey();
      expect(a, isNot(equals(b)));
    });
  });
}
