import 'dart:async';
import 'dart:typed_data';

import 'package:nios_sdk/stream.dart';
import 'package:pulse_flutter/core/media/background_stream_crypto.dart';
import 'package:test/test.dart';

void main() {
  test(
    'segment crypto yields the UI event loop and preserves authenticated bytes',
    () async {
      final executor = BackgroundStreamCrypto();
      final expected = Uint8List.fromList(
        List.generate(1024 * 1024, (i) => i & 255),
      );
      final input = Uint8List.fromList(expected);
      final key = Uint8List.fromList(List.filled(32, 7));
      final nonce = Uint8List.fromList(List.filled(12, 4));
      final aad = Uint8List.fromList([1, 2, 3]);
      var heartbeat = false;
      try {
        final pending = executor.run(
          StreamCryptoRequest(
            operation: StreamCryptoOperation.encrypt,
            bytes: input,
            key: key,
            nonce: nonce,
            associatedData: aad,
          ),
        );
        Timer.run(() {
          heartbeat = true;
        });
        final encrypted = await pending;
        expect(
          heartbeat,
          isTrue,
          reason: 'A 1MiB AES job must leave the UI event queue free',
        );
        expect(input.every((v) => v == 0), isTrue);
        expect(key.every((v) => v == 0), isTrue);
        final decrypted = await executor.run(
          StreamCryptoRequest(
            operation: StreamCryptoOperation.decrypt,
            bytes: encrypted.bytes,
            key: Uint8List.fromList(List.filled(32, 7)),
            nonce: nonce,
            associatedData: aad,
            expectedHash: encrypted.hash,
          ),
        );
        expect(decrypted.bytes, expected);
        decrypted.bytes.fillRange(0, decrypted.bytes.length, 0);
        final altered = Uint8List.fromList(encrypted.bytes)..[17] ^= 1;
        await expectLater(
          executor.run(
            StreamCryptoRequest(
              operation: StreamCryptoOperation.decrypt,
              bytes: altered,
              key: Uint8List.fromList(List.filled(32, 7)),
              nonce: nonce,
              associatedData: aad,
              expectedHash: encrypted.hash,
            ),
          ),
          throwsFormatException,
        );
      } finally {
        await executor.close();
      }
    },
  );

  test(
    'shutdown drains an active segment, fences queued jobs and clears copied secrets',
    () async {
      final executor = BackgroundStreamCrypto();
      final request = StreamCryptoRequest(
        operation: StreamCryptoOperation.encrypt,
      bytes: Uint8List.fromList(List.filled(1024 * 1024, 23)),
        key: Uint8List.fromList(List.filled(32, 11)),
        nonce: Uint8List(12),
        associatedData: Uint8List(0),
      );
      final pending = executor.run(request);
      final rejected = expectLater(pending, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    final second = executor.run(StreamCryptoRequest(
      operation: StreamCryptoOperation.hash, bytes: Uint8List(1)));
    final secondRejected = expectLater(second, throwsStateError);
      await executor.close();
      await rejected;
    await secondRejected;
      expect(request.key!.every((v) => v == 0), isTrue);
    expect(request.bytes.every((v) => v == 0), isTrue);
      final queued = StreamCryptoRequest(
        operation: StreamCryptoOperation.hash,
        bytes: Uint8List(1),
      );
      await expectLater(executor.run(queued), throwsStateError);
    },
  );
}
