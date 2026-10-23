import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_io/io.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';

class _RealHttp extends HttpOverrides {}

/// Uses the actual WebSocket transport and AES-GCM wire format, not a mock channel.
class _Server {
  late HttpServer http;
  final peers = <WebSocket>[];
  final requests = <Map<String, dynamic>>[];
  final key = List<int>.generate(32, (i) => i);
  bool handshake = true, pong = true;
  Future<void> Function(WebSocket, Map<String, dynamic>)? handle;
  String get url => 'http://127.0.0.1:${http.port}';

  Future<void> start() async {
    http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    http.listen((request) async {
      final peer = await WebSocketTransformer.upgrade(request);
      peers.add(peer);
      if (handshake) sendKey(peer);
      peer.listen((raw) async {
        final outer = jsonDecode(raw as String) as Map<String, dynamic>;
        if (outer['action'] == 'ping') {
          if (pong) peer.add(jsonEncode({'action': 'pong'}));
          return;
        }
        expect(
          outer['encrypted'],
          true,
          reason: 'Application requests must be encrypted',
        );
        final data = outer['data'] as Map;
        final plain = await AesGcm.with256bits().decrypt(
          SecretBox(
            base64Decode(data['ciphertext'] as String),
            nonce: base64Decode(data['iv'] as String),
            mac: Mac(base64Decode(data['tag'] as String)),
          ),
          secretKey: SecretKey(key),
        );
        final msg =
            jsonDecode(utf8.decode(base64Decode(utf8.decode(plain))))
                as Map<String, dynamic>;
        requests.add(msg);
        await handle?.call(peer, msg);
      });
    });
  }

  void sendKey(WebSocket peer, {List<int>? bytes}) => peer.add(
    jsonEncode({'action': 'key_exchange', 'key': base64Encode(bytes ?? key)}),
  );

  Future<void> send(WebSocket peer, Map<String, dynamic> msg) async {
    final box = await AesGcm.with256bits().encrypt(
      utf8.encode(base64Encode(utf8.encode(jsonEncode(msg)))),
      secretKey: SecretKey(key),
    );
    peer.add(
      jsonEncode({
        'encrypted': true,
        'data': {
          'ciphertext': base64Encode(box.cipherText),
          'iv': base64Encode(box.nonce),
          'tag': base64Encode(box.mac.bytes),
        },
      }),
    );
  }

  Future<void> reply(WebSocket peer, Map<String, dynamic> req) => send(peer, {
    'action': req['action'],
    'request_id': req['request_id'],
    'payload': {'ok': true},
  });

  Future<void> close() async {
    for (final peer in peers) {
      await peer.close();
    }
    await http.close(force: true);
  }
}

