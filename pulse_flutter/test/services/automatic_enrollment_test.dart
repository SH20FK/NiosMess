import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/automatic_enrollment.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_codec.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_service.dart';

// Two distinct device stores, no platform keychain or real account credentials.
class DeviceStore extends FlutterSecureStorage {
  final values = <String, String>{};
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values[key];
  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final vector =
      jsonDecode(
            File(
              'test/fixtures/automatic_enrollment_vectors.json',
            ).readAsStringSync(),
          )
          as E2eJson;
  final messages =
      jsonDecode(
            File('test/fixtures/ordinary_e2ee_vectors.json').readAsStringSync(),
          )
          as E2eJson;
  final record = (messages['identities'] as List).first as E2eJson;
  final prefix =
      'niosmess.ordinary.1.${base64UrlEncode(utf8.encode('${vector['subject']}:test-created-at'))}.v1';
  EnrollmentVerifier verifier({DateTime? clock}) => EnrollmentVerifier(
    fetchKeys: () async => vector['jwks'] as E2eJson,
    now: () =>
        clock ??
        DateTime.fromMillisecondsSinceEpoch(
          (vector['now'] as int) * 1000,
          isUtc: true,
        ),
  );
  DeviceStore targetStore() =>
      DeviceStore()
        ..values[EnrollmentStore.key] = jsonEncode({
          'nonce': vector['nonce'],
          'private': vector['target_private'],
          'public': base64Encode(
            base64Url.decode(
              base64Url.normalize((vector['nonce'] as String).split(':')[2]),
            ),
          ),
          'proof': vector['proof'],
        });

  for (final repairExisting in [false, true]) {
    test(
      'signed login repairs keys, including older epochs on an unlocked device: $repairExisting',
      () async {
        final older = OrdinaryKeys.create(1);
        final other = OrdinaryKeys.create(2);
        final sourceStore = DeviceStore()
          ..values['$prefix.keys'] = jsonEncode({
            'keys': record['secret'],
            'recovery': record['recovery'],
            'old': repairExisting ? [older.secret()] : [],
          });
        final destination = targetStore();
        if (repairExisting) {
          destination.values['$prefix.keys'] = jsonEncode({
            'keys': record['secret'],
            'recovery': record['recovery'],
            'old': [],
          });
        }
        final proof = await verifier().verify(
          vector['proof'] as String,
          vector['subject'] as String,
        );
        final requests = <E2eJson>[];
        bool started = false;
        E2eJson? delivery;
        Future<dynamic> relay(
          String action, {
          Map<String, dynamic>? payload,
        }) async {
          final p = payload!;
          requests.add(p);
          switch (p['op']) {
            case 'status':
              return {
                'identity': record['public'],
                'backup': record['backup'],
                'enabled': true,
                'auto_enrollment': 1,
                'account_subject': '${vector['subject']}:test-created-at',
              };
            case 'identity':
              return p['user_id'] == 2
                  ? await other.public()
                  : record['public'];
            case 'auto_start':
              started = true;
              return {'request_id': proof.requestId};
            case 'auto_get':
              return delivery ?? {'packet': null};
            case 'auto_list':
              expect(
                await OrdinaryCodec.verify(
                  'niosmess-auto-list-v1:1:${p['request_nonce']}',
                  p['signature'] as String,
                  (record['public'] as E2eJson)['ed'] as String,
                ),
                isTrue,
              );
              return {
                'requests': started && delivery == null
                    ? [
                        {
                          'request_id': proof.requestId,
                          'proof': proof.token,
                          'epoch': (record['public'] as E2eJson)['epoch'],
                        },
                      ]
                    : [],
              };
            case 'auto_approve':
              expect(
                await OrdinaryCodec.verify(
                  await proof.approvalText(1, p['packet'] as String),
                  p['signature'] as String,
                  (record['public'] as E2eJson)['ed'] as String,
                ),
                isTrue,
              );
              delivery = {
                ...p,
                'epoch': (record['public'] as E2eJson)['epoch'],
              };
              return {'accepted': true};
          }
          throw StateError('Unexpected operation ${p['op']}');
        }

        final source = OrdinaryE2eeService(
          1,
          relay,
          storage: sourceStore,
          enrollmentVerifier: verifier(),
        );
        final target = OrdinaryE2eeService(
          1,
          relay,
          storage: destination,
          enrollmentVerifier: verifier(),
        );
        await source.open();
        await target.open();
        expect(target.locked, !repairExisting);
        ApiMessage? missing;
        if (repairExisting) {
          await target.syncAutomatic();
          expect(started, isFalse);
          expect(destination.values.containsKey(EnrollmentStore.key), isTrue);
          missing = ApiMessage.fromJson({
            'id': 100,
            'chat_id': 11,
            'sender_id': 2,
            'is_e2ee': true,
            'sent_at': '2026-10-18T00:00:00Z',
            'e2ee_content': await OrdinaryCodec.encrypt(
              other,
              await older.public(),
              11,
              {'text': 'Старая история'},
            ),
          });
          expect((await target.decrypt(missing)).isDecrypted, isFalse);
        }
        await target.syncAutomatic();
        expect(target.autoWaiting, !repairExisting);
        await source.syncAutomatic();
        source.dispose();
        await target.syncAutomatic();
        expect(target.locked, isFalse);
        expect(await target.recoveryCode(), record['recovery']);
        expect(destination.values.containsKey(EnrollmentStore.key), isFalse);
        final message = ApiMessage.fromJson({
          'id': 99,
          'chat_id': 11,
          'sender_id': 1,
          'msg_type': 'text',
          'is_e2ee': true,
          'e2ee_content': messages['packet'],
          'sent_at': '2026-10-18T00:00:00Z',
        });
        final opened = await target.decrypt(message);
        expect(opened.isDecrypted, isTrue);
        expect(opened.content, 'Привет со второго устройства');
        if (missing != null) {
          final recovered = await target.decrypt(missing);
          expect(recovered.isDecrypted, isTrue);
          expect(recovered.content, 'Старая история');
        }
        final wire = jsonEncode(requests);
        expect(wire.contains(record['recovery'] as String), isFalse);
        expect(wire.contains('dh_seed'), isFalse);
        target.dispose();
      },
    );
  }

