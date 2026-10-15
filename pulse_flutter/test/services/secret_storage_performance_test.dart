import 'dart:async';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:hive/hive.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';
import 'package:pulse_flutter/services/secret_chat/secret_attachment_store.dart';
import 'package:pulse_flutter/services/secret_chat/secret_journal.dart';
import 'package:pulse_flutter/services/secret_chat/secret_poll_schedule.dart';

class _MemoryJournal implements SecretJournalBackend {
  final List<String> data = [];
  Completer<void>? flush;
  bool fail = false;
  @override
  Iterable<String> get records => data;
  @override
  Future<void> append(String encryptedRecord) async {
    await flush?.future;
    if (fail) throw StateError('disk full');
    data.add(encryptedRecord);
  }

  @override
  Future<void> compact(String snapshot) async {
    data
      ..clear()
      ..add(snapshot);
  }

  @override
  Future<void> erase() async => data.clear();
  @override
  Future<void> close() async {}
}

SecretJson _row(
  String id,
  int numeric,
  String sent, {
  String? attachment,
  bool pending = true,
}) => {
  'local_id': id,
  'local_numeric_id': numeric,
  'message': {'id': numeric, 'sent_at': sent},
  'body': {
    'text': 'private $id',
    if (attachment != null) 'file': {'attachment_id': attachment},
  },
  'operations': [
    if (pending)
      {
        'id': id,
        'body': {
          'file': {'attachment_id': 'queued-$id'},
        },
      },
  ],
};

