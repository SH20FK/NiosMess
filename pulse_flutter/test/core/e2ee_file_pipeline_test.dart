import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:universal_io/io.dart';
import 'package:pulse_flutter/core/utils/e2ee_file_crypto.dart';

void main() {
  test('empty legacy envelope remains a valid authenticated file', () async {
    final key = E2eeFileCrypto.generateFileKey();
    final blob = await E2eeFileCrypto.encrypt(Uint8List(0), key);
    expect(blob.length, E2eeFileCrypto.nonceBytes + E2eeFileCrypto.macBytes);
    expect(await E2eeFileCrypto.decrypt(blob, key), isEmpty);
  });
  test(
    'worker reads legacy envelope and publishes an authenticated file',
    () async {
      final dir = await Directory.systemTemp.createTemp('nios_crypto_worker_');
      addTearDown(() => dir.delete(recursive: true));
      final key = E2eeFileCrypto.generateFileKey();
      final plain = Uint8List.fromList(
        List.generate(256 * 1024, (i) => i % 251),
      );
      final blob = await E2eeFileCrypto.encrypt(plain, key);
      final encrypted = await File('${dir.path}/encrypted').writeAsBytes(blob);
      final clear = File('${dir.path}/clear');
      await E2eeFileCrypto.decryptFile(
        encryptedPath: encrypted.path,
        outputPath: clear.path,
        key: key,
      );
      expect(await clear.readAsBytes(), plain);
      expect(await File('${clear.path}.partial').exists(), isFalse);
    },
  );

  test(
    'tamper never publishes plaintext and does not poison the work queue',
    () async {
      final dir = await Directory.systemTemp.createTemp('nios_crypto_auth_');
      addTearDown(() => dir.delete(recursive: true));
      final key = E2eeFileCrypto.generateFileKey();
      final blob = await E2eeFileCrypto.encrypt(
        Uint8List.fromList([1, 2, 3]),
        key,
      );
      final good = await File('${dir.path}/good').writeAsBytes(blob);
      blob[13] ^= 1;
      final bad = await File('${dir.path}/bad').writeAsBytes(blob);
      final rejected = E2eeFileCrypto.decryptFile(
        encryptedPath: bad.path,
        outputPath: '${dir.path}/rejected',
        key: key,
      );
      final accepted = E2eeFileCrypto.decryptFile(
        encryptedPath: good.path,
        outputPath: '${dir.path}/accepted',
        key: key,
      );
      await expectLater(rejected, throwsA(anything));
      await accepted;
      expect(await File('${dir.path}/rejected').exists(), isFalse);
      expect(await File('${dir.path}/rejected.partial').exists(), isFalse);
      expect(await File('${dir.path}/accepted').readAsBytes(), [1, 2, 3]);
    },
  );
}
