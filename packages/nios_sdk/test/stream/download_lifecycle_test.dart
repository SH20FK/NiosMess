import 'dart:async';

import 'package:nios_sdk/stream.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  for (final stop in ['close', 'account', 'operation']) {
    test(
      '$stop cancellation aborts a stalled range after a verified first segment',
      () async {
        final temporary = await Directory.systemTemp.createTemp(
          'nios_lifetime_',
        );
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        NiosStreamDownload? download;
        try {
          final data = List.generate(2048, (index) => (index * 19) % 251);
          final input = File(p.join(temporary.path, 'input'));
          await input.writeAsBytes(data, flush: true);
          final object = await NiosStream.prepareFile(
            inputPath: input.path,
            outputDirectory: p.join(temporary.path, 'prepared'),
            segmentSize: 1024,
          );
          final firstCiphertext = await object.ciphertextSource.readRange(
            0,
            1040,
          );
          final stalled = Completer<void>();
          server.listen((request) {
            if (request.headers.value('range') == 'bytes=0-1039') {
              request.response
                ..statusCode = 206
                ..headers.set(
                  'content-range',
                  'bytes 0-1039/${object.manifest.ciphertextLength}',
                )
                ..contentLength = 1040
                ..add(firstCiphertext);
              unawaited(request.response.close());
            } else {
              if (!stalled.isCompleted) stalled.complete();
              // No response: only cancellation, not a short socket timeout,
              // can finish the active source operation in this regression.
            }
          });
          final account = StreamCancellation();
          final operation = StreamCancellation();
          final cache = p.join(temporary.path, 'download');
          download = await NiosStreamDownload.open(
            directory: cache,
            manifest: object.manifest,
            key: object.key,
            sources: [
              HttpRangeCiphertextSource(
                uri: Uri.parse('http://127.0.0.1:${server.port}/ciphertext'),
                totalLength: object.manifest.ciphertextLength,
                timeout: const Duration(minutes: 1),
                allowInsecureLoopback: true,
              ),
            ],
            cancellation: account,
          );
          final pending = download.readRange(
            0,
            2048,
            cancellation: stop == 'operation' ? operation : null,
          );
          final cancelled = expectLater(
            pending,
            throwsA(isA<StreamCancelledException>()),
          );
          await stalled.future.timeout(const Duration(seconds: 5));
          expect(download.verifiedSegmentCount, 1);
          Future<void>? queued;
          if (stop != 'operation') {
            queued = expectLater(
              download.fetchSegment(1),
              throwsA(isA<StreamCancelledException>()),
            );
          }
          if (stop == 'close') {
            await download.close().timeout(const Duration(seconds: 2));
          } else if (stop == 'account') {
            // The read/fetch did not receive this token explicitly. The open
            // owner must still cancel both active and queued operations.
            account.cancel();
          } else {
            operation.cancel();
          }
          await cancelled.timeout(const Duration(seconds: 2));
          if (queued != null) await queued.timeout(const Duration(seconds: 2));
          if (stop == 'operation') {
            // Cancelling one player seek does not destroy the download owner.
            expect(await download.readRange(0, 1024), data.sublist(0, 1024));
          } else if (stop == 'account') {
            await expectLater(
              download.readRange(0, 1),
              throwsA(isA<StreamCancelledException>()),
            );
          }
          await download.close().timeout(const Duration(seconds: 2));
          await expectLater(download.readRange(0, 1), throwsStateError);
          expect(
            await File(p.join(cache, 'content.nsc')).readAsBytes(),
            firstCiphertext,
          );
          // A failed multi-segment read returns no partial plaintext. The
          // completed ciphertext range remains authenticated after reopening.
          download = await NiosStreamDownload.open(
            directory: cache,
            manifest: object.manifest,
            key: object.key,
            sources: [],
          );
          expect(download.verifiedSegmentCount, 1);
          expect(await download.readRange(0, 1024), data.sublist(0, 1024));
        } finally {
          await download?.close();
          await server.close(force: true);
          await temporary.delete(recursive: true);
        }
      },
    );
  }
}
