import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:universal_io/io.dart';
import 'package:pulse_flutter/services/secret_chat/secret_chat_engine.dart';
import 'package:pulse_flutter/services/secret_chat/secret_journal.dart';

class MemoryJournal implements SecretJournalBackend {
  final List<String> data = [];
  bool fail = false;
  @override
  Iterable<String> get records => data;
  @override
  Future<void> append(String record) async {
    if (fail) throw StateError('disk full');
    data.add(record);
  }

  @override
  Future<void> erase() async => data.clear();
  @override
  Future<void> compact(String snapshot) async {
    data
      ..clear()
      ..add(snapshot);
  }

  @override
  Future<void> close() async {}
}

class Hub {
  bool online = true;
  bool loseReply = false;
  bool rejectBeforeSend = false;
  final List<SecretJson> events = [];
  final Map<String, SecretJson> operations = {};
  final List<SecretJson> attempts = [];
  int messages = 0;
  final List<int> leftChats = [];
  bool failLeave = false;

  Future<SecretJson> request(
    int user,
    String peerKey,
    String action,
    SecretJson payload,
  ) async {
    if (!online) throw StateError('offline');
    if (action == 'leave_chat') {
      leftChats.add(payload['chat_id'] as int);
      if (failLeave) throw StateError('offline');
      return {};
    }
    if (action == 'get_public_key') {
      return {
        'devices': [
          {'session_id': 1, 'public_key': peerKey},
        ],
      };
    }
    if (action == 'open_direct') return {'chat_id': 42};
    if (action == 'secret_sync') {
      final after = payload['after_event_id'] as int;
      return {
        'events': events
            .where((e) => (e['event_id'] as int) > after)
            .map(secretCopy)
            .toList(),
        'has_more': false,
        'peer_public_key': peerKey,
        'peer_protocol_version': 2,
      };
    }
    final id =
        '${user}_${payload['client_operation_id'] ?? payload['client_message_id']}';
    if (action == 'secret_control') {
      if (operations.containsKey(id)) return operations[id]!;
      final result = {'event_id': events.length + 1};
      events.add({
        'event_id': events.length + 1,
        'kind': 'control',
        'sender_id': user,
        'payload': secretCopy(secretMap(payload['control'])),
      });
      return operations[id] = result;
    }
    attempts.add(secretCopy(payload));
    if (rejectBeforeSend) {
      rejectBeforeSend = false;
      throw StateError('connection lost');
    }
    if (operations.containsKey(id)) return operations[id]!;
    final deleting = action == 'delete_message';
    final sending = action == 'send_message';
    final messageId = sending ? ++messages : payload['message_id'];
    final original = sending
        ? null
        : events
              .where((e) => secretMap(e['payload'])['id'] == messageId)
              .firstOrNull;
    final result = <String, dynamic>{
      'id': messageId,
      'chat_id': 42,
      'sender_id': user,
      'client_message_id': sending
          ? payload['client_message_id']
          : secretMap(original?['payload'])['client_message_id'],
      'client_operation_id':
          payload['client_operation_id'] ?? payload['client_message_id'],
      'content': '',
      'is_e2ee': true,
      'e2ee_content': payload['e2ee_content'],
      'sent_at': DateTime.now().toUtc().toIso8601String(),
      'is_deleted': deleting,
      'reply_to_id': payload['reply_to_id'],
    };
    events.add({
      'event_id': events.length + 1,
      'sender_id': user,
      'kind': deleting
          ? 'delete'
          : sending
          ? 'message'
          : 'edit',
      'payload': secretCopy(result),
    });
    operations[id] = result;
    if (loseReply) {
      loseReply = false;
      throw StateError('reply lost after commit');
    }
    return result;
  }
}

