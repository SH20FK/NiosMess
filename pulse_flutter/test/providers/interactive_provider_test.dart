import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/interactive_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_service.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState.initial().copyWith(
    session: const AuthSession(
      accessToken: 'fixture',
      userId: 2,
      username: 'fixture',
      displayName: 'Саша',
    ),
  );
}

class _Socket extends WebSocketClient {
  _Socket(this.reply)
    : super(baseUrl: 'https://fixture.invalid', readToken: () => 'fixture');
  final Future<dynamic> Function(Map<String, dynamic>) reply;
  final pushes = StreamController<Map<String, dynamic>>.broadcast();
  final connections = StreamController<void>.broadcast();
  final calls = <Map<String, dynamic>>[];
  @override
  Stream<Map<String, dynamic>> get pushStream => pushes.stream;
  @override
  Stream<void> get onConnected => connections.stream;
  @override
  Future<dynamic> request(
    String action, {
    Map<String, dynamic>? payload,
    Duration timeout = const Duration(seconds: 15),
    int maxRetries = 2,
  }) async {
    expect(action, 'message_replies');
    calls.add(Map.from(payload!));
    return reply(payload);
  }
}

Map<String, dynamic> row(int id, {int root = 10, bool encrypted = false}) => {
  'id': id,
  'chat_id': 1,
  'reply_to_id': root,
  'sender_id': 3,
  'content': encrypted ? '' : 'Событие',
  'is_e2ee': encrypted,
  if (encrypted) 'e2ee_content': 'opaque',
};
ProviderContainer _fixture(_Socket socket) {
  final container = ProviderContainer(
    overrides: [
      authProvider.overrideWith(_Auth.new),
      webSocketClientProvider.overrideWithValue(socket),
      ordinaryE2eeProvider.overrideWithValue(null),
    ],
  );
  final subscription = container.listen(
    interactiveEventsProvider((2, 1, 10)),
    (_, _) {},
  );
  addTearDown(() async {
    subscription.close();
    container.dispose();
    await socket.pushes.close();
    await socket.connections.close();
    socket.close();
  });
  return container;
}

void main() {
  test(
    'loads beyond visible history, refreshes after committed changes and reconnect',
    () async {
      var version = 0;
      final socket = _Socket((payload) async {
        if (version > 0) {
          return {
            'messages': [row(11)],
            'has_more': false,
          };
        }
        return payload['after_id'] == 0
            ? {
                'messages': [row(11)],
                'has_more': true,
                'next_cursor': 11,
              }
            : {
                'messages': [row(12)],
                'has_more': false,
              };
      });
      final container = _fixture(socket);
      expect(
        (await container.read(
          interactiveEventsProvider((2, 1, 10)).future,
        )).map((m) => m.id),
        [11, 12],
      );
      expect(socket.calls.map((p) => p['after_id']), [0, 11]);
      version = 1;
      socket.pushes.add({
        'action': 'interactive_changed',
        'payload': {'chat_id': 1, 'message_id': 10},
      });
      await container.pump();
      expect(
        (await container.read(
          interactiveEventsProvider((2, 1, 10)).future,
        )).map((m) => m.id),
        [11],
      );
      final before = socket.calls.length;
      socket.connections.add(null);
      await container.pump();
      await container.read(interactiveEventsProvider((2, 1, 10)).future);
      expect(socket.calls.length, greaterThan(before));
    },
  );
  test(
    'foreign root and undecipherable E2E fail closed instead of displaying zero votes',
    () async {
      final socket = _Socket(
        (_) async => {
          'messages': [row(11, root: 99)],
          'has_more': false,
        },
      );
      final container = _fixture(socket);
      await expectLater(
        container.read(interactiveEventsProvider((2, 1, 10)).future),
        throwsFormatException,
      );
      final encrypted = _Socket(
        (_) async => {
          'messages': [row(11, encrypted: true)],
          'has_more': false,
        },
      );
      final second = _fixture(encrypted);
      await expectLater(
        second.read(interactiveEventsProvider((2, 1, 10)).future),
        throwsStateError,
      );
    },
  );
  test(
    'bounded pagination rejects incomplete counts and keys isolate accounts',
    () async {
      var id = 10;
      final socket = _Socket(
        (_) async => {
          'messages': [row(++id)],
          'has_more': true,
          'next_cursor': id,
        },
      );
      final container = _fixture(socket);
      await expectLater(
        container.read(interactiveEventsProvider((2, 1, 10)).future),
        throwsStateError,
      );
      expect(socket.calls.length, 100);
      await expectLater(
        container.read(interactiveEventsProvider((999, 1, 10)).future),
        throwsStateError,
      );
      expect(socket.calls.length, 100);
    },
  );
}
