import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pulse_flutter/core/network/api_constants.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/services/oauth_service.dart';

void main() {
  group('OAuthService Unit Tests', () {
    const OAuthService service = OAuthService();

    group('checkCentralNiosIdSession', () {
      test('returns true when endpoint responds with 200 OK', () async {
        final MockClient mockClient = MockClient((http.Request request) async {
          expect(request.url.toString(), equals(ApiConstants.accountCheckUrl));
          expect(request.method, equals('GET'));
          return http.Response(
            jsonEncode(<String, dynamic>{
              'status': 'ok',
              'user': <String, dynamic>{'id': 1, 'email': 'user@example.com'},
            }),
            200,
          );
        });

        final bool hasSession = await service.checkCentralNiosIdSession(client: mockClient);
        expect(hasSession, isTrue);
      });

      test('returns false ONLY when endpoint responds with 401 Unauthorized', () async {
        final MockClient mockClient = MockClient((http.Request request) async {
          return http.Response(
            jsonEncode(<String, dynamic>{'error': 'unauthorized'}),
            401,
          );
        });

        final bool hasSession = await service.checkCentralNiosIdSession(client: mockClient);
        expect(hasSession, isFalse);
      });

      test('returns true when endpoint responds with other status codes (e.g. 500)', () async {
        final MockClient mockClient = MockClient((http.Request request) async {
          return http.Response('Internal server error', 500);
        });

        final bool hasSession = await service.checkCentralNiosIdSession(client: mockClient);
        expect(hasSession, isTrue);
      });

      test('returns true on network exceptions / timeout (offline resilience)', () async {
        final MockClient mockClient = MockClient((http.Request request) async {
          throw http.ClientException('Connection failed');
        });

        final bool hasSession = await service.checkCentralNiosIdSession(client: mockClient);
        expect(hasSession, isTrue);
      });
    });

    group('exchangeAuthCode', () {
      test('successfully exchanges code for NiosOAuthTokenResponse on 200 OK', () async {
        const String code = 'auth_code_12345';
        const String verifier = 'pkce_verifier_67890';

        final MockClient mockClient = MockClient((http.Request request) async {
          expect(request.url.toString(), equals(ApiConstants.oauthTokenUrl));
          expect(request.method, equals('POST'));
          expect(request.headers['content-type'], contains('application/x-www-form-urlencoded'));

          final Map<String, String> bodyFields = request.bodyFields;
          expect(bodyFields['grant_type'], equals('authorization_code'));
          expect(bodyFields['code'], equals(code));
          expect(bodyFields['client_id'], equals(ApiConstants.clientId));
          expect(bodyFields['redirect_uri'], equals(ApiConstants.redirectUri));
          expect(bodyFields['code_verifier'], equals(verifier));

          return http.Response(
            jsonEncode(<String, dynamic>{
              'access_token': 'oauth_access_token_xyz',
              'token_type': 'Bearer',
              'expires_in': 3600,
              'scope': 'openid profile email',
              'id_token': 'mock_id_token',
            }),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        });

        final NiosOAuthTokenResponse response = await service.exchangeAuthCode(
          code: code,
          verifier: verifier,
          client: mockClient,
        );

        expect(response.isSuccess, isTrue);
        expect(response.accessToken, equals('oauth_access_token_xyz'));
        expect(response.tokenType, equals('Bearer'));
        expect(response.expiresIn, equals(3600));
        expect(response.scope, equals('openid profile email'));
        expect(response.idToken, equals('mock_id_token'));
      });

      test('throws ApiException with error description on 400 invalid_grant', () async {
        final MockClient mockClient = MockClient((http.Request request) async {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'error': 'invalid_grant',
              'error_description': 'The authorization code has expired or was already used',
            }),
            400,
            headers: <String, String>{'content-type': 'application/json'},
          );
        });

        expect(
          () => service.exchangeAuthCode(
            code: 'expired_code',
            verifier: 'test_verifier',
            client: mockClient,
          ),
          throwsA(isA<ApiException>().having(
            (ApiException e) => e.message,
            'message',
            contains('The authorization code has expired or was already used'),
          )),
        );
      });

      test('throws ApiException on invalid non-JSON body', () async {
        final MockClient mockClient = MockClient((http.Request request) async {
          return http.Response('<html>Bad Gateway</html>', 502);
        });

        expect(
          () => service.exchangeAuthCode(
            code: 'test_code',
            verifier: 'test_verifier',
            client: mockClient,
          ),
          throwsA(isA<ApiException>().having(
            (ApiException e) => e.message,
            'message',
            contains('Invalid response from OAuth token endpoint'),
          )),
        );
      });

      test('throws ApiException on network failure', () async {
        final MockClient mockClient = MockClient((http.Request request) async {
          throw http.ClientException('Socket connection timeout');
        });

        expect(
          () => service.exchangeAuthCode(
            code: 'test_code',
            verifier: 'test_verifier',
            client: mockClient,
          ),
          throwsA(isA<ApiException>().having(
            (ApiException e) => e.message,
            'message',
            contains('Network error during OAuth token exchange'),
          )),
        );
      });
    });

    group('logoutCentralNiosId', () {
      test('returns true on 200 OK', () async {
        final MockClient mockClient = MockClient((http.Request request) async {
          expect(request.url.toString(), equals(ApiConstants.centralLogoutUrl));
          expect(request.method, equals('POST'));
          return http.Response(jsonEncode(<String, dynamic>{'status': 'logged_out'}), 200);
        });

        final bool result = await service.logoutCentralNiosId(client: mockClient);
        expect(result, isTrue);
      });

      test('returns false on 500 status without throwing exception', () async {
        final MockClient mockClient = MockClient((http.Request request) async {
          return http.Response('Error', 500);
        });

        final bool result = await service.logoutCentralNiosId(client: mockClient);
        expect(result, isFalse);
      });

      test('returns false on network exception without throwing exception', () async {
        final MockClient mockClient = MockClient((http.Request request) async {
          throw http.ClientException('Connection aborted');
        });

        final bool result = await service.logoutCentralNiosId(client: mockClient);
        expect(result, isFalse);
      });
    });
  });

  group('AuthSession Model Tests', () {
    test('serializes and deserializes AuthSession with niosId', () {
      const AuthSession session = AuthSession(
        accessToken: 'jwt_token_123',
        userId: 42,
        username: 'alice',
        displayName: 'Alice Liddell',
        niosId: 'nios_alice_uuid',
      );

      final Map<String, dynamic> json = session.toJson();
      expect(json['access_token'], equals('jwt_token_123'));
      expect(json['user_id'], equals(42));
      expect(json['username'], equals('alice'));
      expect(json['display_name'], equals('Alice Liddell'));
      expect(json['nios_id'], equals('nios_alice_uuid'));

      final AuthSession parsed = AuthSession.fromJson(json);
      expect(parsed.accessToken, equals('jwt_token_123'));
      expect(parsed.userId, equals(42));
      expect(parsed.username, equals('alice'));
      expect(parsed.displayName, equals('Alice Liddell'));
      expect(parsed.niosId, equals('nios_alice_uuid'));
    });

    test('serializes and deserializes AuthSession without niosId', () {
      const AuthSession session = AuthSession(
        accessToken: 'jwt_token_456',
        userId: 99,
        username: 'bob',
        displayName: 'Bob Builder',
      );

      final Map<String, dynamic> json = session.toJson();
      expect(json.containsKey('nios_id'), isFalse);

      final AuthSession parsed = AuthSession.fromJson(json);
      expect(parsed.accessToken, equals('jwt_token_456'));
      expect(parsed.niosId, isNull);
    });

    test('copyWith updates niosId and other fields correctly', () {
      const AuthSession session = AuthSession(
        accessToken: 'token',
        userId: 1,
        username: 'user1',
        displayName: 'User One',
      );

      final AuthSession updated = session.copyWith(
        niosId: 'nios_id_updated',
        displayName: 'User Updated',
      );

      expect(updated.accessToken, equals('token'));
      expect(updated.userId, equals(1));
      expect(updated.username, equals('user1'));
      expect(updated.displayName, equals('User Updated'));
      expect(updated.niosId, equals('nios_id_updated'));
    });

    test('throws FormatException when accessToken is empty', () {
      expect(
        () => AuthSession.fromJson(<String, dynamic>{
          'access_token': '',
          'user_id': 1,
        }),
        throwsFormatException,
      );
    });
  });

  group('NiosOAuthTokenResponse Model Tests', () {
    test('parses full success token response with integer expiresIn', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'access_token': 'at_123',
        'token_type': 'Bearer',
        'expires_in': 3600,
        'scope': 'openid profile email',
        'id_token': 'idt_456',
      };

      final NiosOAuthTokenResponse response = NiosOAuthTokenResponse.fromJson(json);
      expect(response.isSuccess, isTrue);
      expect(response.accessToken, equals('at_123'));
      expect(response.tokenType, equals('Bearer'));
      expect(response.expiresIn, equals(3600));
      expect(response.scope, equals('openid profile email'));
      expect(response.idToken, equals('idt_456'));
      expect(response.error, isNull);
      expect(response.errorDescription, isNull);

      final Map<String, dynamic> outputJson = response.toJson();
      expect(outputJson['access_token'], equals('at_123'));
      expect(outputJson['expires_in'], equals(3600));
    });

    test('parses string expiresIn into int', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'access_token': 'at_string_expires',
        'expires_in': '7200',
      };

      final NiosOAuthTokenResponse response = NiosOAuthTokenResponse.fromJson(json);
      expect(response.isSuccess, isTrue);
      expect(response.expiresIn, equals(7200));
    });

    test('parses error response correctly and marks isSuccess as false', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'error': 'invalid_request',
        'error_description': 'Missing client_id',
      };

      final NiosOAuthTokenResponse response = NiosOAuthTokenResponse.fromJson(json);
      expect(response.isSuccess, isFalse);
      expect(response.error, equals('invalid_request'));
      expect(response.errorDescription, equals('Missing client_id'));
    });
  });

  group('NiosDeviceCodeResponse Model Tests', () {
    test('parses device code response and computes verification_uri_complete', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'device_code': 'device_123',
        'user_code': 'ABCD-7KLM',
        'verification_uri': 'https://ni-os.ru/id/device',
        'verification_uri_complete': 'https://ni-os.ru/id/device?user_code=ABCD-7KLM',
        'expires_in': 600,
        'interval': 5,
      };

      final NiosDeviceCodeResponse response = NiosDeviceCodeResponse.fromJson(json);
      expect(response.deviceCode, equals('device_123'));
      expect(response.userCode, equals('ABCD-7KLM'));
      expect(response.verificationUri, equals('https://ni-os.ru/id/device'));
      expect(response.verificationUriComplete, equals('https://ni-os.ru/id/device?user_code=ABCD-7KLM'));
      expect(response.expiresIn, equals(600));
      expect(response.interval, equals(5));

      final Map<String, dynamic> outputJson = response.toJson();
      expect(outputJson['device_code'], equals('device_123'));
      expect(outputJson['user_code'], equals('ABCD-7KLM'));
    });
  });

  group('OAuthService Device Flow Tests', () {
    const OAuthService service = OAuthService();

    test('requestDeviceCode succeeds and parses response', () async {
      final MockClient mockClient = MockClient((http.Request request) async {
        expect(request.url.toString(), equals(ApiConstants.oauthDeviceCodeUrl));
        expect(request.method, equals('POST'));
        expect(request.bodyFields['client_id'], equals(ApiConstants.clientId));

        return http.Response(
          jsonEncode(<String, dynamic>{
            'device_code': 'dev_code_test',
            'user_code': 'XYZ-123',
            'verification_uri': 'https://ni-os.ru/id/device',
            'verification_uri_complete': 'https://ni-os.ru/id/device?user_code=XYZ-123',
            'expires_in': 600,
            'interval': 5,
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });

      final NiosDeviceCodeResponse resp =
          await service.requestDeviceCode(client: mockClient);
      expect(resp.deviceCode, equals('dev_code_test'));
      expect(resp.userCode, equals('XYZ-123'));
    });

    test('pollDeviceToken polls and returns token when approved', () async {
      int calls = 0;
      final MockClient mockClient = MockClient((http.Request request) async {
        calls++;
        expect(request.url.toString(), equals(ApiConstants.oauthTokenUrl));
        expect(request.bodyFields['grant_type'], equals('urn:ietf:params:oauth:grant-type:device_code'));

        if (calls == 1) {
          return http.Response(
            jsonEncode(<String, dynamic>{'error': 'authorization_pending'}),
            400,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }

        return http.Response(
          jsonEncode(<String, dynamic>{
            'access_token': 'device_access_token_123',
            'token_type': 'Bearer',
            'expires_in': 3600,
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });

      final NiosOAuthTokenResponse? token = await service.pollDeviceToken(
        deviceCode: 'dev_code_test',
        intervalSeconds: 1,
        maxDurationSeconds: 10,
        client: mockClient,
      );

      expect(token, isNotNull);
      expect(token!.isSuccess, isTrue);
      expect(token.accessToken, equals('device_access_token_123'));
      expect(calls, equals(2));
    });
  });
}