class Transport implements SecretTransport {
  Transport(this.hub, this.user);
  final Hub hub;
  final int user;
  String peerKey = '';
  @override
  Future<SecretJson> request(String action, SecretJson payload) =>
      hub.request(user, peerKey, action, payload);
  @override
  Future<String> upload(String id, SecretJson file) async => 'upload-$id';
}

class Pair {
  final Hub hub = Hub();
  final aDisk = MemoryJournal();
  final bDisk = MemoryJournal();
  late SecretChatEngine a;
  late SecretChatEngine b;
  late Transport aTransport;
  late Transport bTransport;

  Future<SecretChatEngine> create(
    int id,
    MemoryJournal disk,
    Transport transport,
  ) async {
    final journal = SecretJournal(
      disk,
      SecretKey(List.filled(32, id)),
      accountId: id,
    );
    await journal.restore();
    final engine = SecretChatEngine(
      userId: id,
      username: 'user$id',
      journal: journal,
      transport: transport,
      staticSeed: List.filled(32, id + 3),
      identitySeed: List.filled(32, id + 9),
    );
    await engine.initialize();
    return engine;
  }

  Future<void> start() async {
    aTransport = Transport(hub, 1);
    bTransport = Transport(hub, 2);
    a = await create(1, aDisk, aTransport);
    b = await create(2, bDisk, bTransport);
    aTransport.peerKey = b.publicKey;
    bTransport.peerKey = a.publicKey;
    await a.open(peerId: 2, peerName: 'B', remoteId: 42, peerKey: b.publicKey);
    await b.open(peerId: 1, peerName: 'A', remoteId: 42, peerKey: a.publicKey);
  }

