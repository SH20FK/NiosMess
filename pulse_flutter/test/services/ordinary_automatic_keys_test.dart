import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_codec.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_service.dart';

class _Account {
  final own = OrdinaryKeys.create(1), oldPeer = OrdinaryKeys.create(2);
  final recovery = OrdinaryCodec.recoveryCode(randomE2eBytes());
  final storage = const FlutterSecureStorage();
  late OrdinaryKeys peer = oldPeer;
  bool online = true, corrupt = false, unavailable = false;
  int statusCalls = 0, chatCalls = 0;
  late OrdinaryE2eeService service;
  Future<void> save({List<OrdinaryKeys> old = const []}) => storage.write(
    key: 'niosmess.ordinary.1.v1.keys',
    value: jsonEncode({
      'keys': own.secret(),
      'recovery': recovery,
      'old': old.map((k) => k.secret()).toList(),
    }),
  );
  Future<void> open() async {
    await save();
    service = OrdinaryE2eeService(
      1,
      (action, {payload}) async {
        if (!online) throw StateError('No network allowed');
        switch (payload!['op']) {
          case 'status':
            statusCalls++;
            return {'enabled': true, 'identity': await own.public()};
          case 'chat':
            chatCalls++;
            if (unavailable) throw StateError('Connection lost');
            final public = await peer.public();
            return {
              'eligible': true,
              'required': true,
              'own': await own.public(),
              'peer': {
                ...public,
                if (corrupt) 'dh': base64Encode(List.filled(32, 99)),
              },
            };
          case 'identity':
            return payload['epoch'] == oldPeer.epoch
                ? await oldPeer.public()
                : await peer.public();
        }
        throw StateError('Unexpected operation');
      },
      isOnline: () => online,
      meshEnabled: () => true,
    );
    await service.open();
  }

  Future<ApiMessage> incoming(
    OrdinaryKeys sender,
    OrdinaryKeys target, {
    String text = 'Текст',
  }) async => ApiMessage.fromJson({
    'id': 1,
    'chat_id': 11,
    'sender_id': 2,
    'content': '',
    'is_e2ee': true,
    'e2ee_content': await OrdinaryCodec.encrypt(
      sender,
      await target.public(),
      11,
      {'text': text},
    ),
    'sent_at': DateTime.now().toIso8601String(),
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('current contact key rotation warns and continues encryption', () async {
    final a = _Account();
    await a.open();
    addTearDown(a.service.dispose);
    await a.service.prepare(11, force: true);
    expect(a.service.contactKeyChange(11), isNull);
    a.peer = OrdinaryKeys.create(2);
    await a.service.prepare(11, force: true);
    expect(a.service.contactKeyChange(11), a.peer.epoch);
    final cipher = await a.service.encrypt(11, 'После смены ключа');
    final clear = await OrdinaryCodec.decrypt(
      a.peer,
      await a.own.public(),
      cipher,
      11,
      1,
    );
    expect(clear['text'], 'После смены ключа');
    await a.service.dismissContactKeyChange(11, a.peer.epoch);
    final historical = await a.service.decrypt(
      await a.incoming(a.oldPeer, a.own),
    );
    expect(historical.isDecrypted, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await a.service.prepare(11, force: true);
    expect(
      a.service.contactKeyChange(11),
      isNull,
      reason: 'History must not roll back the current pin',
    );
  });
  test(
    'reusing an epoch for a different public key still fails closed',
    () async {
      final a = _Account();
      await a.open();
      addTearDown(a.service.dispose);
      await a.service.prepare(11, force: true);
      a.corrupt = true;
      await expectLater(a.service.encrypt(11, 'Секрет'), throwsStateError);
      expect(a.service.contactKeyChange(11), isNull);
    },
  );
  test(
    'background warm works without opening a chat and survives an outage',
    () async {
      final a = _Account();
      await a.open();
      addTearDown(a.service.dispose);
      expect(await a.service.warmMeshChat(11), isTrue);
      expect(await a.service.warmMeshChat(11), isFalse);
      a.unavailable = true;
      await expectLater(a.service.prepare(11, force: true), throwsStateError);
      a.online = false;
      final cipher = await a.service.encrypt(11, 'Без открытия чата');
      expect(
        (await OrdinaryCodec.decrypt(
          a.peer,
          await a.own.public(),
          cipher,
          11,
          1,
        ))['text'],
        'Без открытия чата',
      );
    },
  );
  test(
    'missing epoch reloads saved older private keys and retries without reset',
    () async {
      final a = _Account();
      await a.open();
      addTearDown(a.service.dispose);
      final older = OrdinaryKeys.create(1);
      final oldState = a.service.keyState;
      await a.save(old: [older]);
      final message = await a.incoming(a.oldPeer, older);
      final changed = Completer<void>();
      a.service.addListener(() {
        if (a.service.keyState != oldState && !changed.isCompleted) {
          changed.complete();
        }
      });
      final pending = await a.service.decrypt(message);
      expect(pending.isDecrypted, isFalse);
      expect(pending.content, contains('Ожидаем ключи'));
      await changed.future.timeout(const Duration(seconds: 3));
      final retried = await a.service.decrypt(message);
      expect(retried.isDecrypted, isTrue);
      expect(retried.content, 'Текст');
    },
  );
}
