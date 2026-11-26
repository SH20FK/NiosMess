import 'dart:typed_data';

import 'package:pulse_flutter/core/utils/e2ee_file_crypto.dart';
import 'package:pulse_flutter/core/utils/e2ee_streaming_file_cipher.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  test('streaming cipher uses 256 KiB chunks and round-trips multi-chunk MP4', () async {
    expect(E2eeStreamingFileCipher.chunkBytes, 256 * 1024);

    final dir = await Directory.systemTemp.createTemp('nios_video_e2ee_');
    try {
      final key = E2eeFileCrypto.generateFileKey();
      final nonce = Uint8List.fromList(List<int>.generate(12, (i) => i + 1));

      // ~700 KiB payload (> 2 chunks) starting with an MP4 ftyp box header.
      final header = Uint8List.fromList(<int>[
        0x00, 0x00, 0x00, 0x18,
        0x66, 0x74, 0x79, 0x70, // ftyp
        0x6d, 0x70, 0x34, 0x32, // mp42
        0x00, 0x00, 0x00, 0x00,
        0x69, 0x73, 0x6f, 0x6d, // isom
      ]);
      final payload = Uint8List(700 * 1024);
      payload.setRange(0, header.length, header);
      for (int i = header.length; i < payload.length; i++) {
        payload[i] = (i * 31) & 0xff;
      }

      final plainFile = File('${dir.path}/sample.mp4');
      final encFile = File('${dir.path}/sample.enc');
      final decFile = File('${dir.path}/sample.dec.mp4');
      await plainFile.writeAsBytes(payload);

      await E2eeStreamingFileCipher.encrypt(
        plainPath: plainFile.path,
        outputPath: encFile.path,
        key: key,
        nonce: nonce,
      );
      await E2eeStreamingFileCipher.decrypt(
        encryptedPath: encFile.path,
        outputPath: decFile.path,
        key: key,
      );

      final decrypted = await decFile.readAsBytes();
      expect(decrypted, equals(payload));

      // Also verify compatibility with in-memory E2eeFileCrypto.
      final memDecrypted = await E2eeFileCrypto.decrypt(
        await encFile.readAsBytes(),
        key,
      );
      expect(memDecrypted, equals(payload));
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
