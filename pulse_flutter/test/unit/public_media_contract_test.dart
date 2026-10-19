import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/services/public_media_upload_service.dart';

void main() {
  test('nested NiosGram author, identity and date survive a cold parse', () {
    final message = ApiMessage.fromJson({
      'id': 35,
      'content': 'A comment',
      'created_at': '2026-10-19T12:00:00Z',
      'author': {
        'id': 7,
        'username': 'tester',
        'display_name': 'Tester',
        'avatar_url': '/static/avatars/example.jpg',
      },
    });
    expect(message.senderId, 7);
    expect(message.senderUsername, 'tester');
    expect(message.senderDisplayName, 'Tester');
    expect(message.sentAt.toUtc(), DateTime.utc(2026, 10, 19, 12));
    expect(message.senderAvatarUrl, '/static/avatars/example.jpg');
  });

  test(
    'empty display name falls back to username and sender ID stays authoritative',
    () {
      final message = ApiMessage.fromJson({
        'id': 1,
        'sender_id': 9,
        'sender_username': 'actual',
        'sender_display_name': ' ',
        'author': {'id': 7, 'username': 'other', 'display_name': 'Other'},
      });
      expect(message.senderId, 9);
      expect(message.senderUsername, 'actual');
      expect(message.senderDisplayName, 'actual');
      expect(ApiMessage.fromJson({'author_id': 12}).senderId, 12);
    },
  );

  test(
    'large sticker upload transmits binary multipart bytes and drains response',
    () async {
      final bytes = Uint8List.fromList(
        List<int>.generate(5 * 1024 * 1024, (i) => i % 256),
      );
      late http.Request sent;
      final client = MockClient((request) async {
        sent = request;
        return http.Response(
          '{"upload_id":"0123456789abcdef0123456789abcdef"}',
          200,
        );
      });
      final service = PublicMediaUploadService(
        client,
        () => 'synthetic-session',
      );
      final id = await service.upload(bytes, filename: 'fixture.mp4');
      expect(id, '0123456789abcdef0123456789abcdef');
      expect(sent.url.path, '/api/files/upload');
      expect(sent.headers['content-type'], startsWith('multipart/form-data'));
      expect(sent.bodyBytes.length, lessThan(bytes.length + 2048));
      expect(sent.bodyBytes, containsAllInOrder(bytes.take(256)));
      client.close();
    },
  );

  test(
    'missing authentication fails locally and server error body stays private',
    () async {
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        return http.Response('synthetic-secret-do-not-display', 500);
      });
      final bytes = Uint8List.fromList([1, 2]);
      await expectLater(
        PublicMediaUploadService(
          client,
          () => null,
        ).upload(bytes, filename: 'a.png'),
        throwsA(isA<ApiException>()),
      );
      expect(requests, 0);
      await expectLater(
        PublicMediaUploadService(
          client,
          () => 'token',
        ).upload(bytes, filename: 'a.png'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            isNot(contains('synthetic-secret')),
          ),
        ),
      );
      client.close();
    },
  );
}
