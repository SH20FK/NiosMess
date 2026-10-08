import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:universal_io/io.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/core/services/push_notification_service.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/providers/websocket_dispatcher_provider.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    hydrated: true,
    busy: false,
    pendingIdentifier: null,
    error: null,
    profile: null,
    session: AuthSession(
      accessToken: 'fixture',
      userId: 1,
      username: 'one',
      displayName: 'One',
    ),
  );
}

class _Chats extends ChatsNotifier {
  @override
  Future<List<ApiChatSummary>> build() async => const [
    ApiChatSummary(
      id: 42,
      chatType: 'direct',
      name: 'Two',
      unreadCount: 0,
      membersCount: 2,
    ),
  ];
}

class _Socket extends WebSocketClient {
  _Socket()
    : super(baseUrl: 'https://fixture.invalid', readToken: () => 'fixture');
  final pushes = StreamController<Map<String, dynamic>>.broadcast();
  final connections = StreamController<void>.broadcast();
  final histories = <Completer<dynamic>>[];
  final pages = <int>[];
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
    if (action != 'history') return <String, dynamic>{};
    pages.add(payload!['page'] as int);
    final result = Completer<dynamic>();
    histories.add(result);
    return result.future;
  }

  void history(int request, List<ApiMessage> messages) {
    histories[request].complete({
      'messages': messages.map((m) => m.toJson()).toList(),
    });
  }

  void push(ApiMessage message, {String action = 'new_message'}) {
    pushes.add({'action': action, 'payload': message.toJson()});
  }

  @override
  void close() {
    unawaited(pushes.close());
    unawaited(connections.close());
    super.close();
  }
}

ApiMessage _message(int id, {String? text}) => ApiMessage.fromJson({
  'id': id,
  'chat_id': 42,
  'sender_id': 2,
  'content': text ?? 'Message $id',
  'msg_type': 'text',
  'sent_at': '2026-10-08T10:00:00Z',
});

Future<void> _flush() async {
  for (int i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Socket socket;
  late ProviderContainer container;
  late Directory temporaryDirectory;
  setUpAll(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('ordinary_realtime_');
    Hive.init(temporaryDirectory.path);
    await Hive.openBox<List<dynamic>>('chat_shared_media_v1');
  });
  tearDownAll(() async {
    await Hive.close();
    await temporaryDirectory.delete(recursive: true);
  });
  List<ApiMessage> messages() =>
      container.read(chatMessagesProvider(42)).requireValue;

  setUp(() async {
    WebSocketPushDispatcher.dispose();
    socket = _Socket();
    container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_Auth.new),
        chatsProvider.overrideWith(_Chats.new),
        webSocketClientProvider.overrideWithValue(socket),
      ],
    );
    PushNotificationService.setCurrentChat(42);
    await container.read(chatsProvider.future);
    container.listen(chatMessagesProvider(42), (_, _) {});
    await _flush();
    socket.history(0, [_message(1)]);
    await container.read(chatMessagesProvider(42).future);
  });
  tearDown(() {
    container.dispose();
    WebSocketPushDispatcher.dispose();
    PushNotificationService.setCurrentChat(null);
    socket.close();
  });

  test(
    'real dispatcher delivers incoming messages without leaving the chat',
    () async {
      socket.push(_message(2));
      socket.push(_message(2));
      await _flush();
      expect(messages().map((m) => m.id), [1, 2]);
      expect(socket.histories, hasLength(1));
    },
  );

  test(
    'reconnection automatically catches up and coalesces repeated signals',
    () async {
      socket.connections.add(null);
      socket.connections.add(null);
      await _flush();
      expect(socket.histories, hasLength(2));
      socket.history(1, [_message(1), _message(2)]);
      await _flush();
      expect(messages().map((m) => m.id), [1, 2]);
    },
  );

  test(
    'history cannot erase a push or revert an edit or deletion received during load',
    () async {
      final refresh = container
          .read(chatMessagesProvider(42).notifier)
          .refresh();
      await _flush();
      socket.push(_message(2));
      socket.push(_message(1, text: 'Edited'), action: 'message_edited');
      await _flush();
      socket.history(1, [_message(1)]);
      await refresh;
      expect(messages().map((m) => m.id), [1, 2]);
      expect(messages().first.content, 'Edited');

      final deleting = container
          .read(chatMessagesProvider(42).notifier)
          .refresh();
      await _flush();
      socket.pushes.add({
        'action': 'message_deleted',
        'payload': {'chat_id': 42, 'message_id': 1},
      });
      await _flush();
      socket.history(2, [_message(1), _message(2)]);
      await deleting;
      expect(messages().map((m) => m.id), [2]);
    },
  );

  test(
    'failed catch-up retains displayed history and retries on next connection',
    () async {
      socket.connections.add(null);
      await _flush();
      socket.histories[1].completeError(StateError('Connection lost'));
      await _flush();
      expect(messages().map((m) => m.id), [1]);
      socket.connections.add(null);
      await _flush();
      socket.history(2, [_message(1), _message(2)]);
      await _flush();
      expect(messages().map((m) => m.id), [1, 2]);
    },
  );

  test('catch-up pages through more than eighty missed messages', () async {
    socket.connections.add(null);
    await _flush();
    socket.history(1, [for (int id = 22; id <= 101; id++) _message(id)]);
    await _flush();
    expect(socket.pages, [1, 1, 2]);
    socket.history(2, [for (int id = 1; id <= 21; id++) _message(id)]);
    await _flush();
    expect(messages(), hasLength(101));
    expect(messages().first.id, 1);
    expect(messages().last.id, 101);
  });
}
