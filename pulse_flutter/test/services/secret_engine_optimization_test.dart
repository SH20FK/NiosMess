import 'dart:async';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/services/secret_chat/secret_chat_engine.dart';
import 'package:pulse_flutter/services/secret_chat/secret_journal.dart';

import 'secret_chat_delivery_test.dart' show MemoryJournal, Pair, Transport;

class _IndexedJournal extends SecretJournal {
  _IndexedJournal(super.backend, super.key, {required super.accountId});
  @override
  List<SecretJson> messages(String chat) =>
      throw StateError('Delivery must not copy the complete journal history');
}

class _RecordingTransport implements SecretTransport {
  _RecordingTransport(this.delegate);
  final Transport delegate;
  final List<SecretJson> requests = [];
  Completer<void>? beforeSync;
  Completer<void>? syncStarted;
  @override
  Future<SecretJson> request(String action, SecretJson payload) async {
    requests.add({'action': action, ...payload});
    if (action == 'secret_sync' && beforeSync != null) {
      syncStarted?.complete();
      await beforeSync!.future;
      beforeSync = null;
    }
    return delegate.request(action, payload);
  }

  @override
  Future<String> upload(String id, SecretJson file) =>
      delegate.upload(id, file);
}

class _IndexedPair extends Pair {
  final List<_RecordingTransport> transports = [];
  @override
  Future<SecretChatEngine> create(
    int id,
    MemoryJournal disk,
    Transport transport,
  ) async {
    final journal = _IndexedJournal(
      disk,
      SecretKey(List.filled(32, id)),
      accountId: id,
    );
    await journal.restore();
    final recording = _RecordingTransport(transport);
    transports.add(recording);
    final engine = SecretChatEngine(
      userId: id,
      username: 'user$id',
      journal: journal,
      transport: recording,
      staticSeed: List.filled(32, id + 3),
      identitySeed: List.filled(32, id + 9),
    );
    await engine.initialize();
    return engine;
  }
}

void main() {
  test(
    'indexed engine retains immutable projections across unrelated metadata',
    () async {
      final pair = _IndexedPair();
      await pair.start();
      addTearDown(pair.close);
      await pair.settle();
      await pair.a.enqueue(42, {'text': 'first', 'type': 'text'});
      await pair.a.enqueue(42, {'text': 'second', 'type': 'text'});
      await pair.settle();
      final before = pair.a.messages(42);
      expect(() => before.clear(), throwsUnsupportedError);
      expect(() => before.first['content'] = 'bad', throwsUnsupportedError);
      expect(identical(before, pair.a.messages(42)), isTrue);
      await pair.a.verifyIdentity(42);
      expect(identical(before, pair.a.messages(42)), isTrue);
      expect(pair.a.lastVisibleMessage(42)!['content'], 'second');
      final firstRow = before.first;
      await pair.a.edit(42, before.last['id'] as int, 'edited second');
      await pair.settle();
      final after = pair.a.messages(42);
      expect(after.last['content'], 'edited second');
      expect(identical(firstRow, after.first), isTrue);
      expect(pair.b.messages(42).last['content'], 'edited second');
    },
  );

  test(
    'steady secured pump makes exactly one sync without empty control poll',
    () async {
      final pair = _IndexedPair();
      await pair.start();
      addTearDown(pair.close);
      await pair.settle();
      final transport = pair.transports.first;
      transport.requests.clear();
      await pair.a.pump(pair.a.findChat(42)!);
      expect(transport.requests.map((r) => r['action']), ['secret_sync']);
    },
  );

  test(
    'local enqueue and explicit wake touch only the selected conversation',
    () async {
      final pair = _IndexedPair();
      await pair.start();
      addTearDown(pair.close);
      await pair.settle();
      await pair.a.open(
        peerId: 3,
        peerName: 'C',
        remoteId: 99,
        peerKey: pair.b.publicKey,
      );
      final transport = pair.transports.first;
      transport.requests.clear();
      await pair.a.enqueue(42, {'text': 'addressed send', 'type': 'text'});
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(transport.requests, isNotEmpty);
      expect(transport.requests.every((r) => r['chat_id'] == 42), isTrue);
      // Only an explicit fallback poll is allowed to visit the other chat.
      await pair.a.pumpAll();
      transport.requests.clear();
      pair.a.wakeChat(42);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(transport.requests, isNotEmpty);
      expect(transport.requests.every((r) => r['chat_id'] == 42), isTrue);
      expect(pair.a.messages(42).single['content'], 'addressed send');
    },
  );

  test(
    'push arriving during a sync runs one catch-up pass after busy pump',
    () async {
      final pair = _IndexedPair();
      await pair.start();
      addTearDown(pair.close);
      await pair.settle();
      final transport = pair.transports.first;
      transport.requests.clear();
      final gate = Completer<void>();
      final started = Completer<void>();
      transport.beforeSync = gate;
      transport.syncStarted = started;
      final pumping = pair.a.pump(pair.a.findChat(42)!);
      await started.future;
      pair.a.wakeChat(42);
      pair.a.wakeChat(42);
      gate.complete();
      await pumping;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(transport.requests.map((r) => r['action']), [
        'secret_sync',
        'secret_sync',
      ]);
    },
  );
}
