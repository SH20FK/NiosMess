import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:hive/hive.dart';
import 'package:nios_sdk/link.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

final _journalKey = List<int>.generate(32, (index) => index + 1);
final _peerKey = SecretKey(List<int>.generate(32, (index) => 255 - index));

AesGcmEnvelopeCipher _cipher(String device) =>
    AesGcmEnvelopeCipher(deviceId: device, keyForPeer: (_) async => _peerKey);

Map<String, dynamic> _counter(
  Map<String, dynamic> state,
  DurableOperation operation,
) => {
  'count': (state['count'] as int? ?? 0) + 1,
  'last': operation.payload['value'],
};

class _BlockedCipher implements EnvelopeCipher {
  _BlockedCipher(this.delegate);
  final EnvelopeCipher delegate;
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<EncryptedEnvelope> seal(
    EnvelopeContext context,
    List<int> plaintext,
  ) async {
    if (!started.isCompleted) started.complete();
    await release.future;
    return delegate.seal(context, plaintext);
  }

  @override
  Future<Uint8List> open(EncryptedEnvelope envelope) => delegate.open(envelope);
}

void main() {
  late Directory directory;
  final sessions = <DurableSession>[];

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('nios_link_test_');
  });
  tearDown(() async {
    for (final session in sessions.reversed) {
      if (!session.isClosed) await session.close();
    }
    sessions.clear();
    await directory.delete(recursive: true);
  });

  Future<DurableSession> open(
    String device, {
    List<LinkTransport> transports = const [],
    OperationReducer? reducer,
    List<int>? key,
  }) async {
    final session = await DurableSession.open(
      directory: directory.path,
      accountId: 'test-account',
      journalKey: key ?? _journalKey,
      deviceId: device,
      cipher: _cipher(device),
      transports: transports,
      reducer: reducer ?? _counter,
      autoStart: false,
    );
    sessions.add(session);
    return session;
  }

  test(
    'durable queue reopens with identical ciphertext and encrypted own payload',
    () async {
      final a = await open('a');
      final payload = <String, dynamic>{
        'value': 'never-store-this-text-unencrypted',
      };
      final first = await a.enqueue(
        peerId: 'b',
        sessionId: 'chat',
        payload: payload,
        operationId: 'stable-id',
      );
      payload['value'] = 'mutated-after-enqueue';
      final bytes = jsonEncode(first.envelope.toJson());
      expect(
        a.savedPayload('stable-id')!['value'],
        'never-store-this-text-unencrypted',
      );
      expect(first.facts, {DeliveryFact.localDurable});
      await a.close();
      final files = await directory
          .list()
          .where((file) => file.path.endsWith('.hive'))
          .toList();
      final hiveBytes = await File(files.single.path).readAsBytes();
      expect(
        utf8.decode(hiveBytes, allowMalformed: true),
        isNot(contains('never-store-this-text-unencrypted')),
      );
      final reopened = await open('a');
      expect(
        jsonEncode(reopened.operation('stable-id')!.envelope.toJson()),
        bytes,
      );
      expect(
        reopened.savedPayload('stable-id')!['value'],
        'never-store-this-text-unencrypted',
      );
      final next = await reopened.enqueue(
        peerId: 'b',
        sessionId: 'chat',
        payload: {'value': 2},
      );
      expect(next.envelope.context.sequence, 2);
      await expectLater(
        reopened.enqueue(
          peerId: 'b',
          sessionId: 'chat',
          payload: {'value': 'changed'},
          operationId: 'stable-id',
        ),
        throwsStateError,
      );
    },
  );

  test('wrong journal key cannot truncate accepted operations', () async {
    final a = await open('a');
    await a.enqueue(
      peerId: 'b',
      sessionId: 'chat',
      payload: {'value': 'valuable'},
      operationId: 'important',
    );
    await a.close();
    final files = await directory
        .list()
        .where((file) => file.path.endsWith('.hive'))
        .toList();
    final before = await File(files.single.path).readAsBytes();
    await expectLater(open('a', key: List.filled(32, 42)), throwsStateError);
    expect(await File(files.single.path).readAsBytes(), before);
    expect((await open('a')).savedPayload('important'), {'value': 'valuable'});
  });

  test(
    'concurrent opens cannot replace the first journal key commitment',
    () async {
      final firstOpening = open('a');
      final rejected = expectLater(
        open('a', key: List.filled(32, 42)),
        throwsStateError,
      );
      final first = await firstOpening;
      await rejected;
      await first.enqueue(
        peerId: 'b',
        sessionId: 'chat',
        payload: {'value': 'first key remains authoritative'},
        operationId: 'preserved',
      );
      await first.close();
      expect((await open('a')).savedPayload('preserved'), {
        'value': 'first key remains authoritative',
      });
    },
  );

  test('direct envelopes cannot bypass sequence validation', () async {
    final b = await open('b');
    final invalid = await _cipher('a').seal(
      const EnvelopeContext(
        senderId: 'a',
        recipientId: 'b',
        sessionId: 'chat',
        operationId: 'invalid-zero-sequence',
        sequence: 0,
      ),
      utf8.encode(jsonEncode({'value': 'must not be stored'})),
    );
    expect(() => b.receive(invalid), throwsFormatException);
    expect(b.appliedOperations, isEmpty);
    await b.close();
    expect((await open('b')).appliedOperations, isEmpty);
  });

  test(
    'lost recipient ACK retries identical bytes and applies exactly once',
    () async {
      final b = await open('b');
      final sentDigests = <String>[];
      var drop = true;
      final route = CallbackLinkTransport(
        receiver: (envelope) async {
          sentDigests.add(envelope.digest);
          final ack = await b.receive(envelope);
          if (drop) {
            drop = false;
            throw TimeoutException('simulated lost ACK');
          }
          return ack;
        },
      );
      var a = await open('a', transports: [route]);
      await a.enqueue(
        peerId: 'b',
        sessionId: 'chat',
        payload: {'value': 7},
        operationId: 'once',
      );
      await a.pump();
      expect(a.operation('once')!.applied, isFalse);
      expect(b.applicationState(peerId: 'a', sessionId: 'chat')['count'], 1);
      await a.close();
      a = await open(
        'a',
        transports: [
          CallbackLinkTransport(
            receiver: (envelope) async {
              sentDigests.add(envelope.digest);
              return b.receive(envelope);
            },
          ),
        ],
      );
      await a.retryNow('once');
      expect(sentDigests.length, 2);
      expect(sentDigests.toSet().length, 1);
      expect(b.applicationState(peerId: 'a', sessionId: 'chat')['count'], 1);
      expect(a.operation('once')!.facts, {
        DeliveryFact.localDurable,
        DeliveryFact.recipientStored,
        DeliveryFact.recipientApplied,
      });
      expect(
        a.operation('once')!.facts,
        isNot(contains(DeliveryFact.mailboxStored)),
      );
      expect(
        a.operation('once')!.facts,
        isNot(contains(DeliveryFact.userRead)),
      );
      final read = await b.markRead(
        peerId: 'a',
        sessionId: 'chat',
        operationId: 'once',
      );
      await a.acceptAcknowledgement(read);
      expect(a.operation('once')!.facts, contains(DeliveryFact.userRead));
    },
  );

  test(
    'reordering, duplicates, and reopening preserve contiguous application state',
    () async {
      final a = await open('a');
      var b = await open('b');
      final envelopes = <EncryptedEnvelope>[];
      for (var i = 1; i <= 3; i++) {
        envelopes.add(
          (await a.enqueue(
            peerId: 'b',
            sessionId: 'chat',
            payload: {'value': i},
          )).envelope,
        );
      }
      final stored = await b.receive(envelopes[2]);
      await a.acceptAcknowledgement(stored);
      expect(a.operations.last.facts, contains(DeliveryFact.recipientStored));
      expect(a.operations.last.applied, isFalse);
      await b.receive(envelopes[1]);
      expect(b.applicationState(peerId: 'a', sessionId: 'chat'), isEmpty);
      await b.close();
      b = await open('b');
      await b.receive(envelopes[0]);
      expect(b.applicationState(peerId: 'a', sessionId: 'chat'), {
        'count': 3,
        'last': 3,
      });
      for (final envelope in envelopes.reversed) {
        await b.receive(envelope);
      }
      expect(b.applicationState(peerId: 'a', sessionId: 'chat')['count'], 3);
      await b.close();
      b = await open('b');
      expect(b.appliedOperations.length, 3);
      expect(b.applicationState(peerId: 'a', sessionId: 'chat')['count'], 3);
    },
  );

  test(
    'a pending reducer operation recovers without the original mailbox event',
    () async {
      final a = await open('a');
      var b = await open(
        'b',
        reducer: (_, _) => throw StateError('temporary reducer bug'),
      );
      final message = await a.enqueue(
        peerId: 'b',
        sessionId: 'chat',
        payload: {'value': 'recover'},
      );
      await a.acceptAcknowledgement(await b.receive(message.envelope));
      expect(a.operation(message.operationId)!.applied, isFalse);
      await b.close();
      b = await open('b');
      await b.pump();
      expect(b.applicationState(peerId: 'a', sessionId: 'chat'), {
        'count': 1,
        'last': 'recover',
      });
      await a.acceptAcknowledgement(await b.receive(message.envelope));
      expect(a.operation(message.operationId)!.applied, isTrue);
    },
  );

  test(
    'restart retries accepted work despite a future persisted clock',
    () async {
      var a = await open('a');
      final b = await open('b');
      await a.enqueue(
        peerId: 'b',
        sessionId: 'chat',
        payload: {'value': 'resume without waiting for the old clock'},
        operationId: 'clock-jump',
      );
      final hash = sha256
          .convert(utf8.encode(jsonEncode(['test-account', 'a'])))
          .toString()
          .substring(0, 32);
      final box = Hive.box<String>('nios_link_$hash');
      final record =
          jsonDecode(box.get('o:clock-jump')!) as Map<String, dynamic>;
      // Reproduces the persisted retry deadline after the system clock moves
      // backwards while the application is stopped.
      record['nextAttemptAt'] = DateTime.now()
          .add(const Duration(days: 30))
          .millisecondsSinceEpoch;
      await box.put('o:clock-jump', jsonEncode(record));
      await box.flush();
      await a.close();
      a = await open(
        'a',
        transports: [CallbackLinkTransport(receiver: b.receive)],
      );
      await a.pump();
      expect(a.operation('clock-jump')!.applied, isTrue);
      expect(b.applicationState(peerId: 'a', sessionId: 'chat')['count'], 1);
    },
  );

  test(
    'tampering with context and forging ACKs cannot advance facts',
    () async {
      final a = await open('a');
      final b = await open('b');
      final message = await a.enqueue(
        peerId: 'b',
        sessionId: 'chat',
        payload: {'value': 'secret'},
      );
      final modified = message.envelope.toJson()..['session'] = 'other';
      await expectLater(
        b.receive(EncryptedEnvelope.fromJson(modified)),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      final valid = await b.receive(message.envelope);
      final forged = valid.toJson()
        ..['ciphertext'] = base64Encode(
          List.filled(valid.ciphertext.length, 0),
        );
      await expectLater(
        a.acceptAcknowledgement(EncryptedEnvelope.fromJson(forged)),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      final badFact = await _cipher('b').seal(
        valid.context,
        utf8.encode(
          jsonEncode({
            'digest': message.envelope.digest,
            'fact': 'mailboxStored',
          }),
        ),
      );
      await expectLater(a.acceptAcknowledgement(badFact), throwsStateError);
      expect(a.operation(message.operationId)!.facts, {
        DeliveryFact.localDurable,
      });
    },
  );

  test(
    'parallel enqueues serialize peer sequences and reserve IDs globally',
    () async {
      final a = await open('a');
      final messages = await Future.wait(
        List.generate(
          100,
          (i) =>
              a.enqueue(peerId: 'b', sessionId: 'chat', payload: {'value': i}),
        ),
      );
      expect(
        messages.map((value) => value.envelope.context.sequence).toSet(),
        Set.of(List.generate(100, (i) => i + 1)),
      );
      final first = a.enqueue(
        peerId: 'b',
        sessionId: 'chat',
        payload: {'value': 1},
        operationId: 'collision',
      );
      final other = a.enqueue(
        peerId: 'c',
        sessionId: 'chat',
        payload: {'value': 2},
        operationId: 'collision',
      );
      await first;
      await expectLater(other, throwsStateError);
      expect(a.operation('collision')!.envelope.context.recipientId, 'b');
    },
  );

  test(
    'unknown peer key queues durable payload across restart then seals once',
    () async {
      var available = false;
      var sealResolutions = 0;
      var deliveries = 0;
      final b = await open('b');
      Future<DurableSession> openWaiting() async {
        final session = await DurableSession.open(
          directory: directory.path,
          accountId: 'unknown',
          journalKey: _journalKey,
          deviceId: 'a',
          cipher: AesGcmEnvelopeCipher(
            deviceId: 'a',
            keyForPeer: (_) async {
              sealResolutions++;
              if (!available) throw StateError('unknown key');
              return _peerKey;
            },
          ),
          transports: [
            CallbackLinkTransport(
              receiver: (envelope) async {
                deliveries++;
                return b.receive(envelope);
              },
            ),
          ],
          autoStart: false,
        );
        sessions.add(session);
        return session;
      }

      var session = await openWaiting();
      final saved = await session.enqueue(
        peerId: 'b',
        sessionId: 'chat',
        payload: {'value': 'private'},
        operationId: 'waiting',
        prepareImmediately: false,
      );
      expect(saved.isPrepared, isFalse);
      expect(saved.facts, {DeliveryFact.localDurable});
      expect(sealResolutions, 0);
      await session.pump();
      expect(deliveries, 0);
      expect(session.savedPayload('waiting'), {'value': 'private'});
      await session.close();
      session = await openWaiting();
      expect(session.operation('waiting')!.isPrepared, isFalse);
      expect(session.savedPayload('waiting'), {'value': 'private'});
      available = true;
      await session.wakePeer('b');
      expect(session.operation('waiting')!.isPrepared, isTrue);
      expect(session.operation('waiting')!.applied, isTrue);
      expect(deliveries, 1);
      expect(b.applicationState(peerId: 'a', sessionId: 'chat')['count'], 1);
    },
  );

  test(
    'failed local journal write is not accepted and keeps previous data',
    () async {
      final a = await open('a');
      await a.enqueue(
        peerId: 'b',
        sessionId: 'chat',
        payload: {'value': 'already durable'},
        operationId: 'kept',
      );
      final hash = sha256
          .convert(utf8.encode(jsonEncode(['test-account', 'a'])))
          .toString()
          .substring(0, 32);
      await Hive.box<String>('nios_link_$hash').close();
      await expectLater(
        a.enqueue(
          peerId: 'b',
          sessionId: 'chat',
          payload: {'value': 'keep this draft'},
          operationId: 'failed',
        ),
        throwsA(isA<HiveError>()),
      );
      expect(a.operation('failed'), isNull);
      await a.close();
      final recovered = await open('a');
      expect(recovered.savedPayload('kept'), {'value': 'already durable'});
      expect(recovered.operation('failed'), isNull);
    },
  );

  test(
    'closing during cipher preparation preserves the accepted local operation',
    () async {
      final blocked = _BlockedCipher(_cipher('a'));
      final a = await DurableSession.open(
        directory: directory.path,
        accountId: 'closing',
        journalKey: _journalKey,
        deviceId: 'a',
        cipher: blocked,
        transports: [],
        autoStart: false,
      );
      sessions.add(a);
      final sending = a.enqueue(
        peerId: 'b',
        sessionId: 'chat',
        payload: {'value': 'keep across interruption'},
        operationId: 'closing',
      );
      await blocked.started.future;
      final closing = a.close();
      blocked.release.complete();
      final accepted = await sending;
      await closing;
      expect(accepted.facts, {DeliveryFact.localDurable});
      expect(accepted.isPrepared, isFalse);
      final reopened = await DurableSession.open(
        directory: directory.path,
        accountId: 'closing',
        journalKey: _journalKey,
        deviceId: 'a',
        cipher: _cipher('a'),
        transports: [],
        autoStart: false,
      );
      sessions.add(reopened);
      expect(reopened.savedPayload('closing'), {
        'value': 'keep across interruption',
      });
      expect(reopened.operation('closing')!.isPrepared, isFalse);
    },
  );

  test(
    'account wipe fences work and removes only that device journal',
    () async {
      final a = await open('a');
      final b = await open('b');
      await a.enqueue(peerId: 'b', sessionId: 'chat', payload: {'value': 1});
      await b.enqueue(peerId: 'a', sessionId: 'chat', payload: {'value': 2});
      await a.close(wipe: true);
      expect(
        () => a.enqueue(peerId: 'b', sessionId: 'chat', payload: {}),
        throwsStateError,
      );
      expect((await open('a')).operations, isEmpty);
      expect(b.operations.length, 1);
    },
  );

  test('remote HTTP and redirects are not silently accepted', () {
    expect(
      () => HttpMailboxTransport(
        baseUri: Uri.parse('http://example.com'),
        deviceId: 'a',
        bearerToken: 'token',
      ),
      throwsArgumentError,
    );
  });
}