Future<void> _until(bool Function() check) async {
  final deadline = DateTime.now().add(const Duration(seconds: 6));
  while (!check()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for transport state');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  Future<void> run(Future<void> Function(_Server) body) =>
      HttpOverrides.runWithHttpOverrides(() async {
        final server = _Server();
        await server.start();
        try {
          await body(server);
        } finally {
          await server.close();
        }
      }, _RealHttp());

  test(
    'concurrent encrypted requests share one handshake; a read timeout leaves other requests alive',
    () => run((s) async {
      final client = WebSocketClient(
        baseUrl: s.url,
        readToken: () => 'account',
      );
      addTearDown(client.close);
      s.handle = (peer, req) async {
        if (req['action'] == 'get_retry' &&
            s.requests.where((r) => r['action'] == 'get_retry').length == 1) {
          return;
        }
        if (req['action'] == 'get_slow') {
          await Future<void>.delayed(const Duration(milliseconds: 350));
        }
        await s.reply(peer, req);
      };
      final results = await Future.wait([
        client.request(
          'get_retry',
          timeout: const Duration(milliseconds: 120),
          maxRetries: 1,
        ),
        client.request('get_slow', timeout: const Duration(seconds: 3)),
        client.request('get_fast'),
      ]);
      expect(results.every((r) => r['ok'] == true), true);
      expect(s.peers.length, 1);
      expect(s.requests.where((r) => r['action'] == 'get_retry').length, 2);
    }),
  );

  test(
    'mutations are never blindly replayed after missing acknowledgement',
    () => run((s) async {
      final client = WebSocketClient(
        baseUrl: s.url,
        readToken: () => 'account',
      );
      addTearDown(client.close);
      await expectLater(
        client.request(
          'send_message',
          timeout: const Duration(milliseconds: 100),
        ),
        throwsA(isA<ApiException>()),
      );
      expect(s.requests.length, 1);
      expect(client.isConnected, true);
    }),
  );

  test(
    'stale handshake cannot replace a new connection after explicit disconnect',
    () => run((s) async {
      s.handshake = false;
      final client = WebSocketClient(
        baseUrl: s.url,
        readToken: () => 'account',
      );
      addTearDown(client.close);
      final old = expectLater(client.connect(), throwsA(isA<ApiException>()));
      await _until(() => s.peers.length == 1);
      client.disconnect();
      s.handshake = true;
      await client.connect();
      await old;
      expect(s.peers.length, 2);
      expect(client.isConnected, true);
      s.handle = s.reply;
      expect((await client.request('get_chats'))['ok'], true);
    }),
  );

  test(
    'invalid handshake key fails closed without sending application data',
    () => run((s) async {
      s.handshake = false;
      final client = WebSocketClient(
        baseUrl: s.url,
        readToken: () => 'account',
      );
      addTearDown(client.close);
      final rejected = expectLater(
        client.request('send_message'),
        throwsA(isA<ApiException>()),
      );
      await _until(() => s.peers.isNotEmpty);
      s.sendKey(s.peers.single, bytes: [1, 2, 3]);
      await rejected;
      expect(s.requests, isEmpty);
      expect(client.isConnected, false);
    }),
  );

  test(
    'large encrypted pushes preserve wire order around small acknowledgements',
    () => run((s) async {
      final client = WebSocketClient(
        baseUrl: s.url,
        readToken: () => 'account',
      );
      addTearDown(client.close);
      final seen = <int>[];
      final sub = client.pushStream.listen((e) => seen.add(e['id'] as int));
      addTearDown(sub.cancel);
      await client.connect();
      s.handle = s.reply;
      await s.send(s.peers.single, {
        'action': 'message',
        'id': 1,
        'content': 'x' * 180000,
      });
      await s.send(s.peers.single, {'action': 'message', 'id': 2});
      expect((await client.request('get_chats'))['ok'], true);
      await _until(() => seen.length == 2);
      expect(seen, [1, 2]);
    }),
  );

  test(
    'background pause suppresses reconnect; foreground probes black holes; closed client stays closed',
    () => run((s) async {
      s.pong = false;
      final client = WebSocketClient(
        baseUrl: s.url,
        readToken: () => 'account',
        heartbeatInterval: const Duration(milliseconds: 40),
        heartbeatTimeout: const Duration(seconds: 5),
        probeTimeout: const Duration(milliseconds: 80),
      );
      addTearDown(client.close);
      await client.connect();
      client.pauseForBackground();
      await Future<void>.delayed(const Duration(milliseconds: 160));
      expect(s.peers.length, 1);
      client.resumeFromBackground();
      await _until(() => s.peers.length == 2);
      client.disconnect();
      client.reconnectNow();
      client.pauseForBackground();
      client.resumeFromBackground();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(s.peers.length, 2);
      client.close();
      await expectLater(client.connect(), throwsA(isA<ApiException>()));
    }),
  );

  test(
    'an account change during handshake never sends the old operation with new credentials',
    () => run((s) async {
      s.handshake = false;
      String token = 'first';
      final client = WebSocketClient(baseUrl: s.url, readToken: () => token);
      addTearDown(client.close);
      final canceled = expectLater(
        client.request('send_message'),
        throwsA(isA<ApiException>()),
      );
      await _until(() => s.peers.isNotEmpty);
      token = 'second';
      s.sendKey(s.peers.single);
      await canceled;
      expect(s.requests, isEmpty);
    }),
  );
}
