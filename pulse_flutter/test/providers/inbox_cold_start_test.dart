// Cold start of the inbox: what is on screen before `list_chats` answers.
// * no cache: the list is loading (skeleton), never an "empty inbox";
// * cache: ordinary chats are shown at once and do not wait for the secret
//   store, which opens Hive boxes and secure storage first.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/core/storage/cache_service.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/chat_productivity_provider.dart';
import 'package:pulse_flutter/providers/secret_chat_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/providers/websocket_dispatcher_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/services/bluetooth_mesh/bluetooth_mesh_service.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_service.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState.initial().copyWith(
    session: const AuthSession(
      accessToken: 'fixture',
      userId: 1,
      username: 'me',
      displayName: 'Me',
    ),
  );
}

ApiChatSummary _chat(int id, {bool secret = false}) => ApiChatSummary(
  id: id,
  chatType: 'direct',
  name: 'Chat $id',
  unreadCount: 0,
  membersCount: 2,
  isSecret: secret,
  partnerUserId: 100 + id,
);

class _Repository extends Fake implements ChatRepository {
  final requests = <Completer<List<ApiChatSummary>>>[];
  @override
  Future<List<ApiChatSummary>> listChats({String? publicKey}) {
    final completer = Completer<List<ApiChatSummary>>();
    requests.add(completer);
    return completer.future;
  }
}

class _Cache extends CacheService {
  _Cache(this.rows);
  final List<ApiChatSummary> rows;
  @override
  List<ApiChatSummary> getCachedChats({int? accountId}) =>
      accountId == 1 ? rows : const <ApiChatSummary>[];
  @override
  Future<void> saveChats(List<ApiChatSummary> rows, {int? accountId}) async {}
}

Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 400 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue);
}

/// What the inbox screen draws for [value]: it shows rows for a non-empty
/// `asData`, otherwise it goes through `when`.
String _shown(AsyncValue<List<ApiChatSummary>> value) {
  final List<ApiChatSummary>? rows = value.asData?.value;
  if (rows != null && rows.isNotEmpty) return 'rows:${rows.length}';
  return value.when(
    data: (List<ApiChatSummary> list) => 'rows:${list.length}',
    error: (Object _, StackTrace _) => 'error',
    loading: () => 'loading',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Repository repo;
  late WebSocketClient socket;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    WebSocketPushDispatcher.dispose();
    repo = _Repository();
    socket = WebSocketClient(
      baseUrl: 'https://fixture.invalid',
      readToken: () => null,
    );
  });

  tearDown(() {
    WebSocketPushDispatcher.dispose();
    socket.close();
  });

  ProviderContainer open({
    required List<ApiChatSummary> cached,
    required FutureOr<SecretChatCoordinator?> Function() secret,
  }) {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_Auth.new),
        ordinaryE2eeProvider.overrideWithValue(null),
        bluetoothMeshProvider.overrideWithValue(null),
        secretChatCoordinatorProvider.overrideWith((ref) => secret()),
        chatRepositoryProvider.overrideWithValue(repo),
        cacheServiceProvider.overrideWithValue(_Cache(cached)),
        webSocketClientProvider.overrideWithValue(socket),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(chatsProvider, (_, _) {});
    addTearDown(sub.close);
    return container;
  }

  test('first launch without a cache is loading, not an empty inbox', () async {
    final ProviderContainer c = open(cached: const [], secret: () => null);
    await _until(() => repo.requests.length == 1);

    expect(
      _shown(c.read(visibleChatsProvider)),
      'loading',
      reason: 'chatsProvider is ${c.read(chatsProvider)}',
    );

    repo.requests[0].complete(<ApiChatSummary>[_chat(7)]);
    await c.read(chatsProvider.future);
    expect(_shown(c.read(visibleChatsProvider)), 'rows:1');
  });

  test('cached chats are shown before the secret store is ready', () async {
    final pending = Completer<SecretChatCoordinator?>();
    final ProviderContainer c = open(
      cached: <ApiChatSummary>[_chat(7), _chat(9, secret: true)],
      secret: () => pending.future,
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));

    // `list_chats` needs the store's public key, so it has not been sent yet.
    expect(repo.requests, isEmpty);
    // Ordinary chats are on screen already; secret ones take their ids from
    // the store and wait for it.
    expect(
      c.read(visibleChatsProvider).asData?.value.map((x) => x.id).toList(),
      <int>[7],
      reason: 'chatsProvider is ${c.read(chatsProvider)}',
    );

    pending.complete(null);
    await _until(() => repo.requests.length == 1);
    expect(
      c.read(chatsProvider).value?.map((x) => x.id).toSet(),
      <int>{7, 9},
    );

    repo.requests[0].complete(<ApiChatSummary>[_chat(7), _chat(8)]);
    // The server list replaces the cached one, including the chat it no
    // longer has.
    await _until(() {
      final Set<int>? ids = c
          .read(chatsProvider)
          .value
          ?.map((x) => x.id)
          .toSet();
      return ids != null && ids.length == 2 && ids.containsAll(<int>{7, 8});
    });
  });
}
