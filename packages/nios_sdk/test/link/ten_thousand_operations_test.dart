import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:nios_sdk/link.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  test(
    '10000 encrypted operations survive hard process death, reorder and replay once',
    () async {
      final directory = await Directory.systemTemp.createTemp('nios_10000_');
      final key = SecretKey(List.filled(32, 17));
      final journalKey = List<int>.generate(32, (i) => i + 1);
      DurableSession? a;
      DurableSession? b;
      Process? writer;
      try {
        Future<DurableSession> open(String device) => DurableSession.open(
          directory: directory.path,
          accountId: 'crash-account',
          deviceId: device,
          journalKey: journalKey,
          cipher: AesGcmEnvelopeCipher(
            deviceId: device,
            keyForPeer: (_) async => key,
          ),
          transports: [],
          autoStart: false,
          reducer: (state, operation) => {
            'count': (state['count'] as int? ?? 0) + 1,
            'sum':
                (state['sum'] as int? ?? 0) +
                (operation.payload['number'] as int),
          },
        );
        writer = await Process.start(Platform.resolvedExecutable, [
          'run',
          'test/link/journal_child.dart',
          directory.path,
          'queued-10000',
        ]);
        final errors = <String>[];
        writer.stderr.transform(utf8.decoder).listen(errors.add);
        final written = await writer.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .first
            .timeout(
              const Duration(minutes: 5),
              onTimeout: () =>
                  throw StateError('Writer did not finish: $errors'),
            );
        expect((jsonDecode(written) as Map)['count'], 10000);
        expect(writer.kill(ProcessSignal.sigkill), isTrue);
        await writer.exitCode.timeout(const Duration(seconds: 10));
        a = await open('a');
        expect(a.operations.length, 10000);
        b = await open('b');
        // Pairwise reversed deliveries exercise buffered ordering without an
        // ever-growing state snapshot or scans inside the application loop.
        for (var i = 0; i < 10000; i += 2) {
          await b.receive(a.operation('operation-${i + 1}')!.envelope);
          await b.receive(a.operation('operation-$i')!.envelope);
        }
        for (var i = 0; i < 10000; i++) {
          await a.acceptAcknowledgement(
            await b.receive(a.operation('operation-$i')!.envelope),
          );
        }
        expect(b.applicationState(peerId: 'a', sessionId: 'load'), {
          'count': 10000,
          'sum': 49995000,
        });
        expect(
          a.operations.where((operation) => operation.applied).length,
          10000,
        );
        await b.close();
        b = await open('b');
        expect(
          b.applicationState(peerId: 'a', sessionId: 'load')['count'],
          10000,
        );
        expect(b.appliedOperations.length, 10000);
      } finally {
        writer?.kill(ProcessSignal.sigkill);
        if (writer != null) await writer.exitCode;
        if (a != null && !a.isClosed) await a.close();
        if (b != null && !b.isClosed) await b.close();
        await directory.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