void main() {
  group('secret attachment payloads', () {
    late Directory directory;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('secret-lazy-');
      Hive.init(directory.path);
    });
    tearDown(() async {
      await Hive.close();
      await directory.delete(recursive: true);
    });

    test(
      'opens existing eager Hive files lazily without payload migration',
      () async {
        final previous = await Hive.openBox<Uint8List>('account1');
        final bytes = Uint8List.fromList(
          List.generate(256 * 1024, (i) => i % 251),
        );
        await previous.put('attachment', bytes);
        await previous.flush();
        await previous.close();

        var store = await SecretAttachmentStore.open('account1');
        expect(Hive.lazyBox<Uint8List>('account1').lazy, isTrue);
        expect(store.ids, ['attachment']);
        expect(await store.read('attachment'), bytes);
        await store.save('queued', Uint8List.fromList([8, 6, 7]));
        await store.close();
        store = await SecretAttachmentStore.open('account1');
        expect(await store.read('attachment'), bytes);
        expect(await store.read('queued'), [8, 6, 7]);
        await store.close();
      },
    );

    test(
      'collects only unreferenced payloads and erases only selected account',
      () async {
        var first = await SecretAttachmentStore.open('account1');
        final second = await SecretAttachmentStore.open('account2');
        for (final id in ['body', 'queued-operation', 'orphan']) {
          await first.save(id, Uint8List.fromList([1, 2, 3]));
        }
        await second.save('peer', Uint8List.fromList([9]));
        expect(await first.retain({'body', 'queued-operation'}), isTrue);
        expect(await first.retain({'body', 'queued-operation'}), isFalse);
        expect(first.ids.toSet(), {'body', 'queued-operation'});
        await first.close(erase: true);
        first = await SecretAttachmentStore.open('account1');
        expect(first.ids, isEmpty);
        expect(await second.read('peer'), [9]);
        await first.close();
        await second.close();
      },
    );
  });

  group('immutable secret journal indexes', () {
    late _MemoryJournal disk;
    late SecretJournal journal;
    final key = SecretKey(List.filled(32, 7));
    setUp(() {
      disk = _MemoryJournal();
      journal = SecretJournal(disk, key, accountId: 17);
    });
    tearDown(() => journal.close());

    test('never publishes an unflushed mutable transaction', () async {
      disk.flush = Completer<void>();
      final state = <String, dynamic>{
        'ui_id': -1,
        'ratchet': {'n': 4},
      };
      final row = _row('a', -5, '2026-01-01', attachment: 'file-a');
      final pending = journal.commit('chat', state, messages: {'a': row});
      (state['ratchet'] as Map)['n'] = 999;
      (row['body'] as Map)['text'] = 'corrupted caller';
      expect(journal.findChat(-1), isNull);
      expect(journal.messageViews('chat'), isEmpty);
      disk.flush!.complete();
      await pending;
      expect((journal.stateView('chat')['ratchet'] as Map)['n'], 4);
      expect(
        (journal.messageViewByLocalId('chat', 'a')!['body'] as Map)['text'],
        'private a',
      );
      expect(
        () => (journal.stateView('chat')['ratchet'] as Map)['n'] = 0,
        throwsUnsupportedError,
      );
      expect(
        () => (journal.messageViewByLocalId('chat', 'a')!['operations'] as List)
            .clear(),
        throwsUnsupportedError,
      );
      final detached = journal.messageByLocalId('chat', 'a')!;
      (detached['body'] as Map)['text'] = 'edit before commit';
      expect(
        (journal.messageViewByLocalId('chat', 'a')!['body'] as Map)['text'],
        'private a',
      );
    });

    test(
      'point lookups, order, outbox and attachment references survive replay',
      () async {
        await journal.commit(
          'chat',
          {'ui_id': -7, 'remote_id': 42},
          messages: {
            'later': _row('later', -2, '2026-02-02', attachment: 'shared'),
            'first': _row('first', -1, '2026-01-01', attachment: 'shared'),
          },
        );
        final ack = journal.messageByLocalId('chat', 'later')!;
        (ack['message'] as Map)['id'] = 600;
        ack['operations'] = [];
        ack['pending_message'] = {'e2ee_content': 'defer until handshake'};
        await journal.commit(
          'chat',
          journal.state('chat'),
          messages: {'later': ack},
        );
        expect(journal.messageById('chat', -2)!['local_id'], 'later');
        expect(journal.messageById('chat', 600)!['local_id'], 'later');
        expect(journal.firstPendingMessage('chat')!['local_id'], 'first');
        expect(journal.attachmentIds, {'shared', 'queued-first'});
        expect(journal.pendingInboxIds('chat'), ['later']);
        expect(journal.orderedMessageViews('chat').map((r) => r['local_id']), [
          'first',
          'later',
        ]);
        expect(
          journal
              .orderedMessageViews('chat', reverse: true)
              .map((r) => r['local_id']),
          ['later', 'first'],
        );
        expect(journal.findChat(-7), 'chat');
        expect(journal.findChat(42), 'chat');
        final revision = journal.messageRevision('chat');
        await journal.commit('chat', {
          ...journal.state('chat'),
          'verified': true,
        });
        expect(journal.messageRevision('chat'), revision);
        await journal.close();
        journal = SecretJournal(disk, key, accountId: 17);
        await journal.restore();
        expect(journal.firstPendingMessage('chat')!['local_id'], 'first');
        expect(journal.messageById('chat', 600)!['local_id'], 'later');
        expect(journal.attachmentIds, {'shared', 'queued-first'});
        await journal.commit('chat', journal.state('chat'), remove: ['first']);
        expect(journal.attachmentIds, {'shared'});
        expect(journal.messageById('chat', -1), isNull);
        expect(journal.firstPendingMessage('chat'), isNull);
      },
    );

    test(
      'expiration index follows replacements and restores independently',
      () async {
        final expiry = DateTime.utc(2026, 1, 1);
        final expiring = _row('a', -1, '2026-01-01');
        (expiring['message'] as Map)['expires_at'] = expiry.toIso8601String();
        await journal.commit(
          'chat',
          {'ui_id': 42, 'remote_id': 42},
          messages: {'a': expiring, 'b': _row('b', -2, '2026-01-02')},
        );
        expect(journal.nextExpiry, expiry);
        expect(
          journal.expiredMessageIds(
            'chat',
            expiry.subtract(const Duration(seconds: 1)),
          ),
          isEmpty,
        );
        expect(journal.expiredMessageIds('chat', expiry), ['a']);
        await journal.close();
        journal = SecretJournal(disk, key, accountId: 17);
        await journal.restore();
        expect(journal.nextExpiry, expiry);
        final deleted = journal.messageByLocalId('chat', 'a')!;
        (deleted['message'] as Map)['is_deleted'] = true;
        await journal.commit(
          'chat',
          journal.state('chat'),
          messages: {'a': deleted},
        );
        expect(journal.nextExpiry, isNull);
        expect(journal.expiredMessageIds('chat', expiry), isEmpty);
      },
    );

    test(
      'prepared head keeps durable outbox order after row replacement and restart',
      () async {
        await journal.commit(
          'chat',
          {'ui_id': 42, 'remote_id': 42},
          messages: {
            'first': _row('first', -1, '2026-01-01'),
            'second': _row('second', -2, '2026-01-02'),
          },
        );
        final head = journal.messageByLocalId('chat', 'first')!;
        ((head['operations'] as List).first as Map)['packet'] = {
          'ciphertext': 'same packet on retry',
        };
        await journal.commit(
          'chat',
          journal.state('chat'),
          messages: {'first': head},
        );
        expect(journal.firstPendingMessage('chat')!['local_id'], 'first');
        await journal.close();
        journal = SecretJournal(disk, key, accountId: 17);
        await journal.restore();
        expect(journal.firstPendingMessage('chat')!['local_id'], 'first');
        expect(
          (journal.firstPendingMessage('chat')!['operations'] as List)
              .first['packet'],
          {'ciphertext': 'same packet on retry'},
        );
      },
    );

    test(
      'failed append cannot advance indexes or remove attachment references',
      () async {
        await journal.commit(
          'chat',
          {'ui_id': 1},
          messages: {'a': _row('a', -1, '2026-01-01', attachment: 'keep')},
        );
        disk.fail = true;
        await expectLater(
          journal.commit('chat', {'ui_id': 2}, remove: ['a']),
          throwsStateError,
        );
        expect(journal.findChat(1), 'chat');
        expect(journal.findChat(2), isNull);
        expect(journal.attachmentIds, {'keep', 'queued-a'});
        expect(journal.firstPendingMessage('chat')!['local_id'], 'a');
      },
    );
  });

  test('idle backoff stops offline/background and resets for durable work', () {
    final schedule = SecretPollSchedule();
    Duration? next({
      bool connected = true,
      bool background = false,
      bool pending = false,
      bool chats = true,
    }) => schedule.next(
      connected: connected,
      background: background,
      pending: pending,
      hasChats: chats,
    );
    expect(List.generate(7, (_) => next()!.inSeconds), [
      5,
      10,
      20,
      40,
      60,
      60,
      60,
    ]);
    expect(next(connected: false, pending: true), isNull);
    expect(next(background: true), isNull);
    expect(next(chats: false), isNull);
    expect(next(background: true, pending: true), const Duration(seconds: 5));
    schedule.reset(); // onConnected / foreground catch-up
    expect(next(), const Duration(seconds: 5));
  });
}
