import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nios_sdk/link.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  for (final closeTransport in [true, false]) {
    test(
      closeTransport
          ? 'close aborts a live response without closing the injected client'
          : 'total timeout aborts a continuously streamed response',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final client = http.Client();
        final started = Completer<void>();
        final release = Completer<void>();
        final handlers = <Future<void>>[];
        final subscription = server.listen((request) {
          handlers.add(() async {
            try {
              request.response.headers.contentType = ContentType.json;
              if (request.uri.path == '/probe') {
                request.response.write('{}');
                await request.response.close();
                return;
              }
              request.response.write('{"envelopes":');
              await request.response.flush();
              if (!started.isCompleted) started.complete();
              if (closeTransport) {
                await release.future;
              } else {
                // Each chunk arrives within the idle timeout. The request must
                // nevertheless be cancelled at the absolute transport deadline.
                for (var i = 0; i < 40 && !release.isCompleted; i++) {
                  await Future<void>.delayed(const Duration(milliseconds: 50));
                  request.response.write(' ');
                  await request.response.flush();
                }
              }
              request.response.write('[],"next":null}');
              await request.response.close();
            } catch (_) {
              // Cancellation is the expected path for the held HTTP response.
            }
          }());
        });
        final endpoint = Uri.parse('http://127.0.0.1:${server.port}');
        final transport = HttpMailboxTransport(
          baseUri: endpoint,
          deviceId: 'a',
          bearerToken: 'local-test-token',
          client: client,
          timeout: const Duration(milliseconds: 750),
          allowInsecureLoopback: true,
        );
        try {
          final polled = transport.poll('a');
          final rejected = expectLater(
            polled,
            throwsA(
              anyOf(
                isA<http.RequestAbortedException>(),
                isA<TimeoutException>(),
              ),
            ),
          );
          await started.future.timeout(const Duration(seconds: 5));
          if (closeTransport) await transport.close();
          await rejected.timeout(const Duration(seconds: 3));
          expect(
            (await client.get(endpoint.resolve('/probe'))).statusCode,
            200,
          );
        } finally {
          await transport.close();
          if (!release.isCompleted) release.complete();
          client.close();
          await server.close(force: true);
          await subscription.cancel();
          await Future.wait(handlers);
        }
      },
    );
  }

  test('malformed inbox page cannot advance its cursor', () async {
    final requests = <Uri>[];
    var first = true;
    final cursor = '1' * 64;
    final context = const EnvelopeContext(
      senderId: 'b',
      recipientId: 'a',
      sessionId: 'test',
      operationId: 'queued',
      sequence: 1,
    );
    final valid = EncryptedEnvelope(
      context: context,
      nonce: List.filled(12, 0),
      ciphertext: [],
      mac: List.filled(16, 0),
    );
    final client = MockClient((request) async {
      requests.add(request.url);
      final envelope = valid.toJson();
      if (first) {
        first = false;
        envelope['mac'] = '';
      }
      return http.Response(
        jsonEncode({
          'envelopes': [envelope],
          'next': cursor,
        }),
        200,
      );
    });
    final transport = HttpMailboxTransport(
      baseUri: Uri.parse('https://mailbox.invalid'),
      deviceId: 'a',
      bearerToken: 'test-token',
      client: client,
    );
    try {
      await expectLater(transport.poll('a'), throwsFormatException);
      expect((await transport.poll('a')).single.digest, valid.digest);
      await transport.poll('a');
      expect(requests[0].queryParameters, isEmpty);
      expect(requests[1].queryParameters, isEmpty);
      expect(requests[2].queryParameters, {'after': cursor});
    } finally {
      await transport.close();
      client.close();
    }
  });

  test('ACK publishing requires a matching durable mailbox receipt', () async {
    final acknowledgement = EncryptedEnvelope(
      context: const EnvelopeContext(
        senderId: 'a',
        recipientId: 'b',
        sessionId: 'test',
        operationId: 'queued',
        sequence: 1,
        kind: 'ack',
      ),
      nonce: List.filled(12, 0),
      ciphertext: [],
      mac: List.filled(16, 0),
    );
    final responses = <Map<String, dynamic>>[
      {'stored': false, 'digest': acknowledgement.digest},
      {'stored': true, 'digest': '0' * 64},
      {'stored': true, 'digest': acknowledgement.digest},
    ];
    final client = MockClient((_) async {
      return http.Response(jsonEncode(responses.removeAt(0)), 200);
    });
    final transport = HttpMailboxTransport(
      baseUri: Uri.parse('https://mailbox.invalid'),
      deviceId: 'a',
      bearerToken: 'test-token',
      client: client,
    );
    try {
      for (var i = 0; i < 2; i++) {
        await expectLater(
          transport.publishAcknowledgement(acknowledgement),
          throwsA(
            isA<LinkTransportException>().having(
              (error) => error.code,
              'code',
              'invalid_mailbox_receipt',
            ),
          ),
        );
      }
      await transport.publishAcknowledgement(acknowledgement);
    } finally {
      await transport.close();
      client.close();
    }
  });
}
