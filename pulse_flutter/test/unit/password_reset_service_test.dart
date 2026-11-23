import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pulse_flutter/core/network/api_constants.dart';
import 'package:pulse_flutter/services/password_reset_service.dart';

void main() {
  const PasswordResetService service = PasswordResetService();

  /// A client that answers exactly what the Nios ID endpoints answer:
  /// `202` with a small body on request, `204` with none on reset.
  http.Client answeringClient({
    int requestCode = 202,
    int resetCode = 204,
    Object? requestError,
  }) => MockClient((http.Request request) async {
    if (requestError != null) {
      throw requestError;
    }
    final bool isRequest = request.url.toString() ==
        ApiConstants.passwordRequestUrl;
    expect(request.method, equals('POST'));
    expect(
      request.headers['content-type'],
      contains('application/json'),
    );
    // The request bodies must be well-formed JSON, not hand-escaped strings.
    final Map<String, dynamic> body =
        jsonDecode(request.body) as Map<String, dynamic>;
    if (isRequest) {
      expect(body.keys, containsAll(<String>['email']));
      return http.Response(
        requestCode == 202 ? '{"status":"accepted"}' : '',
        requestCode,
      );
    }
    expect(body.keys, containsAll(<String>['email', 'code', 'new_password']));
    return http.Response('', resetCode);
  });

  group('PasswordResetService.requestCode', () {
    test('returns quietly on 202 with a body', () async {
      await service.requestCode(
        'user@example.com',
        client: answeringClient(),
      );
    });

    test('a 204-style empty body is never parsed', () async {
      // The endpoint is documented as 202, but an empty body anywhere on this
      // path must not crash the caller.
      await service.requestCode(
        'user@example.com',
        client: answeringClient(requestCode: 204),
      );
    });

    test('maps 429 to tooManyRequests', () async {
      await expectLater(
        service.requestCode('user@example.com', client: answeringClient(requestCode: 429)),
        throwsA(
          isA<PasswordResetException>().having(
            (PasswordResetException e) => e.kind,
            'kind',
            PasswordResetFailureKind.tooManyRequests,
          ),
        ),
      );
    });

    test('maps anything unexpected to unknown', () async {
      await expectLater(
        service.requestCode('user@example.com', client: answeringClient(requestCode: 500)),
        throwsA(
          isA<PasswordResetException>().having(
            (PasswordResetException e) => e.kind,
            'kind',
            PasswordResetFailureKind.unknown,
          ),
        ),
      );
    });

    test('a network failure becomes network', () async {
      await expectLater(
        service.requestCode(
          'user@example.com',
          client: answeringClient(requestError: http.ClientException('boom')),
        ),
        throwsA(
          isA<PasswordResetException>().having(
            (PasswordResetException e) => e.kind,
            'kind',
            PasswordResetFailureKind.network,
          ),
        ),
      );
    });

    test('a malformed response body still reports the status', () async {
      // 422 on request is not a documented combination, but the client must
      // not trust the body either way: the status is the whole truth.
      await expectLater(
        service.requestCode('user@example.com', client: answeringClient(requestCode: 422)),
        throwsA(
          isA<PasswordResetException>().having(
            (PasswordResetException e) => e.kind,
            'kind',
            PasswordResetFailureKind.weakPassword,
          ),
        ),
      );
    });
  });

  group('PasswordResetService.reset', () {
    test('returns quietly on 204 with no body', () async {
      await service.reset(
        email: 'user@example.com',
        code: '123456',
        newPassword: 'Longpass1',
        client: answeringClient(),
      );
    });

    test('escapes the fields into one JSON object', () async {
      String? seenBody;
      final http.Client client = MockClient((http.Request request) async {
        seenBody = request.body;
        return http.Response('', 204);
      });
      await service.reset(
        email: 'a"b@example.com',
        code: '123456',
        newPassword: 'Pass"word1',
        client: client,
      );
      final Map<String, dynamic> body =
          jsonDecode(seenBody!) as Map<String, dynamic>;
      expect(body['email'], equals('a"b@example.com'));
      expect(body['new_password'], equals('Pass"word1'));
    });

    test('maps 422 to weakPassword', () async {
      await expectLater(
        service.reset(
          email: 'user@example.com',
          code: '123456',
          newPassword: 'short',
          client: answeringClient(resetCode: 422),
        ),
        throwsA(
          isA<PasswordResetException>().having(
            (PasswordResetException e) => e.kind,
            'kind',
            PasswordResetFailureKind.weakPassword,
          ),
        ),
      );
    });

    test('maps 400 and 401 to invalidCode', () async {
      for (final int status in <int>[400, 401]) {
        await expectLater(
          service.reset(
            email: 'user@example.com',
            code: '000000',
            newPassword: 'Longpass1',
            client: answeringClient(resetCode: status),
          ),
          throwsA(
            isA<PasswordResetException>().having(
              (PasswordResetException e) => e.kind,
              'kind',
              PasswordResetFailureKind.invalidCode,
            ),
          ),
          reason: 'HTTP $status',
        );
      }
    });

    test('maps 429 to tooManyRequests', () async {
      await expectLater(
        service.reset(
          email: 'user@example.com',
          code: '123456',
          newPassword: 'Longpass1',
          client: answeringClient(resetCode: 429),
        ),
        throwsA(
          isA<PasswordResetException>().having(
            (PasswordResetException e) => e.kind,
            'kind',
            PasswordResetFailureKind.tooManyRequests,
          ),
        ),
      );
    });

    test('a network failure becomes network', () async {
      await expectLater(
        service.reset(
          email: 'user@example.com',
          code: '123456',
          newPassword: 'Longpass1',
          client: answeringClient(requestError: http.ClientException('boom')),
        ),
        throwsA(
          isA<PasswordResetException>().having(
            (PasswordResetException e) => e.kind,
            'kind',
            PasswordResetFailureKind.network,
          ),
        ),
      );
    });

    test('an unexpected status becomes unknown, body untouched', () async {
      await expectLater(
        service.reset(
          email: 'user@example.com',
          code: '123456',
          newPassword: 'Longpass1',
          client: answeringClient(resetCode: 502),
        ),
        throwsA(
          isA<PasswordResetException>().having(
            (PasswordResetException e) => e.kind,
            'kind',
            PasswordResetFailureKind.unknown,
          ),
        ),
      );
    });
  });
}
