import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:universal_io/io.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/core/network/ws_media_fetcher.dart';
import 'package:pulse_flutter/providers/secret_chat_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';

class _Cache extends Fake implements BaseCacheManager {
  @override
  Future<void> emptyCache() async {}
}

class _Repository extends Fake implements ChatRepository {}

class _Socket extends WebSocketClient {
  _Socket()
    : super(baseUrl: 'https://fixture.invalid', readToken: () => 'fixture');
  final connectedEvents = StreamController<void>.broadcast();
  final pushes = StreamController<Map<String, dynamic>>.broadcast();
  final actions = <String>[];
  bool connected = true;
  final peerKey = base64Encode(List.filled(32, 11));
  @override
  bool get isConnected => connected;
  @override
  Stream<void> get onConnected => connectedEvents.stream;
  @override
  Stream<Map<String, dynamic>> get pushStream => pushes.stream;
  @override
  Future<dynamic> request(
    String action, {
    Map<String, dynamic>? payload,
    Duration timeout = const Duration(seconds: 15),
    int maxRetries = 2,
  }) async {
    actions.add(action);
    if (!connected) throw StateError('offline');
    if (action == 'secret_sync') {
      return {
        'peer_public_key': peerKey,
        'peer_protocol_version': 2,
        'events': [],
        'has_more': false,
      };
    }
    return <String, dynamic>{};
  }

  Future<void> disposeFixture() async {
    await connectedEvents.close();
    await pushes.close();
    super.close();
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'coordinator observes lifecycle, suspends idle polling and catches reconnect',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'secret-lifecycle-',
      );
      Hive.init(directory.path);
      FlutterSecureStorage.setMockInitialValues({});
      const paths = MethodChannel('plugins.flutter.io/path_provider');
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        paths,
        (_) async => directory.path,
      );
      final httpClient = MockClient((_) async => http.Response('', 200));
      final restoreMedia = WsMediaFetcher.debugOverride(
        cacheManager: _Cache(),
        playbackCache: _Cache(),
        httpClient: httpClient,
        temporaryDirectory: () async => directory,
      );
      final socket = _Socket();
      SecretChatCoordinator? coordinator;
      addTearDown(() async {
        await coordinator?.close(erase: true);
        await socket.disposeFixture();
        httpClient.close();
        restoreMedia();
        binding.defaultBinaryMessenger.setMockMethodCallHandler(paths, null);
        await Hive.close();
        await directory.delete(recursive: true);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      });
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      coordinator = await SecretChatCoordinator.open(
        701,
        'fixture',
        socket,
        _Repository(),
      );
      await coordinator.tick();
      await Future<void>.delayed(Duration.zero);
      final uiId = await coordinator.engine.open(
        peerId: 702,
        peerName: 'Peer',
        remoteId: 42,
        peerKey: socket.peerKey,
      );
      final chat = coordinator.engine.findChat(uiId)!;
      await coordinator.engine.journal.commit(chat, {
        ...coordinator.engine.chat(uiId),
        'status': 'secured',
        'ratchet': {},
        'initialized': true,
      });
      await coordinator.tick();
      expect(coordinator.debugPollingScheduled, isTrue);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(coordinator.debugPollingScheduled, isFalse);
      final beforeResume = socket.actions.length;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await coordinator.tick();
      await Future<void>.delayed(Duration.zero);
      expect(socket.actions.length, greaterThan(beforeResume));
      expect(coordinator.debugPollingScheduled, isTrue);

      socket.connected = false;
      await coordinator.tick();
      expect(coordinator.debugPollingScheduled, isFalse);
      socket.actions.clear();
      socket.connected = true;
      socket.connectedEvents.add(null);
      await Future<void>.delayed(Duration.zero);
      await coordinator.tick();
      await Future<void>.delayed(Duration.zero);
      expect(socket.actions, contains('set_public_key'));
      expect(socket.actions, contains('secret_sync'));
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(coordinator.debugPollingScheduled, isFalse);
      await coordinator.engine.enqueue(uiId, {
        'text': 'durable background send',
        'type': 'text',
      });
      await Future<void>.delayed(Duration.zero);
      expect(
        coordinator.engine.messages(uiId).single['content'],
        'durable background send',
      );
      expect(coordinator.debugPollingScheduled, isTrue);
      await coordinator.close(erase: true);
      expect(coordinator.debugPollingScheduled, isFalse);
      final afterClose = socket.actions.length;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(socket.actions.length, afterClose);
    },
  );
}
