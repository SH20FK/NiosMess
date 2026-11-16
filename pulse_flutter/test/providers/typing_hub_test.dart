import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/typing_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';

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
}

class _Settings extends UiSettingsNotifier {
  @override
  UiSettingsState build() => const UiSettingsState.defaults();
}

class _Socket extends WebSocketClient {
  _Socket()
    : super(baseUrl: 'https://fixture.invalid', readToken: () => 'fixture');

  final StreamController<Map<String, dynamic>> pushes =
      StreamController<Map<String, dynamic>>.broadcast();
  final List<String> actions = <String>[];

  /// Proves the leak fix: the whole app must read `pushStream` once for typing,
  /// not once per chat shown in the inbox.
  int pushStreamReads = 0;

  @override
  Stream<Map<String, dynamic>> get pushStream {
    pushStreamReads++;
    return pushes.stream;
  }

  @override
  Future<dynamic> request(
    String action, {
    Map<String, dynamic>? payload,
    Duration timeout = const Duration(seconds: 15),
    int maxRetries = 2,
  }) async {
    actions.add(action);
    return <String, dynamic>{};
  }

  void typing(int chatId, int userId, {bool isTyping = true}) {
    pushes.add(<String, dynamic>{
      'action': 'typing',
      'payload': <String, dynamic>{
        'chat_id': chatId,
        'user_id': userId,
        'is_typing': isTyping,
      },
    });
  }

  @override
  void close() {
    unawaited(pushes.close());
    super.close();
  }
}

ProviderContainer _container(_Socket socket) {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      webSocketClientProvider.overrideWithValue(socket),
      authProvider.overrideWith(_Auth.new),
      uiSettingsProvider.overrideWith(_Settings.new),
    ],
  );
  // Typing pushes are only routed while the hub listens, exactly like the app
  // once any chat is on screen.
  container.read(typingHubProvider);
  return container;
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  test('one push subscription serves every chat in the inbox', () async {
    final socket = _Socket();
    final container = _container(socket);
    addTearDown(container.dispose);

    for (int chatId = 1; chatId <= 200; chatId++) {
      expect(container.read(typingProvider(chatId)).typingUserIds, isEmpty);
    }

    expect(socket.pushStreamReads, 1);
    expect(container.read(typingHubProvider), isEmpty);
  });

  test('typing pushes are routed to the right chat only', () async {
    final socket = _Socket();
    final container = _container(socket);
    addTearDown(container.dispose);

    container.read(typingProvider(5));
    container.read(typingProvider(6));

    socket.typing(5, 2);
    socket.typing(5, 3);
    await _flush();

    expect(container.read(typingProvider(5)).typingUserIds, <int>{2, 3});
    expect(container.read(typingProvider(6)).typingUserIds, isEmpty);
    expect(container.read(typingHubProvider.notifier).typingFor(5), <int>{2, 3});
  });

  test('own typing pings are ignored and duplicates do not churn state', () async {
    final socket = _Socket();
    final container = _container(socket);
    addTearDown(container.dispose);

    socket.typing(5, 1);
    await _flush();
    expect(container.read(typingHubProvider), isEmpty);

    socket.typing(5, 2);
    await _flush();
    final Map<int, Set<int>> first = container.read(typingHubProvider);
    socket.typing(5, 2);
    await _flush();
    expect(identical(container.read(typingHubProvider), first), isTrue);
  });

  test('is_typing=false and who_writing stop events clear the indicator', () async {
    final socket = _Socket();
    final container = _container(socket);
    addTearDown(container.dispose);

    socket.typing(5, 2);
    await _flush();
    expect(container.read(typingHubProvider)[5], <int>{2});

    socket.typing(5, 2, isTyping: false);
    await _flush();
    expect(container.read(typingHubProvider), isEmpty);

    socket.pushes.add(<String, dynamic>{
      'action': 'who_writing',
      'payload': <String, dynamic>{'chat_id': 5, 'user_id': 4},
    });
    await _flush();
    expect(container.read(typingHubProvider)[5], <int>{4});
  });

  test('sendTyping is throttled per chat across facades', () async {
    final socket = _Socket();
    final container = _container(socket);
    addTearDown(container.dispose);

    await container.read(typingProvider(5).notifier).sendTyping();
    await container.read(typingProvider(5).notifier).sendTyping();
    await container.read(typingProvider(6).notifier).sendTyping();

    expect(socket.actions, <String>['im_writing', 'im_writing']);
  });

  testWidgets('typing indicator auto-expires after the TTL', (
    WidgetTester tester,
  ) async {
    final socket = _Socket();
    final container = _container(socket);

    socket.typing(5, 2);
    await tester.pump();
    expect(container.read(typingProvider(5)).typingUserIds, <int>{2});

    await tester.pump(const Duration(seconds: 5));
    expect(container.read(typingProvider(5)).typingUserIds, isEmpty);
    expect(container.read(typingHubProvider), isEmpty);

    container.dispose();
  });
}
