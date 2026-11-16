import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/chat_muted_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/providers/websocket_dispatcher_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    hydrated: true,
    busy: false,
    session: AuthSession(
      accessToken: 'fixture',
      userId: 1,
      username: 'one',
      displayName: 'One',
    ),
    pendingIdentifier: null,
    error: null,
    profile: null,
  );

  @override
  Future<void> refreshFcmTokenRegistration() async {}
}

class _Chats extends ChatsNotifier {
  int refreshes = 0;
  int upserts = 0;

  @override
  Future<List<ApiChatSummary>> build() async => const <ApiChatSummary>[
    ApiChatSummary(
      id: 1,
      chatType: 'direct',
      name: 'One',
      unreadCount: 0,
      membersCount: 2,
    ),
  ];

  @override
  Future<void> refresh() async {
    refreshes++;
  }

  @override
  void upsertChat(ApiChatSummary chat) {
    upserts++;
  }
}

class _Socket extends WebSocketClient {
  _Socket()
    : super(baseUrl: 'https://fixture.invalid', readToken: () => 'fixture');

  final StreamController<Map<String, dynamic>> pushes =
      StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> get pushStream => pushes.stream;

  @override
  Future<dynamic> request(
    String action, {
    Map<String, dynamic>? payload,
    Duration timeout = const Duration(seconds: 15),
    int maxRetries = 2,
  }) async => <String, dynamic>{};

  void push(String action, Map<String, dynamic> payload) {
    pushes.add(<String, dynamic>{'action': action, 'payload': payload});
  }

  @override
  void close() {
    unawaited(pushes.close());
    super.close();
  }
}

const Duration _window = Duration(milliseconds: 500);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  late _Chats chats;

  Future<ProviderContainer> boot(_Socket socket) async {
    chats = _Chats();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        webSocketClientProvider.overrideWithValue(socket),
        authProvider.overrideWith(_Auth.new),
        chatsProvider.overrideWith(() => chats),
      ],
    );
    addTearDown(container.dispose);
    container.read(webSocketDispatcherProvider);
    await container.read(chatsProvider.future);
    return container;
  }

  test('burst of chat_updated pushes costs one debounced refresh', () async {
    final _Socket socket = _Socket();
    final ProviderContainer container = await boot(socket);

    for (int i = 0; i < 5; i++) {
      socket.push('chat_updated', <String, dynamic>{
        'chat_id': 1,
        'auto_delete_seconds': null,
      });
    }
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(chats.refreshes, 0, reason: 'must wait for the debounce window');

    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(chats.refreshes, 1);
    expect(chats.upserts, 0);
    expect(container.read(chatsProvider).hasValue, isTrue);
  });

  test('chat_deleted and chat_removed refresh the list', () async {
    final _Socket socket = _Socket();
    await boot(socket);

    socket.push('chat_deleted', <String, dynamic>{'chat_id': 4});
    socket.push('chat_removed', <String, dynamic>{'chat_id': 7});
    await Future<void>.delayed(_window + const Duration(milliseconds: 150));

    expect(chats.refreshes, 1);
  });

  test('presence pushes never invalidate the inbox', () async {
    final _Socket socket = _Socket();
    await boot(socket);

    for (int userId = 2; userId < 6; userId++) {
      socket.push('user_status', <String, dynamic>{
        'chat_id': 1,
        'user_id': userId,
        'is_online': userId.isEven,
      });
    }
    await Future<void>.delayed(_window + const Duration(milliseconds: 150));

    expect(chats.refreshes, 0);
    expect(chats.upserts, 0);
  });

  test('a full chat summary is upserted without a full refresh', () async {
    final _Socket socket = _Socket();
    await boot(socket);

    socket.push('chat_updated', <String, dynamic>{
      'chat_id': 2,
      'chat_type': 'group',
      'name': 'Renamed group',
      'unread_count': 3,
      'members_count': 5,
    });
    await Future<void>.delayed(_window + const Duration(milliseconds: 150));

    expect(chats.upserts, 1);
    expect(chats.refreshes, 0);
  });

  test('a mute flag in the payload reaches the mute hub', () async {
    final _Socket socket = _Socket();
    final ProviderContainer container = await boot(socket);

    expect(await container.read(chatMutedProvider(1).future), isFalse);

    socket.push('chat_updated', <String, dynamic>{
      'chat_id': 1,
      'is_muted': true,
    });
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(await container.read(chatMutedProvider(1).future), isTrue);
  });
}
