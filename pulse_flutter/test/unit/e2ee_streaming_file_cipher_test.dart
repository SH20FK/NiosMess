import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:pulse_flutter/core/utils/e2ee_file_crypto.dart';
import 'package:pulse_flutter/core/utils/e2ee_streaming_file_cipher.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

Uint8List _hex(String input) => Uint8List.fromList([
  for (var i = 0; i < input.length; i += 2)
    int.parse(input.substring(i, i + 2), radix: 16),
]);

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('nios_gcm_test_');
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test(
    'streaming length guard excludes the PointyCastle uint32 wrap boundary',
    () {
      const wrap = 512 * 1024 * 1024;
      expect(E2eeStreamingFileCipher.supportsPlaintextLength(-1), isFalse);
      expect(E2eeStreamingFileCipher.supportsPlaintextLength(0), isTrue);
      expect(E2eeStreamingFileCipher.supportsPlaintextLength(wrap - 1), isTrue);
      expect(E2eeStreamingFileCipher.supportsPlaintextLength(wrap), isFalse);
      expect(
        E2eeStreamingFileCipher.supportsPlaintextLength(wrap + 1),
        isFalse,
      );
      expect(E2eeStreamingFileCipher.supportsEnvelopeLength(27), isFalse);
      expect(E2eeStreamingFileCipher.supportsEnvelopeLength(28), isTrue);
      expect(E2eeStreamingFileCipher.supportsEnvelopeLength(wrap + 27), isTrue);
      expect(
        E2eeStreamingFileCipher.supportsEnvelopeLength(wrap + 28),
        isFalse,
      );
    },
  );

  // NIST CAVP gcmEncryptExtIV256.rsp: Count=0, IVlen=96, AADlen=0,
  // Taglen=128 for PTlen=0 and PTlen=104. Public primary test vectors:
  // https://csrc.nist.gov/CSRC/media/Projects/Cryptographic-Algorithm-Validation-Program/documents/mac/gcmtestvectors.zip
  final vectors = [
    (
      key: 'b52c505a37d78eda5dd34f20c22540ea1b58963cf8e5bf8ffa85f9f2492505b4',
      nonce: '516c33929df5a3284ff463d7',
      plain: '',
      ciphertext: '',
      tag: 'bdc1ac884d332457a1d2664f168c76f0',
    ),
    (
      key: '82c4f12eeec3b2d3d157b0f992d292b237478d2cecc1d5f161389b97f999057a',
      nonce: '7b40b20f5f397177990ef2d1',
      plain: '982a296ee1cd7086afad976945',
      ciphertext: 'ec8e05a0471d6b43a59ca5335f',
      tag: '113ddeafc62373cac2f5951bb9165249',
    ),
  ];
  for (final vector in vectors) {
    test(
      'NIST AES256 GCM ${vector.plain.length ~/ 2} bytes matches exact envelope',
      () async {
        final plain = await File(
          '${directory.path}/plain',
        ).writeAsBytes(_hex(vector.plain));
        final encrypted = File('${directory.path}/sealed');
        final clear = File('${directory.path}/clear');
        await E2eeFileCrypto.encryptFile(
          plainPath: plain.path,
          outputPath: encrypted.path,
          key: _hex(vector.key),
          iv: _hex(vector.nonce),
        );
        expect(
          await encrypted.readAsBytes(),
          _hex(vector.nonce + vector.ciphertext + vector.tag),
        );
        await E2eeFileCrypto.decryptFile(
          encryptedPath: encrypted.path,
          outputPath: clear.path,
          key: _hex(vector.key),
        );
        expect(await clear.readAsBytes(), _hex(vector.plain));
        expect(directory.listSync().whereType<Directory>(), isEmpty);
      },
    );
  }

  for (final length in [
    0,
    1,
    15,
    16,
    17,
    31,
    32,
    63,
    65535,
    65536,
    65537,
    131089,
  ]) {
    test(
      'file/legacy interoperability across chunk boundary: $length',
      () async {
        final key = E2eeFileCrypto.generateFileKey();
        final bytes = Uint8List.fromList(
          List.generate(length, (i) => (i * 31) % 251),
        );
        final plain = await File('${directory.path}/plain').writeAsBytes(bytes);
        final encrypted = File('${directory.path}/sealed');
        await E2eeFileCrypto.encryptFile(
          plainPath: plain.path,
          outputPath: encrypted.path,
          key: key,
        );
        final envelope = await encrypted.readAsBytes();
        expect(envelope.length, length + 28);
        // Existing cryptography implementation reads the new streamed output.
        expect(await E2eeFileCrypto.decrypt(envelope, key), bytes);
        // And the streamed reader accepts old cryptography-generated envelopes.
        final legacy = await File(
          '${directory.path}/legacy',
        ).writeAsBytes(await E2eeFileCrypto.encrypt(bytes, key));
        final clear = File('${directory.path}/clear');
        await E2eeFileCrypto.decryptFile(
          encryptedPath: legacy.path,
          outputPath: clear.path,
          key: key,
        );
        expect(await clear.readAsBytes(), bytes);
        expect(directory.listSync().whereType<Directory>(), isEmpty);
      },
    );
  }

  test(
    'nonce, ciphertext, tag and wrong key fail without published plaintext',
    () async {
      final key = E2eeFileCrypto.generateFileKey();
      final original = await E2eeFileCrypto.encrypt(
        Uint8List.fromList(List.generate(65537, (i) => i % 251)),
        key,
      );
      for (final offset in [0, 11, 12, 65548, original.length - 1]) {
        final tampered = Uint8List.fromList(original)..[offset] ^= 1;
        final input = await File(
          '${directory.path}/tampered_$offset',
        ).writeAsBytes(tampered);
        final output = File('${directory.path}/rejected_$offset');
        await expectLater(
          E2eeFileCrypto.decryptFile(
            encryptedPath: input.path,
            outputPath: output.path,
            key: key,
          ),
          throwsA(isA<SecretBoxAuthenticationError>()),
        );
        expect(await output.exists(), isFalse);
        expect(directory.listSync().whereType<Directory>(), isEmpty);
      }
      final input = await File(
        '${directory.path}/valid',
      ).writeAsBytes(original);
      await expectLater(
        E2eeFileCrypto.decryptFile(
          encryptedPath: input.path,
          outputPath: '${directory.path}/wrong_key',
          key: E2eeFileCrypto.generateFileKey(),
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      expect(await File('${directory.path}/wrong_key').exists(), isFalse);
    },
  );

  test(
    'truncated envelopes clean quarantine and leave existing output untouched',
    () async {
      final key = E2eeFileCrypto.generateFileKey();
      final envelope = await E2eeFileCrypto.encrypt(
        Uint8List.fromList([1, 2, 3, 4, 5]),
        key,
      );
      for (final length in [
        0,
        11,
        12,
        15,
        16,
        27,
        28,
        29,
        envelope.length - 1,
      ]) {
        final input = await File(
          '${directory.path}/truncated_$length',
        ).writeAsBytes(Uint8List.sublistView(envelope, 0, length));
        final output = File('${directory.path}/rejected_$length');
        await expectLater(
          E2eeFileCrypto.decryptFile(
            encryptedPath: input.path,
            outputPath: output.path,
            key: key,
          ),
          throwsA(anything),
        );
        expect(await output.exists(), isFalse);
        expect(directory.listSync().whereType<Directory>(), isEmpty);
      }
      final input = await File(
        '${directory.path}/valid',
      ).writeAsBytes(envelope);
      final existing = await File(
        '${directory.path}/existing',
      ).writeAsBytes([9, 8, 7]);
      await expectLater(
        E2eeFileCrypto.decryptFile(
          encryptedPath: input.path,
          outputPath: existing.path,
          key: key,
        ),
        throwsA(isA<StateError>()),
      );
      expect(await existing.readAsBytes(), [9, 8, 7]);
    },
  );

  test(
    'default encryption uses fresh nonces and never mutates its input file',
    () async {
      final key = E2eeFileCrypto.generateFileKey();
      final original = Uint8List.fromList([1, 2, 3]);
      final plain = await File(
        '${directory.path}/plain',
      ).writeAsBytes(original);
      final first = File('${directory.path}/first');
      final second = File('${directory.path}/second');
      await E2eeFileCrypto.encryptFile(
        plainPath: plain.path,
        outputPath: first.path,
        key: key,
      );
      await E2eeFileCrypto.encryptFile(
        plainPath: plain.path,
        outputPath: second.path,
        key: key,
      );
      expect(
        (await first.readAsBytes()).sublist(0, 12),
        isNot((await second.readAsBytes()).sublist(0, 12)),
      );
      expect(await plain.readAsBytes(), original);
    },
  );
}
