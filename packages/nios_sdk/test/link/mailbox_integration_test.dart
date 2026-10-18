import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;
import 'package:nios_sdk/link.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

const _tokenA = 'test-device-a-token-at-least-32-characters';
const _tokenB = 'test-device-b-token-at-least-32-characters';

class _DropFirstPost extends http.BaseClient {
  final http.Client delegate = http.Client();
  bool drop = true;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await delegate.send(request);
    if (drop &&
        request.method == 'POST' &&
        request.url.path == '/v1/messages' &&
        response.statusCode == 200) {
      drop = false;
      await response.stream.drain<void>();
      throw TimeoutException('Simulated lost durable mailbox response');
    }
    return response;
  }

  @override
  void close() => delegate.close();
}

void main() {
  test(
    'real HTTP mailbox survives restart and a lost POST reply without duplicates',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'nios_mailbox_integration_',
      );
      final sessions = <DurableSession>[];
      Process? server;
      final dropClient = _DropFirstPost();
      final adminClient = http.Client();
      final journalKey = List<int>.generate(32, (i) => i + 1);
      final sharedKey = SecretKey(List.filled(32, 71));
      try {
        Future<Uri> start() async {
          server = await Process.start(
            Platform.resolvedExecutable,
            ['run', 'example/mailbox_server.dart'],
            environment: {
              'NIOS_MAILBOX_KEY': base64Encode(journalKey),
              'NIOS_MAILBOX_TOKENS': jsonEncode({'a': _tokenA, 'b': _tokenB}),
              'NIOS_MAILBOX_DIRECTORY': '${directory.path}/server',
            },
          );
          final errors = <String>[];
          server!.stderr.transform(utf8.decoder).listen(errors.add);
          final first = await server!.stdout
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .first
              .timeout(
                const Duration(seconds: 30),
                onTimeout: () =>
                    throw StateError('Mailbox startup failed: $errors'),
              );
          final metadata = jsonDecode(first) as Map;
          return Uri.parse('http://127.0.0.1:${metadata['port']}');
        }

        Future<DurableSession> open(
          String device,
          Uri endpoint, {
          http.Client? client,
        }) async {
          final session = await DurableSession.open(
            directory: '${directory.path}/clients',
            accountId: 'integration',
            deviceId: device,
            journalKey: journalKey,
            cipher: AesGcmEnvelopeCipher(
              deviceId: device,
              keyForPeer: (_) async => sharedKey,
            ),
            transports: [
              HttpMailboxTransport(
                baseUri: endpoint,
                deviceId: device,
                bearerToken: device == 'a' ? _tokenA : _tokenB,
                allowInsecureLoopback: true,
                client: client,
              ),
            ],
            reducer: (state, operation) => {
              'count': (state['count'] as int? ?? 0) + 1,
              'value': operation.payload['value'],
            },
            autoStart: false,
          );
          sessions.add(session);
          return session;
        }

        var endpoint = await start();
        var a = await open('a', endpoint, client: dropClient);
        final saved = await a.enqueue(
          peerId: 'b',
          sessionId: 'session',
          payload: {'value': 'opaque secret'},
          operationId: 'stable',
        );
        await a.pump();
        expect(a.operation('stable')!.facts, {DeliveryFact.localDurable});
        await a.close();
        server!.kill(ProcessSignal.sigkill);
        await server!.exitCode;
        endpoint = await start();
        a = await open('a', endpoint);
        await a.retryNow('stable');
        expect(a.operation('stable')!.facts, {
          DeliveryFact.localDurable,
          DeliveryFact.mailboxStored,
        });
        expect(a.operation('stable')!.envelope.digest, saved.envelope.digest);
        final inbox = await adminClient.get(
          endpoint.resolve('/v1/inbox'),
          headers: {'authorization': 'Bearer $_tokenB'},
        );
        expect(inbox.statusCode, 200);
        final items = (jsonDecode(inbox.body) as Map)['envelopes'] as List;
        expect(items.length, 1);
        expect(inbox.body, isNot(contains('opaque secret')));
        final unauthenticated = await adminClient.get(
          endpoint.resolve('/v1/inbox'),
        );
        expect(unauthenticated.statusCode, 401);
        final spoof = await adminClient.post(
          endpoint.resolve('/v1/messages'),
          headers: {
            'authorization': 'Bearer $_tokenB',
            'content-type': 'application/json',
          },
          body: jsonEncode(saved.envelope.toJson()),
        );
        expect(spoof.statusCode, 403);
        final b = await open('b', endpoint);
        await b.pump();
        expect(b.applicationState(peerId: 'a', sessionId: 'session'), {
          'count': 1,
          'value': 'opaque secret',
        });
        await a.pump();
        expect(a.operation('stable')!.facts, {
          DeliveryFact.localDurable,
          DeliveryFact.mailboxStored,
          DeliveryFact.recipientStored,
          DeliveryFact.recipientApplied,
        });
        await b.pump();
        expect(
          b.applicationState(peerId: 'a', sessionId: 'session')['count'],
          1,
        );

        final uploader = HttpMailboxTransport(
          baseUri: endpoint,
          deviceId: 'a',
          bearerToken: _tokenA,
          allowInsecureLoopback: true,
        );
        final downloader = HttpMailboxTransport(
          baseUri: endpoint,
          deviceId: 'b',
          bearerToken: _tokenB,
          allowInsecureLoopback: true,
        );
        try {
          final cipher = AesGcmEnvelopeCipher(
            deviceId: 'a',
            keyForPeer: (_) async => sharedKey,
          );
          final expected = <String>{};
          // Exercise the real server's >100-envelope pagination, rather than a
          // fake transport which can accidentally discard the remaining page.
          for (var i = 0; i < 101; i++) {
            final envelope = await cipher.seal(
              EnvelopeContext(
                senderId: 'a',
                recipientId: 'b',
                sessionId: 'pagination',
                operationId: 'page-$i',
                sequence: i + 1,
              ),
              utf8.encode(jsonEncode({'value': i})),
            );
            expected.add(envelope.digest);
            await uploader.deliver(envelope);
          }
          final firstPage = await downloader.poll('b');
          final secondPage = await downloader.poll('b');
          expect(firstPage.length, 100);
          expect(secondPage.length, 1);
          expect({
            ...firstPage.map((envelope) => envelope.digest),
            ...secondPage.map((envelope) => envelope.digest),
          }, expected);
          await expectLater(
            uploader.confirmReceived(firstPage.first),
            throwsA(
              isA<LinkTransportException>().having(
                (error) => error.code,
                'code',
                'http_403',
              ),
            ),
          );
          for (final envelope in [...firstPage, ...secondPage]) {
            await downloader.confirmReceived(envelope);
          }
          expect(await downloader.poll('b'), isEmpty);
        } finally {
          await uploader.close();
          await downloader.close();
        }

        // Keep an authenticated HTTP request alive with bytes inside every
        // idle-timeout window. The server must still enforce its total budget.
        final slow = await Socket.connect(endpoint.host, endpoint.port);
        final deadlineClock = Stopwatch()..start();
        Timer? trickle;
        try {
          final status = slow
              .cast<List<int>>()
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .first
              .timeout(const Duration(seconds: 15));
          slow.write(
            'POST /v1/messages HTTP/1.1\r\n'
            'Host: ${endpoint.host}:${endpoint.port}\r\n'
            'Authorization: Bearer $_tokenA\r\n'
            'Content-Type: application/json\r\n'
            'Content-Length: 500\r\n'
            'Connection: close\r\n\r\n{',
          );
          await slow.flush();
          trickle = Timer.periodic(const Duration(seconds: 2), (_) {
            try {
              slow.write(' ');
              unawaited(slow.flush().catchError((Object _) {}));
            } catch (_) {
              trickle?.cancel();
            }
          });
          // Cancelling an unread HttpRequest body at its deadline can end TCP
          // with EOF or ECONNRESET before an HTTP 408 is written. Accept only
          // that specific socket error; the deadline and recovery checks below
          // still reject premature disconnects and a blocked mailbox queue.
          final result = await status.then(
            (line) => line,
            onError: (Object error, StackTrace stack) {
              if (error is StateError && error.message == 'No element') {
                return 'body_connection_closed';
              }
              if (error is SocketException &&
                  const {104, 54, 10054}.contains(error.osError?.errorCode)) {
                // Linux, macOS/BSD, and Windows ECONNRESET, respectively.
                return 'body_connection_reset';
              }
              Error.throwWithStackTrace(error, stack);
            },
          );
          expect(
            result,
            anyOf(
              startsWith('HTTP/1.1 408'),
              'body_connection_closed',
              'body_connection_reset',
            ),
          );
          expect(
            deadlineClock.elapsed,
            greaterThan(const Duration(seconds: 8)),
          );
          expect(deadlineClock.elapsed, lessThan(const Duration(seconds: 15)));
          trickle.cancel();
          final recovered = await adminClient
              .get(
                endpoint.resolve('/v1/inbox'),
                headers: {'authorization': 'Bearer $_tokenB'},
              )
              .timeout(const Duration(seconds: 3));
          expect(recovered.statusCode, 200);
        } finally {
          trickle?.cancel();
          slow.destroy();
        }
      } finally {
        for (final session in sessions.reversed) {
          if (!session.isClosed) await session.close();
        }
        server?.kill(ProcessSignal.sigkill);
        if (server != null) await server!.exitCode;
        dropClient.close();
        adminClient.close();
        await directory.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