  Future<void> settle([int rounds = 15]) async {
    for (var i = 0; i < rounds; i++) {
      await Future.wait([
        a
            .pump(
              a.findChat(42) ??
                  a.journal.conversations.firstWhere(
                    (key) => a.journal.state(key)['peer_id'] == 2,
                  ),
            )
            .catchError((_) {}),
        b.pump(b.findChat(42)!).catchError((_) {}),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  }

  Future<void> close() async {
    await a.stop();
    await b.stop();
  }
}

void main() {
  test(
    'manual verification preserves ratchet, queued sends and delivery after restart',
    () async {
      final pair = Pair();
      await pair.start();
      await pair.settle();
      await pair.a.enqueue(42, {'text': 'before confirmation', 'type': 'text'});
      await pair.settle();
      pair.hub.online = false;
      await pair.a.enqueue(42, {
        'text': 'queued during confirmation',
        'type': 'text',
      });
      final before = pair.a.chat(42)..remove('verified');
      await pair.a.verifyIdentity(42);
      final after = pair.a.chat(42)..remove('verified');
      expect(after, before);
      expect(pair.a.chat(42)['verified'], true);
      expect(pair.a.messages(42).map((m) => m['content']), [
        'before confirmation',
        'queued during confirmation',
      ]);
      await pair.a.stop();
      pair.a = await pair.create(1, pair.aDisk, pair.aTransport);
      expect(pair.a.chat(42)['verified'], true);
      pair.hub.online = true;
      await pair.b.enqueue(42, {
        'text': 'reply after confirmation',
        'type': 'text',
      });
      await pair.settle();
      expect(pair.a.chat(42)['status'], 'secured');
      expect(pair.b.chat(42)['status'], 'secured');
      expect(
        pair.b
            .messages(42)
            .any((m) => m['content'] == 'queued during confirmation'),
        true,
      );
      expect(
        pair.a
            .messages(42)
            .any((m) => m['content'] == 'reply after confirmation'),
        true,
      );
      await pair.close();
    },
  );

  test(
    'verification at a real Hive checkpoint retains session and bidirectional delivery',
    () async {
      final pair = Pair();
      await pair.start();
      await pair.settle();
      await pair.a.enqueue(42, {
        'text': 'persisted before confirmation',
        'type': 'text',
      });
      await pair.settle();
      pair.hub.online = false;
      await pair.a.stop();
      final directory = await Directory.systemTemp.createTemp(
        'secret_verify_checkpoint_',
      );
      Hive.init(directory.path);
      var box = await Hive.openBox<String>('verified_a');
      await box.addAll(pair.aDisk.data);
      await box.flush();
      Future<SecretChatEngine> restore() async {
        final journal = SecretJournal(
          HiveSecretJournalBackend(box),
          SecretKey(List.filled(32, 1)),
          accountId: 1,
        );
        await journal.restore();
        final engine = SecretChatEngine(
          userId: 1,
          username: 'user1',
          journal: journal,
          transport: pair.aTransport,
          staticSeed: List.filled(32, 4),
          identitySeed: List.filled(32, 10),
        );
        await engine.initialize();
        return engine;
      }

      pair.a = await restore();
      final key = pair.a.findChat(42)!;
      while (box.length < 127) {
        await pair.a.journal.commit(
          key,
          pair.a.chat(42)..['fixture_revision'] = box.length,
        );
      }
      final ratchet = pair.a.chat(42)['ratchet'];
      await pair.a.verifyIdentity(42);
      expect(box.length, 1);
      expect(box.values.single.startsWith('snapshot:'), true);
      expect(pair.a.chat(42)['ratchet'], ratchet);
      await pair.a.stop();
      box = await Hive.openBox<String>('verified_a');
      pair.a = await restore();
      expect(pair.a.chat(42)['verified'], true);
      expect(
        pair.a.messages(42).single['content'],
        'persisted before confirmation',
      );
      pair.hub.online = true;
      await pair.a.enqueue(42, {'text': 'after checkpoint A', 'type': 'text'});
      await pair.b.enqueue(42, {'text': 'after checkpoint B', 'type': 'text'});
      await pair.settle();
      expect(
        pair.b.messages(42).any((m) => m['content'] == 'after checkpoint A'),
        true,
      );
      expect(
        pair.a.messages(42).any((m) => m['content'] == 'after checkpoint B'),
        true,
      );
      await pair.close();
      await Hive.close();
      await directory.delete(recursive: true);
    },
  );
  test(
    'delete pending local chat clears queue durably and permits opening again',
    () async {
      final pair = Pair();
      await pair.start();
      pair.hub.online = false;
      final id = await pair.a.open(peerId: 99, peerName: 'Pending');
      await pair.a.enqueue(id, {'text': 'cancelled send', 'type': 'text'});
      await pair.a.saveDraft(id, 'cancelled draft');
      await pair.a.deleteConversation(id);
      expect(pair.a.messages(id), isEmpty);
      expect(pair.a.chat(id)['status'], 'deleted');
      expect(pair.a.chat(id)['draft'], isNull);
      expect(pair.hub.leftChats, isEmpty);
      await pair.a.stop();
      pair.a = await pair.create(1, pair.aDisk, pair.aTransport);
      expect(pair.a.chat(id)['status'], 'deleted');
      expect(pair.a.messages(id), isEmpty);
      await expectLater(
        pair.a.enqueue(id, {'text': 'too late'}),
        throwsStateError,
      );
      final reopened = await pair.a.open(peerId: 99, peerName: 'Pending');
      expect(reopened, id);
      await pair.a.enqueue(reopened, {'text': 'new send', 'type': 'text'});
      expect(pair.a.messages(reopened).single['content'], 'new send');
      await pair.close();
    },
  );

  test(
    'delete remote conversation leaves server id and reopening preserves peer decryption',
    () async {
      final pair = Pair();
      await pair.start();
      await pair.settle();
      final key = pair.a.findChat(42)!;
      final state = pair.a.chat(42)..['ui_id'] = -99;
      await pair.a.journal.commit(key, state);
      await pair.a.enqueue(42, {'text': 'old local history', 'type': 'text'});
      await pair.settle();
      final pin = pair.a.chat(42)['pinned_ed'];
      await pair.a.deleteConversation(-99);
      expect(pair.hub.leftChats, [42]);
      expect(pair.a.messages(42), isEmpty);
      expect(pair.b.messages(42).single['content'], 'old local history');
      expect(pair.a.chat(42)['pinned_ed'], pin);
      final attempts = pair.hub.attempts.length;
      await pair.a.pump(pair.a.findChat(42)!);
      expect(pair.hub.attempts, hasLength(attempts));
      await pair.a.open(peerId: 2, peerName: 'B');
      await pair.a.enqueue(-99, {'text': 'new conversation', 'type': 'text'});
      await pair.a.pump(key);
      await pair.settle();
      expect(pair.a.messages(42).single['content'], 'new conversation');
      expect(pair.b.messages(42).last['content'], 'new conversation');
      await pair.close();
    },
  );

  test(
    'failed server leave keeps history and queue until deletion succeeds',
    () async {
      final pair = Pair();
      await pair.start();
      pair.hub.online = false;
      await pair.a.enqueue(42, {'text': 'keep on failure', 'type': 'text'});
      pair.hub.online = true;
      pair.hub.failLeave = true;
      await expectLater(pair.a.deleteConversation(42), throwsStateError);
      expect(pair.a.messages(42).single['content'], 'keep on failure');
      expect(pair.a.chat(42)['status'], isNot('deleted'));
      pair.hub.failLeave = false;
      await pair.a.deleteConversation(42);
      expect(pair.a.messages(42), isEmpty);
      await pair.close();
    },
  );
  test(
    'pending chat keeps selected peer name and avatar through restart and profile refresh',
    () async {
      final pair = Pair();
      await pair.start();
      pair.hub.online = false;
      final id = await pair.a.open(
        peerId: 99,
        peerName: 'Display name',
        peerProfile: {
          'display_name': 'Display name',
          'username': 'peer99',
          'avatar_url': 'avatars/peer99.jpg',
        },
      );
      await pair.a.enqueue(id, {'text': 'pending data', 'type': 'text'});
      await pair.a.stop();
      pair.a = await pair.create(1, pair.aDisk, pair.aTransport);
      final profile = secretMap(pair.a.chat(id)['peer_profile']);
      expect(profile['display_name'], 'Display name');
      expect(profile['username'], 'peer99');
      expect(profile['avatar_url'], 'avatars/peer99.jpg');
      final updated = await pair.a.open(
        peerId: 99,
        peerName: 'Updated',
        peerProfile: {
          'display_name': 'Updated',
          'username': 'peer99',
          'avatar_url': null,
        },
      );
      expect(updated, id);
      expect(
        secretMap(pair.a.chat(id)['peer_profile'])['display_name'],
        'Updated',
      );
      expect(secretMap(pair.a.chat(id)['peer_profile'])['avatar_url'], isNull);
      expect(pair.a.messages(id).single['content'], 'pending data');
      await pair.close();
    },
  );
  test(
    'remote chat arriving during creation reuses the durable local conversation',
    () async {
      final pair = Pair();
      await pair.start();
      pair.hub.online = false;
      final id = await pair.a.open(peerId: 99, peerName: 'pending');
      await pair.a.enqueue(id, {'text': 'keep this queue', 'type': 'text'});
      final resolved = await pair.a.open(
        peerId: 99,
        peerName: 'pending',
        remoteId: 123,
        peerKey: pair.b.publicKey,
      );
      expect(resolved, id);
      expect(pair.a.chat(id)['remote_id'], 123);
      expect(pair.a.messages(id).single['content'], 'keep this queue');
      expect(pair.a.journal.conversations.length, 2);
      await pair.close();
    },
  );
  test('Hive journal recovers queue and checkpoint from real files', () async {
    final directory = await Directory.systemTemp.createTemp(
      'niosmess-secret-journal-',
    );
    Hive.init(directory.path);
    final key = SecretKey(List.filled(32, 4));
    var box = await Hive.openBox<String>('account1');
    var journal = SecretJournal(
      HiveSecretJournalBackend(box),
      key,
      accountId: 1,
    );
    for (var i = 0; i < 140; i++) {
      await journal.commit(
        'chat',
        {'cursor': i},
        messages: {
          'message': {
            'local_id': 'message',
            'body': {'text': 'saved $i'},
            'operations': [
              {'id': 'stable'},
            ],
          },
        },
      );
    }
    await journal.close();
    box = await Hive.openBox<String>('account1');
    journal = SecretJournal(HiveSecretJournalBackend(box), key, accountId: 1);
    await journal.restore();
    expect(journal.state('chat')['cursor'], 139);
    expect(
      secretMap(journal.messages('chat').single['body'])['text'],
      'saved 139',
    );
    await journal.commit('chat', {'cursor': 140}, remove: ['message']);
    await journal.close();
    box = await Hive.openBox<String>('account1');
    journal = SecretJournal(HiveSecretJournalBackend(box), key, accountId: 1);
    await journal.restore();
    expect(journal.messages('chat'), isEmpty);
    expect(box.length, 1);
    await journal.close(erase: true);
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('reply to queued message resolves to its confirmed server id', () async {
    final pair = Pair();
    await pair.start();
    pair.hub.online = false;
    await pair.a.enqueue(42, {'text': 'original', 'type': 'text'});
    final local = pair.a.messages(42).single['id'] as int;
    await pair.a.enqueue(42, {
      'text': 'reply',
      'type': 'text',
    }, replyToId: local);
    pair.hub.online = true;
    await pair.settle();
    expect(pair.hub.messages, 2);
    expect(
      pair.b.messages(42).last['reply_to_id'],
      pair.b.messages(42).first['id'],
    );
    await pair.close();
  });

  test(
    'invalid signature pauses delivery without erasing queued plaintext',
    () async {
      final pair = Pair();
      await pair.start();
      await pair.settle();
      final control = secretCopy(
        secretMap(
          pair.hub.events.firstWhere(
            (e) => e['kind'] == 'control' && e['sender_id'] == 2,
          )['payload'],
        ),
      );
      control['sig'] = base64Encode(List.filled(64, 0));
      pair.hub.events.add({
        'event_id': pair.hub.events.length + 1,
        'kind': 'control',
        'sender_id': 2,
        'payload': control,
      });
      await pair.settle();
      await pair.a.enqueue(42, {'text': 'still mine', 'type': 'text'});
      await pair.settle();
      expect(pair.a.chat(42)['status'], 'invalidSignature');
      expect(pair.a.messages(42).single['content'], 'still mine');
      expect(pair.a.messages(42).single['is_sending'], true);
      expect(pair.hub.messages, 0);
      await pair.close();
    },
  );

  test('empty or corrupt own echo cannot replace authored body', () async {
    final pair = Pair();
    await pair.start();
    await pair.settle();
    await pair.a.enqueue(42, {'text': 'original stays', 'type': 'text'});
    await pair.settle();
    final original = secretCopy(pair.hub.events.last['payload'] as SecretJson);
    original['e2ee_content'] = 'broken';
    original['content'] = '';
    pair.hub.events.add({
      'event_id': pair.hub.events.length + 1,
      'kind': 'edit',
      'sender_id': 1,
      'payload': original,
    });
    await pair.settle();
    expect(pair.a.messages(42).single['content'], 'original stays');
    expect(pair.b.messages(42).single['content'], 'original stays');
    await pair.close();
  });

  test(
    'changed identity requires approval and keeps queued messages',
    () async {
      final pair = Pair();
      await pair.start();
      await pair.settle();
      await pair.b.stop();
      final journal = SecretJournal(
        pair.bDisk,
        SecretKey(List.filled(32, 2)),
        accountId: 2,
      );
      await journal.restore();
      pair.b = SecretChatEngine(
        userId: 2,
        username: 'user2',
        journal: journal,
        transport: pair.bTransport,
        staticSeed: List.filled(32, 5),
        identitySeed: List.filled(32, 99),
      );
      await pair.b.initialize();
      final key = pair.b.findChat(42)!;
      final fresh = journal.state(key)
        ..['ratchet'] = null
        ..['controls'] = <String, dynamic>{}
        ..['reset_requested'] = false
        ..['status'] = 'waiting';
      await journal.commit(key, fresh);
      await pair.settle();
      expect(pair.a.chat(42)['status'], 'keyChanged');
      await pair.a.enqueue(42, {'text': 'wait for approval', 'type': 'text'});
      await pair.settle();
      expect(pair.hub.messages, 0);
      expect(pair.a.messages(42).single['content'], 'wait for approval');
      await pair.a.acceptChangedIdentity(42);
      await pair.settle(25);
      expect(pair.a.chat(42)['status'], 'secured');
      expect(pair.b.messages(42).single['content'], 'wait for approval');
      await pair.close();
    },
  );
  test(
    'journal refuses torn/wrong-account records instead of resetting history',
    () async {
      final disk = MemoryJournal();
      final journal = SecretJournal(
        disk,
        SecretKey(List.filled(32, 7)),
        accountId: 1,
      );
      await journal.commit(
        'chat',
        {'ratchet': 'private state'},
        messages: {
          '1': {'text': 'important secret'},
        },
      );
      expect(disk.data.single, isNot(contains('important secret')));
      final restored = SecretJournal(
        disk,
        SecretKey(List.filled(32, 7)),
        accountId: 1,
      );
      await restored.restore();
      expect(restored.messages('chat').single['text'], 'important secret');
      final wrong = SecretJournal(
        disk,
        SecretKey(List.filled(32, 7)),
        accountId: 2,
      );
      await expectLater(
        wrong.restore(),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    },
  );

  test('failed durable write does not publish an accepted message', () async {
    final pair = Pair();
    await pair.start();
    pair.hub.online = false;
    pair.aDisk.fail = true;
    await expectLater(
      pair.a.enqueue(42, {'text': 'keep in composer', 'type': 'text'}),
      throwsStateError,
    );
    expect(pair.a.messages(42), isEmpty);
    pair.aDisk.fail = false;
    await pair.close();
  });

  test(
    'offline queue survives restart before handshake, then auto-delivers',
    () async {
      final pair = Pair();
      await pair.start();
      pair.hub.online = false;
      await pair.a.enqueue(42, {'text': 'important secret', 'type': 'text'});
      expect(pair.a.messages(42).single['content'], 'important secret');
      await pair.a.stop();
      pair.a = await pair.create(1, pair.aDisk, pair.aTransport);
      expect(pair.a.messages(42).single['content'], 'important secret');
      pair.hub.online = true;
      await pair.settle();
      expect(pair.a.chat(42)['status'], 'secured');
      expect(pair.b.chat(42)['status'], 'secured');
      expect(pair.b.messages(42).single['content'], 'important secret');
      expect(pair.a.messages(42).single['is_sending'], false);
      await pair.close();
    },
  );

  test(
    'lost server acknowledgement cannot duplicate or blank own message',
    () async {
      final pair = Pair();
      await pair.start();
      await pair.settle();
      pair.hub.loseReply = true;
      await pair.a.enqueue(42, {'text': 'saved locally', 'type': 'text'});
      await pair.settle();
      expect(pair.hub.messages, 1);
      expect(pair.a.messages(42).single['content'], 'saved locally');
      expect(pair.b.messages(42).single['content'], 'saved locally');
      await pair.a.stop();
      pair.a = await pair.create(1, pair.aDisk, pair.aTransport);
      expect(pair.a.messages(42).single['content'], 'saved locally');
      await pair.close();
    },
  );

  test(
    'retry reuses committed ciphertext instead of consuming another ratchet key',
    () async {
      final pair = Pair();
      await pair.start();
      await pair.settle();
      pair.hub.rejectBeforeSend = true;
      await pair.a.enqueue(42, {
        'text': 'one immutable packet',
        'type': 'text',
      });
      await pair.settle();
      expect(pair.hub.attempts.length, greaterThanOrEqualTo(2));
      expect(
        jsonEncode(pair.hub.attempts[0]),
        jsonEncode(pair.hub.attempts[1]),
      );
      expect(pair.hub.messages, 1);
      expect(pair.b.messages(42).single['content'], 'one immutable packet');
      await pair.close();
    },
  );

  test(
    'concurrent bidirectional sends and replays preserve every message',
    () async {
      final pair = Pair();
      await pair.start();
      await pair.settle();
      await Future.wait([
        for (var i = 0; i < 12; i++)
          pair.a.enqueue(42, {'text': 'A$i', 'type': 'text'}),
        for (var i = 0; i < 12; i++)
          pair.b.enqueue(42, {'text': 'B$i', 'type': 'text'}),
      ]);
      await pair.settle(25);
      expect(pair.a.messages(42).length, 24);
      expect(pair.b.messages(42).length, 24);
      expect(
        pair.a.messages(42).every((m) => (m['content'] as String).isNotEmpty),
        true,
      );
      expect(
        pair.b.messages(42).every((m) => (m['content'] as String).isNotEmpty),
        true,
      );
      await pair.settle();
      expect(pair.hub.messages, 24);
      await pair.close();
    },
  );

  test(
    'edits retain local plaintext and decrypt new revisions on the peer',
    () async {
      final pair = Pair();
      await pair.start();
      await pair.settle();
      await pair.a.enqueue(42, {'text': 'before', 'type': 'text'});
      await pair.settle();
      final id = pair.a.messages(42).single['id'] as int;
      await pair.a.edit(42, id, 'after');
      expect(pair.a.messages(42).single['content'], 'after');
      await pair.settle();
      expect(pair.b.messages(42).single['content'], 'after');
      expect(pair.a.messages(42).single['content'], 'after');
      await pair.a.delete(42, id);
      await pair.settle();
      expect(pair.a.messages(42), isEmpty);
      expect(pair.b.messages(42), isEmpty);
      await pair.close();
    },
  );

  test(
    'file caption, file key and sticker metadata travel only inside ciphertext',
    () async {
      final pair = Pair();
      await pair.start();
      await pair.settle();
      await pair.a.enqueue(42, {
        'text': 'private caption',
        'type': 'media',
        'file': {
          'attachment_id': 'local-only',
          'key': 'private-file-key',
          'name': 'file.png',
          'size': 8,
        },
      });
      await pair.a.enqueue(42, {
        'text': '',
        'type': 'sticker',
        'sticker': {'id': 123, 'url': 'https://example.test/sticker'},
      });
      await pair.settle();
      final network = jsonEncode(pair.hub.attempts);
      expect(network, isNot(contains('private caption')));
      expect(network, isNot(contains('private-file-key')));
      expect(pair.b.messages(42).first['content'], 'private caption');
      expect(pair.b.messages(42).first['e2ee_file_key'], 'private-file-key');
      expect(secretMap(pair.b.messages(42).last['sticker'])['id'], 123);
      await pair.close();
    },
  );

  test('logout erases this journal and stops future delivery', () async {
    final pair = Pair();
    await pair.start();
    pair.hub.online = false;
    await pair.a.enqueue(42, {'text': 'erase me', 'type': 'text'});
    await pair.a.stop(erase: true);
    expect(pair.aDisk.data, isEmpty);
    expect(pair.a.messages(42), isEmpty);
    pair.hub.online = true;
    pair.a.wake();
    expect(pair.hub.messages, 0);
    await pair.b.stop();
  });
}
