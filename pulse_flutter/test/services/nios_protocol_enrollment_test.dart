import 'dart:convert';

import 'package:crypto/crypto.dart' as hashing;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pulse_flutter/services/protocol/nios_protocol_accounts.dart';
import 'package:pulse_flutter/services/protocol/nios_protocol_enrollment.dart';
import 'package:universal_io/io.dart';

final class _Secrets implements ProtocolSecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String name) async => values[name];
  @override
  Future<void> write(String name, String value) async => values[name] = value;
  @override
  Future<void> delete(String name) async => values.remove(name);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'enrollment proves both persisted keys and dedupes concurrent bootstrap',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'nios-enrollment-',
      );
      final secrets = _Secrets();
      var accounts = NiosProtocolAccounts(
        secrets: secrets,
        directory: () async => directory,
      );
      var requests = 0;
      String? firstIdentity;
      Future<http.Response> server(http.Request request) async {
        requests++;
        expect(request.headers['authorization'], 'Bearer fixture-token');
        final device = request.url.pathSegments[2];
        final challenge = '12' * 32;
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'account': '7',
              'device': device,
              'session': 31,
              'challenge': challenge,
              'expires': 9999999999999,
            }),
            200,
          );
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final capabilities = body['protocols'];
        expect(capabilities['stream'], [1]);
        expect(capabilities['link'], isEmpty);
        expect(capabilities['mls']['versions'], isEmpty);
        expect(capabilities['irohAlpn'], isEmpty);
        final statement = utf8.encode(
          jsonEncode([
            'nios-device-registration',
            1,
            '7',
            device,
            body['identity_key'],
            body['link_key'],
            null,
            null,
            'legacy-fixture',
            hashing.sha256
                .convert(utf8.encode(jsonEncode(capabilities)))
                .toString(),
          ]),
        );
        final proof = utf8.encode(
          jsonEncode([
            'nios-device-enrollment',
            1,
            '7',
            device,
            31,
            challenge,
            hashing.sha256.convert(statement).toString(),
          ]),
        );
        for (final (key, signature, bytes) in [
          ('identity_key', 'identity_signature', statement),
          ('link_key', 'device_proof', proof),
        ]) {
          expect(
            await Ed25519().verify(
              bytes,
              signature: Signature(
                base64Decode(body[signature] as String),
                publicKey: SimplePublicKey(
                  base64Decode(body[key] as String),
                  type: KeyPairType.ed25519,
                ),
              ),
            ),
            isTrue,
          );
        }
        firstIdentity ??= body['identity_key'] as String;
        expect(body['identity_key'], firstIdentity);
        return http.Response('{"registered":true}', 200);
      }

      NiosProtocolEnrollment enrollment() => NiosProtocolEnrollment(
        accounts: accounts,
        origin: Uri.parse('https://fixture.invalid'),
        clientFactory: () => MockClient(server),
      );
      try {
        var bootstrap = enrollment();
        await Future.wait(
          List.generate(
            3,
            (_) => bootstrap.ensureRegistered(
              accountId: 7,
              legacyPublicKey: 'legacy-fixture',
              bearerToken: 'fixture-token',
            ),
          ),
        );
        expect(requests, 2);
        await accounts.close();
        accounts = NiosProtocolAccounts(
          secrets: secrets,
          directory: () async => directory,
        );
        bootstrap = enrollment();
        await bootstrap.ensureRegistered(
          accountId: 7,
          legacyPublicKey: 'legacy-fixture',
          bearerToken: 'fixture-token',
        );
        expect(requests, 4);
      } finally {
        await accounts.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'wrong account challenge fails before proof publication and can retry',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'nios-enrollment-error-',
      );
      final accounts = NiosProtocolAccounts(
        secrets: _Secrets(),
        directory: () async => directory,
      );
      var calls = 0;
      final bootstrap = NiosProtocolEnrollment(
        accounts: accounts,
        origin: Uri.parse('https://fixture.invalid'),
        clientFactory: () => MockClient((request) async {
          calls++;
          return http.Response(
            jsonEncode({
              'account': '999',
              'device': request.url.pathSegments[2],
              'session': 31,
              'challenge': '12' * 32,
            }),
            200,
          );
        }),
      );
      try {
        for (var i = 0; i < 2; i++) {
          await expectLater(
            bootstrap.ensureRegistered(
              accountId: 7,
              legacyPublicKey: 'legacy-fixture',
              bearerToken: 'fixture-token',
            ),
            throwsA(isA<ProtocolEnrollmentException>()),
          );
        }
        expect(calls, 2);
      } finally {
        await accounts.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
