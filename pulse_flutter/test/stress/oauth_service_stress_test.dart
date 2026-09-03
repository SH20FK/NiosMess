import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/services/oauth_service.dart';
import 'package:universal_io/io.dart';

void main() {
  group('OAuthService Adversarial & Empirical Stress Tests', () {
    const OAuthService service = OAuthService();
    const String dummyCode = 'stress_auth_code_sample_12345';
    const String dummyVerifier = 'stress_pkce_verifier_sample_67890';

    group('exchangeAuthCode Malformed JSON & Unparseable Payloads', () {
      final List<Map<String, dynamic>> malformedCases = <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'Truncated JSON payload',
          'body': '{"access_token": "abc123',
          'status': 200,
        },
        <String, dynamic>{
          'name': 'Raw HTML error page on 502 Bad Gateway',
          'body': '<html><head><title>502 Bad Gateway</title></head><body><h1>Bad Gateway</h1></body></html>',
          'status': 502,
        },
        <String, dynamic>{
          'name': 'JSON Array instead of Map',
          'body': '["access_token", "bearer", 3600]',
          'status': 200,
        },
        <String, dynamic>{
          'name': 'JSON Primitive String',
          'body': '"just a raw string"',
          'status': 200,
        },
        <String, dynamic>{
          'name': 'JSON Primitive Integer',
          'body': '123456789',
          'status': 200,
        },
        <String, dynamic>{
          'name': 'Empty string body on 200 OK',
          'body': '',
          'status': 200,
        },
        <String, dynamic>{
          'name': 'Whitespace only body on 200 OK',
          'body': '   \n\t  \r\n   ',
          'status': 200,
        },
        <String, dynamic>{
          'name': 'Malformed UTF-8 / binary payload',
          'body': '\x00\x01\x02\xFF\xFE',
          'status': 500,
        },
      ];

      for (final Map<String, dynamic> testCase in malformedCases) {
        test('Handles ${testCase['name']} gracefully without crashing', () async {
          final MockClient mockClient = MockClient((http.Request request) async {
            return http.Response(
              testCase['body'] as String,
              testCase['status'] as int,
              headers: <String, String>{'content-type': 'text/plain'},
            );
          });

          expect(
            () => service.exchangeAuthCode(
              code: dummyCode,
              verifier: dummyVerifier,
              client: mockClient,
            ),
            throwsA(isA<ApiException>().having(
              (ApiException e) => e.statusCode,
              'statusCode',
              equals(testCase['status'] as int),
            )),
          );
        });
      }
    });

    group('exchangeAuthCode HTTP Error Statuses & OAuth Error Codes', () {
      final List<Map<String, dynamic>> errorScenarios = <Map<String, dynamic>>[
        <String, dynamic>{
          'status': 400,
          'json': <String, dynamic>{
            'error': 'invalid_grant',
            'error_description': 'The authorization code has expired or was already used',
          },
          'expectedMsg': 'The authorization code has expired or was already used',
        },
        <String, dynamic>{
          'status': 400,
          'json': <String, dynamic>{
            'error': 'invalid_request',
            'error_description': 'Missing required parameter: code_verifier',
          },
          'expectedMsg': 'Missing required parameter: code_verifier',
        },
        <String, dynamic>{
          'status': 400,
          'json': <String, dynamic>{
            'error': 'unsupported_grant_type',
          },
          'expectedMsg': 'unsupported_grant_type',
        },
        <String, dynamic>{
          'status': 400,
          'json': <String, dynamic>{
            'error_message': 'Legacy error message format',
          },
          'expectedMsg': 'Legacy error message format',
        },
        <String, dynamic>{
          'status': 400,
          'json': <String, dynamic>{
            'message': 'Spring/Nest standard error message',
          },
          'expectedMsg': 'Spring/Nest standard error message',
        },
        <String, dynamic>{
          'status': 400,
          'json': <String, dynamic>{},
          'expectedMsg': 'OAuth token exchange failed with status 400',
        },
        <String, dynamic>{
          'status': 401,
          'json': <String, dynamic>{
            'error': 'invalid_client',
            'error_description': 'Client authentication failed',
          },
          'expectedMsg': 'Client authentication failed',
        },
        <String, dynamic>{
          'status': 403,
          'json': <String, dynamic>{
            'error': 'access_denied',
            'error_description': 'Resource access is forbidden',
          },
          'expectedMsg': 'Resource access is forbidden',
        },
        <String, dynamic>{
          'status': 404,
          'json': <String, dynamic>{
            'error': 'not_found',
            'error_description': 'OAuth endpoint not found',
          },
          'expectedMsg': 'OAuth endpoint not found',
        },
        <String, dynamic>{
          'status': 429,
          'json': <String, dynamic>{
            'error': 'rate_limit_exceeded',
            'error_description': 'Too many requests, slow down',
          },
          'expectedMsg': 'Too many requests, slow down',
        },
        <String, dynamic>{
          'status': 500,
          'json': <String, dynamic>{
            'error': 'server_error',
            'error_description': 'Internal database connection failure',
          },
          'expectedMsg': 'Internal database connection failure',
        },
        <String, dynamic>{
          'status': 503,
          'json': <String, dynamic>{
            'error': 'temporarily_unavailable',
            'error_description': 'Service is undergoing maintenance',
          },
          'expectedMsg': 'Service is undergoing maintenance',
        },
        <String, dynamic>{
          'status': 200,
          'json': <String, dynamic>{
            'error': 'unexpected_error_in_200',
            'error_description': 'Server returned error inside 200 OK',
          },
          'expectedMsg': 'Server returned error inside 200 OK',
        },
        <String, dynamic>{
          'status': 200,
          'json': <String, dynamic>{
            'access_token': '', // Empty access token
          },
          'expectedMsg': 'OAuth token exchange failed with status 200',
        },
      ];

      for (final Map<String, dynamic> scenario in errorScenarios) {
        test('Handles status ${scenario['status']} with body ${scenario['json']} correctly', () async {
          final MockClient mockClient = MockClient((http.Request request) async {
            return http.Response(
              jsonEncode(scenario['json']),
              scenario['status'] as int,
              headers: <String, String>{'content-type': 'application/json'},
            );
          });

          expect(
            () => service.exchangeAuthCode(
              code: dummyCode,
              verifier: dummyVerifier,
              client: mockClient,
            ),
            throwsA(isA<ApiException>()
                .having((ApiException e) => e.statusCode, 'statusCode', equals(scenario['status'] as int))
                .having((ApiException e) => e.message, 'message', contains(scenario['expectedMsg'] as String))),
          );
        });
      }
    });

    group('exchangeAuthCode Network, Socket & TLS Failures', () {
      final List<Map<String, dynamic>> networkExceptions = <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'ClientException Socket timeout',
          'exception': http.ClientException('Socket connection timeout'),
        },
        <String, dynamic>{
          'name': 'SocketException Host lookup failure',
          'exception': const SocketException('Failed host lookup: ni-os.ru'),
        },
        <String, dynamic>{
          'name': 'TimeoutException Async operation timeout',
          'exception': TimeoutException('Connection timed out after 10000ms'),
        },
        <String, dynamic>{
          'name': 'HandshakeException TLS negotiation error',
          'exception': const HandshakeException('Handshake error in client (CERTIFICATE_VERIFY_FAILED)'),
        },
        <String, dynamic>{
          'name': 'HttpException Connection closed before full response',
          'exception': const HttpException('Connection closed prematurely by peer'),
        },
      ];

      for (final Map<String, dynamic> netCase in networkExceptions) {
        test('Wraps ${netCase['name']} into ApiException(statusCode: 0)', () async {
          final MockClient mockClient = MockClient((http.Request request) async {
            throw netCase['exception'] as Object;
          });

          expect(
            () => service.exchangeAuthCode(
              code: dummyCode,
              verifier: dummyVerifier,
              client: mockClient,
            ),
            throwsA(isA<ApiException>()
                .having((ApiException e) => e.statusCode, 'statusCode', equals(0))
                .having((ApiException e) => e.message, 'message', contains('Network error during OAuth token exchange'))),
          );
        });
      }
    });

    group('checkCentralNiosIdSession Resilience Matrix', () {
      test('Returns true for 200 OK with valid user object', () async {
        final MockClient client = MockClient((http.Request r) async => http.Response(
              jsonEncode(<String, dynamic>{'status': 'ok', 'user': <String, dynamic>{'id': 1}}),
              200,
            ));
        expect(await service.checkCentralNiosIdSession(client: client), isTrue);
      });

      test('Returns true for 200 OK with empty body or non-JSON', () async {
        final MockClient client = MockClient((http.Request r) async => http.Response('OK', 200));
        expect(await service.checkCentralNiosIdSession(client: client), isTrue);
      });

      test('Returns false ONLY on 401 Unauthorized', () async {
        final MockClient client = MockClient((http.Request r) async => http.Response(
              jsonEncode(<String, dynamic>{'error': 'unauthorized'}),
              401,
            ));
        expect(await service.checkCentralNiosIdSession(client: client), isFalse);
      });

      test('Returns true on 403 Forbidden (does not prematurely drop session on RBAC check)', () async {
        final MockClient client = MockClient((http.Request r) async => http.Response('Forbidden', 403));
        expect(await service.checkCentralNiosIdSession(client: client), isTrue);
      });

      test('Returns true on 500 / 502 / 503 Server Errors (offline / outage resilience)', () async {
        for (final int code in <int>[500, 502, 503, 504]) {
          final MockClient client = MockClient((http.Request r) async => http.Response('Server Error', code));
          expect(await service.checkCentralNiosIdSession(client: client), isTrue, reason: 'Failed for HTTP $code');
        }
      });

      test('Returns true on Network / Socket / Timeout exceptions (offline resilience)', () async {
        final List<Object> exceptions = <Object>[
          http.ClientException('Client exception'),
          const SocketException('No route to host'),
          TimeoutException('Timed out'),
          const HandshakeException('TLS error'),
        ];
        for (final Object ex in exceptions) {
          final MockClient client = MockClient((http.Request r) async => throw ex);
          expect(await service.checkCentralNiosIdSession(client: client), isTrue, reason: 'Failed on $ex');
        }
      });
    });

    group('logoutCentralNiosId Resilience Matrix', () {
      test('Returns true on 200 OK and 204 No Content', () async {
        final MockClient c200 = MockClient((http.Request r) async => http.Response('{"status":"ok"}', 200));
        expect(await service.logoutCentralNiosId(client: c200), isTrue);

        final MockClient c204 = MockClient((http.Request r) async => http.Response('', 204));
        expect(await service.logoutCentralNiosId(client: c204), isTrue);
      });

      test('Returns false on 4xx / 5xx HTTP codes without throwing', () async {
        for (final int code in <int>[400, 401, 403, 404, 500, 502, 503]) {
          final MockClient client = MockClient((http.Request r) async => http.Response('Error', code));
          expect(await service.logoutCentralNiosId(client: client), isFalse, reason: 'Failed for HTTP $code');
        }
      });

      test('Returns false on Network / Socket / Timeout exceptions without throwing', () async {
        final List<Object> exceptions = <Object>[
          http.ClientException('Client exception'),
          const SocketException('Network is unreachable'),
          TimeoutException('Timed out'),
        ];
        for (final Object ex in exceptions) {
          final MockClient client = MockClient((http.Request r) async => throw ex);
          expect(await service.logoutCentralNiosId(client: client), isFalse, reason: 'Failed on $ex');
        }
      });
    });

    group('Auth Models Extreme Boundary & Fuzz Testing', () {
      test('NiosOAuthTokenResponse handles diverse field types for expires_in', () {
        // Integer
        final NiosOAuthTokenResponse r1 = NiosOAuthTokenResponse.fromJson(<String, dynamic>{
          'access_token': 'tok_1',
          'expires_in': 3600,
        });
        expect(r1.expiresIn, equals(3600));

        // String representation of integer
        final NiosOAuthTokenResponse r2 = NiosOAuthTokenResponse.fromJson(<String, dynamic>{
          'access_token': 'tok_2',
          'expires_in': '7200',
        });
        expect(r2.expiresIn, equals(7200));

        // Non-parsable string
        final NiosOAuthTokenResponse r3 = NiosOAuthTokenResponse.fromJson(<String, dynamic>{
          'access_token': 'tok_3',
          'expires_in': 'invalid_seconds',
        });
        expect(r3.expiresIn, isNull);

        // Null value
        final NiosOAuthTokenResponse r4 = NiosOAuthTokenResponse.fromJson(<String, dynamic>{
          'access_token': 'tok_4',
          'expires_in': null,
        });
        expect(r4.expiresIn, isNull);
      });

      test('AuthLoginResult parses various 2FA representation types', () {
        // bool true
        final AuthLoginResult bTrue = AuthLoginResult.fromJson(<String, dynamic>{'two_fa_required': true});
        expect(bTrue.twoFaRequired, isTrue);

        // int 1
        final AuthLoginResult iTrue = AuthLoginResult.fromJson(<String, dynamic>{'two_fa_required': 1});
        expect(iTrue.twoFaRequired, isTrue);

        // String 'true'
        final AuthLoginResult sTrue = AuthLoginResult.fromJson(<String, dynamic>{'two_fa_required': 'true'});
        expect(sTrue.twoFaRequired, isTrue);

        // Alternative key 2fa_required
        final AuthLoginResult altKey1 = AuthLoginResult.fromJson(<String, dynamic>{'2fa_required': true});
        expect(altKey1.twoFaRequired, isTrue);

        // Alternative key twofa_required
        final AuthLoginResult altKey2 = AuthLoginResult.fromJson(<String, dynamic>{'twofa_required': 1});
        expect(altKey2.twoFaRequired, isTrue);

        // False values
        final AuthLoginResult bFalse = AuthLoginResult.fromJson(<String, dynamic>{'two_fa_required': false});
        expect(bFalse.twoFaRequired, isFalse);

        final AuthLoginResult nullFa = AuthLoginResult.fromJson(<String, dynamic>{});
        expect(nullFa.twoFaRequired, isFalse);
      });

      test('AuthSession throws FormatException on null, empty, or whitespace access_token', () {
        expect(() => AuthSession.fromJson(<String, dynamic>{'user_id': 1}), throwsFormatException);
        expect(() => AuthSession.fromJson(<String, dynamic>{'access_token': '', 'user_id': 1}), throwsFormatException);
      });
    });
  });
}
