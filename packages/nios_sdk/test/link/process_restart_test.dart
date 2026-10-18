import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:nios_sdk/link.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  for (final prepare in [true, false]) {
    test(
      prepare
          ? 'prepared operation survives killing its writer process'
          : 'accepted operation survives killing before peer-key preparation',
      () async {
        final directory = await Directory.systemTemp.createTemp('nios_crash_');
        Process? child;
        DurableSession? reopened;
        try {
          child = await Process.start(Platform.resolvedExecutable, [
            'run',
            'test/link/journal_child.dart',
            directory.path,
            if (!prepare) 'saved-unprepared',
          ]);
          final output = await child.stdout
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .first
              .timeout(const Duration(seconds: 30));
          final digest = (jsonDecode(output) as Map)['digest'];
          expect(child.kill(ProcessSignal.sigkill), isTrue);
          await child.exitCode.timeout(const Duration(seconds: 10));
          reopened = await DurableSession.open(
            directory: directory.path,
            accountId: 'crash-account',
            deviceId: 'a',
            journalKey: List<int>.generate(32, (index) => index + 1),
            cipher: AesGcmEnvelopeCipher(
              deviceId: 'a',
              keyForPeer: (_) async => SecretKey(List.filled(32, 17)),
            ),
            transports: [],
            autoStart: false,
          );
          expect(reopened.operation('crash-id')!.isPrepared, prepare);
          expect(
            reopened.operation('crash-id')!.preparedEnvelope?.digest,
            digest,
          );
          expect(
            reopened.savedPayload('crash-id')!['value'],
            'survives hard process termination',
          );
        } finally {
          child?.kill();
          await reopened?.close();
          await directory.delete(recursive: true);
        }
      },
    );
  }

  for (final applied in [true, false]) {
    test(
      applied
          ? 'hard death after reducer commit preserves state and dedup together'
          : 'hard death after incoming storage resumes pending reducer once',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'nios_in_crash_',
        );
        Process? child;
        DurableSession? reopened;
        try {
          child = await Process.start(Platform.resolvedExecutable, [
            'run',
            'test/link/journal_child.dart',
            directory.path,
            applied ? 'receive-applied' : 'receive-pending',
          ]);
          final output = await child.stdout
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .first
              .timeout(const Duration(seconds: 30));
          final envelope = EncryptedEnvelope.fromJson(
            (jsonDecode(output) as Map<String, dynamic>)['envelope']
                as Map<String, dynamic>,
          );
          expect(child.kill(ProcessSignal.sigkill), isTrue);
          await child.exitCode.timeout(const Duration(seconds: 10));
          reopened = await DurableSession.open(
            directory: directory.path,
            accountId: 'crash-account',
            deviceId: 'a',
            journalKey: List<int>.generate(32, (index) => index + 1),
            cipher: AesGcmEnvelopeCipher(
              deviceId: 'a',
              keyForPeer: (_) async => SecretKey(List.filled(32, 17)),
            ),
            transports: [],
            autoStart: false,
            reducer: (state, _) => {'count': (state['count'] as int? ?? 0) + 1},
          );
          expect(
            reopened.applicationState(peerId: 'b', sessionId: 'crash')['count'],
            applied ? 1 : null,
          );
          await reopened.pump();
          await reopened.receive(envelope);
          await reopened.receive(envelope);
          expect(reopened.applicationState(peerId: 'b', sessionId: 'crash'), {
            'count': 1,
          });
          expect(reopened.appliedOperations.length, 1);
        } finally {
          child?.kill(ProcessSignal.sigkill);
          if (child != null) await child.exitCode;
          await reopened?.close();
          await directory.delete(recursive: true);
        }
      },
    );
  }

  test('another process cannot race the key commitment creation', () async {
    final directory = await Directory.systemTemp.createTemp('nios_guard_lock_');
    Process? holder;
    DurableSession? session;
    Future<DurableSession> open() => DurableSession.open(
      directory: directory.path,
      accountId: 'crash-account',
      deviceId: 'a',
      journalKey: List<int>.generate(32, (index) => index + 1),
      cipher: AesGcmEnvelopeCipher(
        deviceId: 'a',
        keyForPeer: (_) async => SecretKey(List.filled(32, 17)),
      ),
      transports: [],
      autoStart: false,
    );
    try {
      holder = await Process.start(Platform.resolvedExecutable, [
        'run',
        'test/link/journal_child.dart',
        directory.path,
        'hold-key-lock',
      ]);
      await holder.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first
          .timeout(const Duration(seconds: 30));
      await expectLater(open(), throwsA(isA<FileSystemException>()));
      expect(
        await directory.list().any((file) => file.path.endsWith('.hive')),
        isFalse,
      );
      expect(holder.kill(ProcessSignal.sigkill), isTrue);
      await holder.exitCode.timeout(const Duration(seconds: 10));
      session = await open();
      await session.enqueue(
        peerId: 'b',
        sessionId: 'recovered',
        payload: {'value': 'lock released after process death'},
      );
      expect(session.operations.length, 1);
    } finally {
      holder?.kill(ProcessSignal.sigkill);
      if (holder != null) await holder.exitCode;
      await session?.close();
      await directory.delete(recursive: true);
    }
  });
}
