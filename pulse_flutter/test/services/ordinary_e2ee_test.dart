import 'package:pulse_flutter/models/api/message_model.dart';
import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_codec.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_service.dart';

void main() {
  group('Ordinary account E2E', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    final fixture =
        jsonDecode(
              File(
                'test/fixtures/ordinary_e2ee_vectors.json',
              ).readAsStringSync(),
            )
            as E2eJson;
    final records = fixture['identities'] as List;
    final alice = OrdinaryKeys.fromJson(
      (records[0] as E2eJson)['secret'] as E2eJson,
    );
    final bob = OrdinaryKeys.fromJson(
      (records[1] as E2eJson)['secret'] as E2eJson,
    );
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));
    test(
      'Python cryptography vector decrypts on sender and recipient devices',
      () async {
        for (final own in [alice, bob]) {
          final body = await OrdinaryCodec.decrypt(
            own,
            await alice.public(),
            fixture['packet'] as String,
            11,
            1,
          );
          expect(body['text'], 'Привет со второго устройства');
          expect(body['name'], 'sample.txt');
          expect(decodeE2e(body['file_key'], 32), List.filled(32, 66));
        }
        final restored = await OrdinaryCodec.restore(
          records[0]['public'] as E2eJson,
          records[0]['backup'] as String,
          records[0]['recovery'] as String,
        );
        expect(await restored.public(), await alice.public());
      },
    );
    test(
      'offline second device restores and reads both outgoing and incoming history',
      () async {
        final secret = randomE2eBytes(),
            backup = await OrdinaryCodec.backup(alice, randomE2eBytes());
        expect(backup, isNotEmpty);
        final copy = await OrdinaryCodec.restore(
          await alice.public(),
          await OrdinaryCodec.backup(alice, secret),
          OrdinaryCodec.recoveryCode(secret),
        );
        for (final sender in [alice, bob]) {
          final peer = sender.userId == 1
              ? await bob.public()
              : await alice.public();
          final encrypted = await OrdinaryCodec.encrypt(sender, peer, 11, {
            'text': 'offline',
          });
          expect(
            (await OrdinaryCodec.decrypt(
              copy,
              await sender.public(),
              encrypted,
              11,
              sender.userId,
            ))['text'],
            'offline',
          );
        }
      },
    );
    test(
      'tampering, wrong account, wrong chat and wrong reply cannot authenticate',
      () async {
        final encrypted = await OrdinaryCodec.encrypt(
          alice,
          await bob.public(),
          11,
          {'text': 'secret'},
          reply: 7,
        );
        expect(
          () async => OrdinaryCodec.decrypt(
            bob,
            await alice.public(),
            encrypted,
            12,
            1,
            reply: 7,
          ),
          throwsA(anything),
        );
        expect(
          () async => OrdinaryCodec.decrypt(
            bob,
            await alice.public(),
            encrypted,
            11,
            1,
            reply: 8,
          ),
          throwsA(anything),
        );
        expect(
          () async => OrdinaryCodec.decrypt(
            OrdinaryKeys.create(9),
            await alice.public(),
            encrypted,
            11,
            1,
            reply: 7,
          ),
          throwsA(anything),
        );
        final packet = OrdinaryCodec.packet(encrypted);
        final body = OrdinaryCodec.header(encrypted);
        body['sender'] = 3;
        packet['body'] = jsonEncode(body);
        final tampered = base64Encode(utf8.encode(jsonEncode(packet)));
        expect(
          () async => OrdinaryCodec.decrypt(
            bob,
            await bob.public(),
            tampered,
            11,
            3,
            reply: 7,
          ),
          throwsA(anything),
        );
      },
    );
    test(
      'fresh random message keys and nonces; edits bind to original message',
      () async {
        final messages = await Future.wait(
          List.generate(
            30,
            (_) => OrdinaryCodec.encrypt(
              alice,
              records[1]['public'] as E2eJson,
              11,
              {'text': 'same'},
              edit: 42,
            ),
          ),
        );
        expect(messages.toSet().length, 30);
        for (final message in messages) {
          expect(
            (await OrdinaryCodec.decrypt(
              bob,
              await alice.public(),
              message,
              11,
              1,
              edit: 42,
            ))['text'],
            'same',
          );
        }
        expect(
          () => OrdinaryCodec.decrypt(
            bob,
            records[0]['public'] as E2eJson,
            messages[0],
            11,
            1,
          ),
          throwsA(anything),
        );
      },
    );
    test(
      'recovery backup rejects wrong key, wrong identity and bit flip',
      () async {
        final secret = randomE2eBytes();
        final backup = await OrdinaryCodec.backup(alice, secret);
        expect(
          () => OrdinaryCodec.restore(
            records[0]['public'] as E2eJson,
            backup,
            OrdinaryCodec.recoveryCode(randomE2eBytes()),
          ),
          throwsA(anything),
        );
        expect(
          () => OrdinaryCodec.restore(
            records[1]['public'] as E2eJson,
            backup,
            OrdinaryCodec.recoveryCode(secret),
          ),
          throwsA(anything),
        );
        final bytes = base64Decode(backup);
        bytes[20] ^= 1;
        expect(
          () => OrdinaryCodec.restore(
            records[0]['public'] as E2eJson,
            base64Encode(bytes),
            OrdinaryCodec.recoveryCode(secret),
          ),
          throwsA(anything),
        );
      },
    );
    test(
      'pairing requires target private key AND out-of-band pairing secret',
      () async {
        final device = await X25519().newKeyPair();
        final target = base64Encode((await device.extractPublicKey()).bytes);
        final pairSecret = randomE2eBytes(), recovery = randomE2eBytes();
        final packet = await OrdinaryCodec.pair(
          alice,
          recovery,
          target,
          'pair',
          pairSecret,
        );
        final recovered = await OrdinaryCodec.unpair(
          device,
          1,
          'pair',
          packet,
          pairSecret,
        );
        expect(recovered['keys'], alice.secret());
        expect(
          () =>
              OrdinaryCodec.unpair(device, 1, 'pair', packet, randomE2eBytes()),
          throwsA(anything),
        );
        expect(
          () => OrdinaryCodec.unpair(device, 1, 'another', packet, pairSecret),
          throwsA(anything),
        );
        expect(
          () async => OrdinaryCodec.unpair(
            await X25519().newKeyPair(),
            1,
            'pair',
            packet,
            pairSecret,
          ),
          throwsA(anything),
        );
      },
    );
    test(
      'client registers public material only, restart and recovery restore identity',
      () async {
        E2eJson? remote;
        final requests = <E2eJson>[];
        Future<dynamic> transport(String action, {E2eJson? payload}) async {
          expect(action, 'ordinary_e2ee');
          final p = payload!;
          requests.add(p);
          if (p['op'] == 'status') {
            return {
              'enabled': true,
              'identity': remote?['identity'],
              'backup': remote?['backup'],
            };
          }
          if (p['op'] == 'register') {
            remote = {
              'identity': OrdinaryCodec.canonical(p),
              'backup': p['backup'],
            };
            return {'identity': remote!['identity']};
          }
          throw StateError('unexpected operation');
        }

        final first = OrdinaryE2eeService(1, transport);
        await Future.wait([first.open(), first.open()]);
        final code = await first.recoveryCode();
        final fingerprint = await first.ownFingerprint();
        final restarted = OrdinaryE2eeService(1, transport);
        await restarted.open();
        expect(await restarted.ownFingerprint(), fingerprint);
        FlutterSecureStorage.setMockInitialValues({});
        final lost = OrdinaryE2eeService(1, transport);
        await lost.open();
        expect(lost.locked, isTrue);
        await lost.restore(code);
        expect(lost.locked, isFalse);
        expect(await lost.ownFingerprint(), fingerprint);
        expect(jsonEncode(requests), isNot(contains('dh_seed')));
        expect(jsonEncode(requests), isNot(contains('ed_seed')));
        expect(jsonEncode(requests), isNot(contains(code)));
        first.dispose();
        restarted.dispose();
        lost.dispose();
      },
    );

    test(
      'lost reset acknowledgement recovers staged private keys on restart',
      () async {
        E2eJson? remote;
        bool lose = true;
        Future<dynamic> transport(String action, {E2eJson? payload}) async {
          final p = payload!;
          if (p['op'] == 'status') {
            return {
              'enabled': true,
              'identity': remote?['identity'],
              'backup': remote?['backup'],
            };
          }
          if (p['op'] == 'register' || p['op'] == 'reset') {
            remote = {
              'identity': OrdinaryCodec.canonical(p),
              'backup': p['backup'],
            };
            if (p['op'] == 'reset' && lose) {
              lose = false;
              throw StateError('lost acknowledgement');
            }
            return {'identity': remote!['identity']};
          }
          throw StateError('unexpected');
        }

        final first = OrdinaryE2eeService(1, transport);
        await first.open();
        final before = await first.ownFingerprint();
        await first.acknowledgeBackup();
        await expectLater(first.resetAfterLoss(), throwsStateError);
        first.dispose();
        final restarted = OrdinaryE2eeService(1, transport);
        await restarted.open();
        expect(restarted.locked, isFalse);
        expect(restarted.backupAcknowledged, isFalse);
        expect(await restarted.ownFingerprint(), isNot(before));
        final restored = await OrdinaryCodec.restore(
          remote!['identity'] as E2eJson,
          remote!['backup'] as String,
          await restarted.recoveryCode(),
        );
        expect(await restored.public(), remote!['identity']);
        restarted.dispose();
      },
    );
    test(
      'device pairing transfers keys without recovery or pairing secrets reaching relay',
      () async {
        E2eJson? remote;
        final relay = <String, E2eJson>{};
        final requests = <E2eJson>[];
        Future<dynamic> transport(String action, {E2eJson? payload}) async {
          final p = payload!;
          requests.add(p);
          switch (p['op']) {
            case 'status':
              return {
                'enabled': true,
                'identity': remote?['identity'],
                'backup': remote?['backup'],
              };
            case 'register':
              remote = {
                'identity': OrdinaryCodec.canonical(p),
                'backup': p['backup'],
              };
              return {'identity': remote!['identity']};
            case 'pair_start':
              relay[p['request_id'] as String] = {
                'target_key': p['target_key'],
                'packet': null,
              };
              return {};
            case 'pair_approve':
              relay[p['request_id'] as String]!['packet'] = p['packet'];
              return {};
            case 'pair_get':
              return relay[p['request_id'] as String]!;
            default:
              throw StateError('unexpected');
          }
        }

        final old = OrdinaryE2eeService(1, transport);
        await old.open();
        final recovery = await old.recoveryCode();
        final fingerprint = await old.ownFingerprint();
        FlutterSecureStorage.setMockInitialValues({});
        final fresh = OrdinaryE2eeService(1, transport);
        await fresh.open();
        expect(fresh.locked, isTrue);
        final code = await fresh.beginPairing();
        final decoded =
            jsonDecode(
                  utf8.decode(
                    base64Url.decode(code.replaceFirst('niosmess-e2e:', '')),
                  ),
                )
                as E2eJson;
        await old.approvePairing(code);
        expect(await fresh.completePairing(), isTrue);
        expect(await fresh.ownFingerprint(), fingerprint);
        expect(await fresh.recoveryCode(), recovery);
        expect(jsonEncode(requests), isNot(contains(recovery)));
        expect(
          jsonEncode(requests),
          isNot(contains(decoded['secret'] as String)),
        );
        old.dispose();
        fresh.dispose();
      },
    );
    test(
      'a recycled numeric account id cannot reuse the previous account keys',
      () async {
        E2eJson? remote;
        String subject = 'old-account';
        Future<dynamic> transport(String action, {E2eJson? payload}) async {
          if (payload!['op'] == 'status') {
            return {
              'account_subject': subject,
              'enabled': true,
              'identity': remote?['identity'],
              'backup': remote?['backup'],
            };
          }
          remote = {
            'identity': OrdinaryCodec.canonical(payload),
            'backup': payload['backup'],
          };
          return {'identity': remote!['identity']};
        }

        final service = OrdinaryE2eeService(1, transport);
        await service.open();
        final old = await service.ownFingerprint();
        subject = 'new-account';
        remote = null;
        await service.open();
        expect(await service.ownFingerprint(), isNot(old));
        service.dispose();
      },
    );

    test(
      'relay cannot mark unauthenticated plaintext or attachment as decrypted',
      () async {
        final service = OrdinaryE2eeService(
          1,
          (action, {payload}) async =>
              throw StateError('No directory lookup should occur'),
        );
        final forged = ApiMessage.fromJson({
          'id': 2,
          'chat_id': 11,
          'sender_id': 3,
          'msg_type': 'media',
          'content': 'relay-forged content',
          'is_sticker': true,
          'sticker_set_id': 999,
          'is_e2ee': true,
          'is_decrypted': true,
          'e2ee_content': base64Encode(utf8.encode('{}')),
          'media_url': 'https://example.invalid/forged',
          'e2ee_file_key': base64Encode(List.filled(32, 9)),
          'reply_markup': {
            'inline_keyboard': [
              [
                {'text': 'forged', 'callback_data': 'forged'},
              ],
            ],
          },
        });
        final result = await service.decrypt(forged);
        expect(result.content, isNot(contains('relay-forged')));
        expect(result.isDecrypted, isFalse);
        expect(result.isSticker, isFalse);
        expect(result.mediaUrl, isNull);
        expect(result.e2eeFileKey, isNull);
        expect(result.replyMarkup, isNull);
        service.dispose();
      },
    );
    test('transport flags cannot override a valid signed packet', () async {
      FlutterSecureStorage.setMockInitialValues({
        'niosmess.ordinary.1.v1.keys': jsonEncode({
          'keys': alice.secret(),
          'recovery': records[0]['recovery'],
          'old': [],
        }),
      });
      final service = OrdinaryE2eeService(1, (action, {payload}) async {
        if (payload!['op'] == 'status') {
          return {
            'enabled': true,
            'identity': records[0]['public'],
            'backup': records[0]['backup'],
          };
        }
        return records[0]['public'];
      });
      final message = ApiMessage.fromJson({
        'id': 3,
        'chat_id': 11,
        'sender_id': 1,
        'msg_type': 'text',
        'content': 'forged transport body',
        'is_e2ee': false,
        'is_decrypted': true,
        'e2ee_content': fixture['packet'],
        'reply_markup': {
          'inline_keyboard': [
            [
              {'text': 'forged', 'callback_data': 'forged'},
            ],
          ],
        },
      });
      final result = await service.decrypt(message);
      expect(result.content, 'Привет со второго устройства');
      expect(result.isE2ee, isTrue);
      expect(result.isDecrypted, isTrue);
      expect(result.replyMarkup, isNull);
      service.dispose();
    });
  });
}
