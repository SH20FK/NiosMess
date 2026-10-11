import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:universal_io/io.dart';
import 'package:pulse_flutter/services/calls/webrtc_signaling_client.dart';

class _RealHttp extends HttpOverrides {}

Future<bool> _connect(WebRtcSignalingClient client) =>
    HttpOverrides.runWithHttpOverrides(client.connect, _RealHttp());

void main() {
  late HttpServer server;
  final sockets = <WebSocket>[];

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  });
  tearDown(() async {
    for (final socket in sockets) {
      await socket.close();
    }
    sockets.clear();
    await server.close(force: true);
  });

  String url([String query = '']) =>
      'ws://127.0.0.1:${server.port}/signal$query';

  test('authenticates the upgrade, waits for ready, and sends leave', () async {
    final requestSeen = Completer<Uri>();
    final accepted = Completer<WebSocket>();
    final frames = <Map<String, dynamic>>[];
    final left = Completer<void>();
    server.listen((request) async {
      requestSeen.complete(request.uri);
      if (request.uri.queryParameters['token'] != 'a+b/= signed.token') {
        request.response.statusCode = 403;
        await request.response.close();
        return;
      }
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((raw) {
        final frame = jsonDecode(raw as String) as Map<String, dynamic>;
        frames.add(frame);
        if (frame['type'] == 'leave') left.complete();
      });
      accepted.complete(socket);
    });
    final client = WebRtcSignalingClient(
      signalUrl: url('?existing=keep&token=stale'),
      token: 'a+b/= signed.token',
    );
    addTearDown(client.disconnect);
    final messages = <Map<String, dynamic>>[];
    final subscription = client.onMessage.listen(messages.add);
    final readyMessage = client.onMessage.first;
    addTearDown(subscription.cancel);
    var completed = false;
    final connection = _connect(client).then((value) {
      completed = true;
      return value;
    });
    final socket = await accepted.future;
    final request = await requestSeen.future;
    expect(request.queryParameters['existing'], 'keep');
    expect(request.queryParameters['token'], 'a+b/= signed.token');
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse, reason: 'An upgrade is not a gateway ready ACK');
    socket.add(jsonEncode({'type': 'ready', 'user_id': 7, 'peers': []}));
    expect(await connection, isTrue);
    await readyMessage;
    expect(client.localUserId, 7);
    expect(messages.single['type'], 'ready');
    client.sendMediaState(targetId: 9, audio: true, video: false);
    await client.disconnect();
    await left.future.timeout(const Duration(seconds: 2));
    expect(frames.map((f) => f['type']), ['media_state', 'leave']);
    expect(frames.first['target_id'], 9);
    expect(frames.any((f) => f.containsKey('token')), isFalse);
  });

  test('rejected authentication returns false and does not leak token', () async {
    server.listen((request) async {
      request.response.statusCode = 403;
      await request.response.close();
    });
    final client = WebRtcSignalingClient(signalUrl: url(), token: 'invalid');
    addTearDown(client.disconnect);
    expect(await _connect(client), isFalse);
    expect(client.isConnected, isFalse);
  });

  test('closing before ready never reports a connected call', () async {
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      await socket.close();
    });
    final client = WebRtcSignalingClient(signalUrl: url(), token: 'fixture');
    addTearDown(client.disconnect);
    expect(await _connect(client), isFalse);
    expect(client.isConnected, isFalse);
  });
}