  test(
    'expired login never asks relay for keys and falls back to recovery',
    () async {
      final requests = <String>[];
      final target = OrdinaryE2eeService(
        1,
        (action, {payload}) async {
          requests.add(payload!['op'] as String);
          return {
            'identity': record['public'],
            'backup': record['backup'],
            'enabled': true,
            'auto_enrollment': 1,
            'account_subject': '${vector['subject']}:test-created-at',
          };
        },
        storage: targetStore(),
        enrollmentVerifier: verifier(
          clock: DateTime.fromMillisecondsSinceEpoch(
            (vector['now'] as int) * 1000,
            isUtc: true,
          ).add(const Duration(minutes: 11)),
        ),
      );
      await target.syncAutomatic();
      expect(target.locked, isTrue);
      expect(target.autoWaiting, isFalse);
      expect(requests, ['status']);
      target.dispose();
    },
  );

  test(
    'logout during key verification does not persist received keys',
    () async {
      final destination = targetStore(), gate = Completer<E2eJson>();
      final target = OrdinaryE2eeService(
        1,
        (action, {payload}) async => {
          'identity': record['public'],
          'backup': record['backup'],
          'enabled': true,
          'auto_enrollment': 1,
          'account_subject': '${vector['subject']}:test-created-at',
        },
        storage: destination,
        enrollmentVerifier: EnrollmentVerifier(
          fetchKeys: () => gate.future,
          now: () => DateTime.fromMillisecondsSinceEpoch(
            (vector['now'] as int) * 1000,
            isUtc: true,
          ),
        ),
      );
      await target.open();
      final operation = target.syncAutomatic();
      target.dispose();
      gate.complete(vector['jwks'] as E2eJson);
      await expectLater(operation, throwsStateError);
      expect(destination.values.containsKey('$prefix.keys'), isFalse);
    },
  );
}
