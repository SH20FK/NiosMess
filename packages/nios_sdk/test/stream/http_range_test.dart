import 'dart:async';
import 'dart:typed_data';

import 'package:nios_sdk/stream.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  late HttpServer server;
  late List<int> content;
  late Uri uri;
  late void Function(HttpRequest) handler;

  setUp(() async {
    content = List.generate(4096, (index) => index % 251);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    uri = Uri.parse('http://127.0.0.1:${server.port}/content');
    handler = (request) {
      expect(request.headers.value('range'), 'bytes=100-199');
      request.response
        ..statusCode = 206
        ..headers.set('content-range', 'bytes 100-199/${content.length}')
        ..contentLength = 100
        ..add(content.sublist(100, 200));
      unawaited(request.response.close());
    };
    server.listen((request) => handler(request));
  });
  tearDown(() async => server.close(force: true));

  HttpRangeCiphertextSource source() => HttpRangeCiphertextSource(
    uri: uri,
    totalLength: content.length,
    timeout: const Duration(seconds: 2),
    allowInsecureLoopback: true,
  );

  test(
    'real HTTP source requires exact 206 range and identity encoding',
    () async {
      expect(await source().readRange(100, 200), content.sublist(100, 200));
    },
  );

  test('a server ignoring Range cannot cause full-file buffering', () async {
    handler = (request) {
      request.response
        ..statusCode = 200
        ..contentLength = content.length
        ..add(content);
      unawaited(request.response.close());
    };
    await expectLater(source().readRange(100, 200), throwsFormatException);
  });

  test('mismatched content-range is rejected', () async {
    handler = (request) {
      request.response
        ..statusCode = 206
        ..headers.set('content-range', 'bytes 99-198/${content.length}')
        ..add(content.sublist(100, 200));
      unawaited(request.response.close());
    };
    await expectLater(source().readRange(100, 200), throwsFormatException);
  });

  test('oversized chunked body is stopped at the requested bound', () async {
    handler = (request) {
      request.response
        ..statusCode = 206
        ..headers.set('content-range', 'bytes 100-199/${content.length}')
        ..add(Uint8List(101));
      unawaited(request.response.close());
    };
    await expectLater(source().readRange(100, 200), throwsFormatException);
  });

  test('truncated chunked body is rejected', () async {
    handler = (request) {
      request.response
        ..statusCode = 206
        ..headers.set('content-range', 'bytes 100-199/${content.length}')
        ..add(Uint8List(99));
      unawaited(request.response.close());
    };
    await expectLater(source().readRange(100, 200), throwsFormatException);
  });

  test(
    'cancellation closes an in-flight HTTP request before headers',
    () async {
      final arrived = Completer<void>();
      handler = (request) => arrived.complete();
      final token = StreamCancellation();
      final pending = source().readRange(100, 200, cancellation: token);
      final assertion = expectLater(
        pending,
        throwsA(isA<StreamCancelledException>()),
      );
      await arrived.future;
      token.cancel();
      await assertion.timeout(const Duration(seconds: 1));
    },
  );

  test(
    'cancellation closes a response stalled after partial authenticated-range bytes',
    () async {
      final arrived = Completer<void>();
      handler = (request) {
        request.response
          ..statusCode = 206
          ..headers.set('content-range', 'bytes 100-199/${content.length}')
          ..contentLength = 100
          ..add(Uint8List(10));
        unawaited(request.response.flush().then((_) => arrived.complete()));
      };
      final cancellation = StreamCancellation();
      final assertion = expectLater(
        source().readRange(100, 200, cancellation: cancellation),
        throwsA(isA<StreamCancelledException>()),
      );
      await arrived.future.timeout(const Duration(seconds: 2));
      cancellation.cancel();
      await assertion.timeout(const Duration(seconds: 1));
    },
  );

  test(
    'HTTP range allocation limits are checked before opening socket',
    () async {
      await expectLater(
        source().readRange(0, 2 * 1024 * 1024),
        throwsRangeError,
      );
      await expectLater(source().readRange(-1, 2), throwsRangeError);
      await expectLater(source().readRange(4000, 5000), throwsRangeError);
    },
  );
}
