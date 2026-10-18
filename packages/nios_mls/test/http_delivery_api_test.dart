import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:nios_mls/nios_mls.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  final group = Uint8List.fromList([1, 2, 3]);
  Matcher code(String value) =>
      isA<NiosMlsException>().having((e) => e.code, 'code', value);

  test('remote HTTP, path prefixes and header injection are rejected', () {
    for (final origin in [
      'http://example.com',
      'https://example.com/subpath/',
      'https://user@example.com',
      'https://example.com?token=no',
    ]) {
      expect(
        () => HttpMlsDeliveryApi(
          baseUri: Uri.parse(origin),
          deviceId: 'alice',
          bearerToken: 'token',
          allowInsecureLoopback: true,
        ),
        throwsArgumentError,
      );
    }
    expect(
      () => HttpMlsDeliveryApi(
        baseUri: Uri.parse('https://example.com'),
        deviceId: 'alice',
        bearerToken: 'token\r\nInjected: yes',
      ),
      throwsArgumentError,
    );
  });

  test(
    'redirect never forwards the device credential to another server',
    () async {
      final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final target = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var targetHits = 0;
      target.listen((request) async {
        targetHits++;
        await request.response.close();
      });
      origin.listen((request) async {
        request.response.statusCode = HttpStatus.found;
        request.response.headers.set(
          HttpHeaders.locationHeader,
          'http://127.0.0.1:${target.port}/leak',
        );
        await request.response.close();
      });
      final api = HttpMlsDeliveryApi(
        baseUri: Uri.parse('http://127.0.0.1:${origin.port}'),
        deviceId: 'alice',
        bearerToken: 'private-device-token',
        allowInsecureLoopback: true,
      );
      try {
        await expectLater(
          api.groupHead(group),
          throwsA(code('mls_http_redirect_rejected')),
        );
        expect(targetHits, 0);
      } finally {
        await api.close();
        await origin.close(force: true);
        await target.close(force: true);
      }
    },
  );

  test(
    'absolute response timeout and close abort an active socket request',
    () async {
      final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final received = StreamController<void>.broadcast();
      final responses = <HttpResponse>[];
      origin.listen((request) {
        responses.add(request.response);
        received.add(null);
      });
      final timeoutApi = HttpMlsDeliveryApi(
        baseUri: Uri.parse('http://127.0.0.1:${origin.port}'),
        deviceId: 'alice',
        bearerToken: 'token',
        allowInsecureLoopback: true,
        timeout: const Duration(milliseconds: 80),
      );
      final closeApi = HttpMlsDeliveryApi(
        baseUri: Uri.parse('http://127.0.0.1:${origin.port}'),
        deviceId: 'alice',
        bearerToken: 'token',
        allowInsecureLoopback: true,
      );
      try {
        await expectLater(
          timeoutApi.groupHead(group),
          throwsA(code('mls_http_timeout')),
        );
        final next = received.stream.first;
        final pending = closeApi.groupHead(group);
        final failed = expectLater(pending, throwsA(anything));
        await next;
        await closeApi.close();
        await failed.timeout(const Duration(seconds: 2));
        await expectLater(
          closeApi.groupHead(group),
          throwsA(code('mls_http_closed')),
        );
      } finally {
        await timeoutApi.close();
        await closeApi.close();
        for (final response in responses) {
          unawaited(response.close().catchError((Object _) {}));
        }
        await origin.close(force: true);
        await received.close();
      }
    },
  );

  test('bounded response and exact requested group are validated', () async {
    final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var oversized = true;
    origin.listen((request) async {
      if (oversized) {
        request.response.contentLength = 65537;
        request.response.add(List.filled(65537, 32));
      } else {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'group_id': mlsServerGroupId([9, 9]),
            'epoch': 0,
            'head': List.filled(64, 'a').join(),
            'coordinator': 'alice',
          }),
        );
      }
      await request.response.close().catchError((Object _) {});
    });
    final api = HttpMlsDeliveryApi(
      baseUri: Uri.parse('http://127.0.0.1:${origin.port}'),
      deviceId: 'alice',
      bearerToken: 'token',
      allowInsecureLoopback: true,
    );
    try {
      await expectLater(
        api.groupHead(group),
        throwsA(code('mls_http_response_too_large')),
      );
      oversized = false;
      await expectLater(
        api.groupHead(group),
        throwsA(code('mls_group_response_mismatch')),
      );
      await expectLater(
        api.ensureApplicationDeliveryAllowed(
          groupId: group,
          epoch: BigInt.one << 100,
          recipientDeviceIds: ['bob'],
        ),
        throwsA(code('mls_epoch_outside_wire_range')),
      );
    } finally {
      await api.close();
      await origin.close(force: true);
    }
  });
}
