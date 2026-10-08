import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:universal_io/io.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/services/secret_chat/secret_chat_engine.dart';
import 'package:pulse_flutter/services/secret_chat/secret_journal.dart';

class BackendTransport implements SecretTransport {
  BackendTransport(this.ws);
  final WebSocketClient ws;
  bool offline = false;
  bool loseAck = false;
  @override
  Future<SecretJson> request(String action, SecretJson payload) async {
    if (offline) throw StateError('fixture offline');
    final result = secretMap(await ws.request(action, payload: payload));
    if (action == 'send_message' && loseAck) {
      loseAck = false;
      throw StateError('fixture lost ACK after real server commit');
    }
    return result;
  }

  @override
  Future<String> upload(String attachmentId, SecretJson file) async =>
      throw UnsupportedError('This fixture covers the real WS delivery path');
}

void main() {
  final url = Platform.environment['SECRET_CHAT_INTEGRATION_URL'];
  test(
    'two clients use real WS handlers, Hive restart, lost ACK and encrypted edits',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'niosmess-secret-clients-',
      );
      Hive.init(root.path);
      final aWs = WebSocketClient(
        baseUrl: url!,
        readToken: () => 'secret-test-1',
      );
      final bWs = WebSocketClient(
        baseUrl: url,
        readToken: () => 'secret-test-2',
      );
      final aTransport = BackendTransport(aWs);
      final bTransport = BackendTransport(bWs);
      Future<SecretChatEngine> create(
        int id,
        BackendTransport transport,
      ) async {
        final box = await Hive.openBox<String>('account$id');
        final journal = SecretJournal(
          HiveSecretJournalBackend(box),
          SecretKey(List.filled(32, id)),
          accountId: id,
        );
        await journal.restore();
        final engine = SecretChatEngine(
          userId: 1200 + id,
          username: 'user${1200 + id}',
          journal: journal,
          transport: transport,
          staticSeed: List.filled(32, id + 3),
          identitySeed: List.filled(32, id + 9),
        );
        await engine.initialize();
        return engine;
      }

      var a = await create(1, aTransport);
      final b = await create(2, bTransport);
      addTearDown(() async {
        await a.stop();
        await b.stop();
        aWs.close();
        bWs.close();
        await Hive.close();
        await root.delete(recursive: true);
      });
      await aTransport.request('set_public_key', {
        'public_key': a.publicKey,
        'secret_protocol_version': 2,
      });
      final localId = await a.open(peerId: 1202, peerName: 'B');
      await a.enqueue(localId, {
        'text': 'important saved data',
        'type': 'text',
      });
      await a.pump(a.findChat(localId)!);
      expect(a.chat(localId)['remote_id'], isNull);
      aTransport.offline = true;
      await a.stop();
      a = await create(1, aTransport);
      expect(a.messages(localId).single['content'], 'important saved data');
      await bTransport.request('set_public_key', {
        'public_key': b.publicKey,
        'secret_protocol_version': 2,
      });
      aTransport.offline = false;
      await a.pump(a.findChat(localId)!);
      final remoteId = a.chat(localId)['remote_id'] as int;
      await b.open(
        peerId: 1201,
        peerName: 'A',
        remoteId: remoteId,
        peerKey: a.publicKey,
      );
      Future<void> settle() async {
        for (var i = 0; i < 12; i++) {
          await Future.wait([
            a.pump(a.findChat(localId)!),
            b.pump(b.findChat(remoteId)!),
          ]);
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      }

      await settle();
      expect(b.messages(remoteId).single['content'], 'important saved data');
      aTransport.loseAck = true;
      await a.enqueue(localId, {'text': 'one real server row', 'type': 'text'});
      // The engine's background pump intentionally swallows transport failure.
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await settle();
      final history = await aTransport.request('history', {
        'chat_id': remoteId,
        'page_size': 100,
      });
      expect((history['messages'] as List).length, 2);
      expect(jsonEncode(history), isNot(contains('important saved data')));
      expect(jsonEncode(history), isNot(contains('one real server row')));
      final id = a.messages(localId).last['id'] as int;
      await a.edit(localId, id, 'edited locally');
      await settle();
      expect(a.messages(localId).last['content'], 'edited locally');
      expect(b.messages(remoteId).last['content'], 'edited locally');
      expect(await a.safetyNumber(localId), await b.safetyNumber(remoteId));
      final beforeVerification = a.chat(localId)..remove('verified');
      await a.verifyIdentity(localId);
      expect(a.chat(localId)..remove('verified'), beforeVerification);
      await b.verifyIdentity(remoteId);
      await a.stop();
      a = await create(1, aTransport);
      expect(a.chat(localId)['verified'], true);
      await a.enqueue(localId, {
        'text': 'verified sender still delivers',
        'type': 'text',
      });
      await b.enqueue(remoteId, {
        'text': 'verified receiver still decrypts',
        'type': 'text',
      });
      await settle();
      // enqueue starts an account-owned pump without waiting for delivery.
      // Wait for peer synchronization, rather than assuming a fixed number
      // of polling rounds means the concurrent socket sends have completed.
      final deliveryDeadline = DateTime.now().add(const Duration(seconds: 5));
      while (DateTime.now().isBefore(deliveryDeadline) &&
          (!b
                  .messages(remoteId)
                  .any(
                    (m) => m['content'] == 'verified sender still delivers',
                  ) ||
              !a
                  .messages(localId)
                  .any(
                    (m) => m['content'] == 'verified receiver still decrypts',
                  ))) {
        await Future.wait([
          a.pump(a.findChat(localId)!),
          b.pump(b.findChat(remoteId)!),
        ]);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(
        b
            .messages(remoteId)
            .any((m) => m['content'] == 'verified sender still delivers'),
        true,
      );
      expect(
        a
            .messages(localId)
            .any((m) => m['content'] == 'verified receiver still decrypts'),
        true,
      );
      expect(a.chat(localId)['status'], 'secured');
      expect(b.chat(remoteId)['status'], 'secured');
    },
    skip: url == null
        ? 'Run with loopback serve_isolated.py and SECRET_CHAT_INTEGRATION_URL'
        : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
