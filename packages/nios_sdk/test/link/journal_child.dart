import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:nios_sdk/link.dart';
import 'package:universal_io/io.dart';

Future<void> main(List<String> args) async {
  // An unresolved Future alone does not keep Dart's event loop alive. Keep an
  // actual event source so the parent must kill this process at the barrier.
  Timer.periodic(const Duration(seconds: 30), (_) {});
  final mode = args.length > 1 ? args[1] : 'prepared';
  if (mode == 'hold-key-lock') {
    final name = sha256
        .convert(utf8.encode(jsonEncode(['crash-account', 'a'])))
        .toString()
        .substring(0, 32);
    final guard = await File(
      '${args.first}/nios_link_$name.keycheck.lock',
    ).open(mode: FileMode.append);
    await guard.lock(FileLock.exclusive);
    stdout.writeln(jsonEncode({'phase': 'key_commitment_locked'}));
    await Completer<void>().future;
    return;
  }
  final cipher = AesGcmEnvelopeCipher(
    deviceId: 'a',
    keyForPeer: (_) async => SecretKey(List.filled(32, 17)),
  );
  final session = await DurableSession.open(
    directory: args.first,
    accountId: 'crash-account',
    deviceId: 'a',
    journalKey: List<int>.generate(32, (index) => index + 1),
    cipher: cipher,
    transports: [],
    autoStart: false,
    reducer: mode == 'receive-pending'
        ? (_, _) => throw StateError('Application interrupted before reduction')
        : (state, _) => {'count': (state['count'] as int? ?? 0) + 1},
  );
  if (mode == 'queued-10000') {
    for (var i = 0; i < 10000; i++) {
      await session.enqueue(
        peerId: 'b',
        sessionId: 'load',
        payload: {'number': i},
        operationId: 'operation-$i',
      );
    }
    stdout.writeln(jsonEncode({'count': session.operations.length}));
    await Completer<void>().future;
    return;
  }
  if (mode == 'receive-pending' || mode == 'receive-applied') {
    final peer = AesGcmEnvelopeCipher(
      deviceId: 'b',
      keyForPeer: (_) async => SecretKey(List.filled(32, 17)),
    );
    final envelope = await peer.seal(
      const EnvelopeContext(
        senderId: 'b',
        recipientId: 'a',
        sessionId: 'crash',
        operationId: 'incoming-crash',
        sequence: 1,
      ),
      utf8.encode(jsonEncode({'value': 'durable incoming'})),
    );
    await session.receive(envelope);
    stdout.writeln(jsonEncode({'envelope': envelope.toJson()}));
    await Completer<void>().future;
    return;
  }
  final saved = await session.enqueue(
    peerId: 'b',
    sessionId: 'crash',
    payload: {'value': 'survives hard process termination'},
    operationId: 'crash-id',
    prepareImmediately: mode != 'saved-unprepared',
  );
  stdout.writeln(jsonEncode({'digest': saved.preparedEnvelope?.digest}));
  await Completer<void>().future;
}
