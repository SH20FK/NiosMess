import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/secret_chat_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/providers/websocket_dispatcher_provider.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_service.dart';
import 'package:pulse_flutter/services/bluetooth_mesh/bluetooth_mesh_service.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/core/storage/cache_service.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState.initial().copyWith(
    session: const AuthSession(
      accessToken: 'one',
      userId: 1,
      username: 'one',
      displayName: 'One',
    ),
  );
  void switchAccount() => state = state.copyWith(
    session: const AuthSession(
      accessToken: 'two',
      userId: 2,
      username: 'two',
      displayName: 'Two',
    ),
  );
}

ApiChatSummary _chat(int id) => ApiChatSummary(
  id: id,
  chatType: 'direct',
  name: 'Account fixture $id',
  unreadCount: 0,
  membersCount: 2,
);

class _Repository extends Fake implements ChatRepository {
  final requests = <Completer<List<ApiChatSummary>>>[];
  @override
  Future<List<ApiChatSummary>> listChats({String? publicKey}) {
    final c = Completer<List<ApiChatSummary>>();
    requests.add(c);
    return c.future;
  }
}

class _Cache extends CacheService {
  final writes = <int?>[];
  @override
  List<ApiChatSummary> getCachedChats({int? accountId}) =>
      accountId == null ? [_chat(999)] : [];
  @override
  Future<void> saveChats(List<ApiChatSummary> rows, {int? accountId}) async {
    writes.add(accountId);
  }
}

Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 100 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'real inbox clears previous account immediately and rejects old list responses/cache timers',
    () async {
      final repo = _Repository(), cache = _Cache();
      final socket = WebSocketClient(
        baseUrl: 'https://fixture.invalid',
        readToken: () => null,
      );
      final c = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_Auth.new),
          ordinaryE2eeProvider.overrideWithValue(null),
          bluetoothMeshProvider.overrideWithValue(null),
          secretChatCoordinatorProvider.overrideWith((ref) async => null),
          chatRepositoryProvider.overrideWithValue(repo),
          cacheServiceProvider.overrideWithValue(cache),
          webSocketClientProvider.overrideWithValue(socket),
        ],
      );
      addTearDown(c.dispose);
      addTearDown(socket.close);
      addTearDown(WebSocketPushDispatcher.dispose);
      final sub = c.listen(chatsProvider, (_, _) {});
      addTearDown(sub.close);
      await _until(() => repo.requests.length == 1);
      repo.requests[0].complete([_chat(1)]);
      await c.read(chatsProvider.future);
      final refresh = c.read(chatsProvider.notifier).refresh();
      await _until(() => repo.requests.length == 2);
      (c.read(authProvider.notifier) as _Auth).switchAccount();
      await _until(() => repo.requests.length == 3);
      expect(c.read(chatsProvider).value ?? [], isEmpty);
      repo.requests[2].complete([_chat(2)]);
      await c.read(chatsProvider.future);
      repo.requests[1].complete([_chat(111)]);
      await refresh;
      expect(c.read(chatsProvider).requireValue.single.id, 2);
      await Future<void>.delayed(const Duration(milliseconds: 2100));
      expect(cache.writes, [2]);
    },
  );
}
