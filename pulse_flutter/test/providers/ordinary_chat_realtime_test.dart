import 'package:pulse_flutter/services/bluetooth_mesh/ble_transport.dart';
import 'package:pulse_flutter/services/bluetooth_mesh/bluetooth_mesh_service.dart';
import 'package:pulse_flutter/services/bluetooth_mesh/mesh_preferences.dart';
import 'dart:convert';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_codec.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_service.dart';
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulse_flutter/core/storage/chat_history_anchor.dart';
import 'package:pulse_flutter/core/storage/message_history_snapshot.dart';
import 'package:pulse_flutter/widgets/chat/message_layout_store.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pulse_flutter/core/storage/encrypted_message_cache.dart';
import 'package:pulse_flutter/core/storage/chat_history_retention.dart';
import 'package:pulse_flutter/core/storage/cache_service.dart';
import 'package:pulse_flutter/core/storage/chat_media_cache.dart';
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
  void switchAccount(int userId) {
    state = state.copyWith(
      session: AuthSession(
        accessToken: 'fixture',
        userId: userId,
        username: 'account$userId',
        displayName: 'Account $userId',
      ),
    );
  }
}

class _Chats extends ChatsNotifier {
  @override
  Future<List<ApiChatSummary>> build() async => const [
    ApiChatSummary(
      id: 9142001,
      chatType: 'direct',
      name: 'Two',
      unreadCount: 0,
      membersCount: 2,
    ),
  ];
}

class _NoopSound extends SoundService {
  @override
  Future<void> playEvent(SoundEvent event, {double? volume}) async {}
  @override
  Future<void> playNotification(SoundEvent event, {double? volume}) async {}
}

class _NoopCache extends CacheService {
  const _NoopCache();
  @override
  Future<void> saveChats(List<ApiChatSummary> chats, {int? accountId}) async {}
}

class _Socket extends WebSocketClient {
  _Socket()
    : super(baseUrl: 'https://fixture.invalid', readToken: () => 'fixture');
  final pushes = StreamController<Map<String, dynamic>>.broadcast();
  final connections = StreamController<void>.broadcast();
  final histories = <Completer<dynamic>>[];
  final pages = <int>[];
  final sentMessages = <Completer<dynamic>>[];
  final outgoing = <Map<String, dynamic>>[];
  final readChats = <int>[];
  Future<void> Function()? beforeSend;
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
    if (action == 'mark_read') readChats.add(payload!['chat_id'] as int);
    if (action == 'send_message') {
      await beforeSend?.call();
      outgoing.add(Map<String, dynamic>.from(payload!));
      final result = Completer<dynamic>();
      sentMessages.add(result);
      return result.future;
    }
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
  'chat_id': 9142001,
  'sender_id': 2,
  'content': text ?? 'Message $id',
  'msg_type': 'text',
  'sent_at': '2026-10-08T10:00:00Z',
});

Future<void> _flush() async {
  for (int i = 0; i < 12; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

Future<void> _waitUntil(bool Function() predicate) async {
  for (var i = 0; i < 600 && !predicate(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(predicate(), isTrue);
}

class _InternetOnly extends MeshPreference {
  @override
  bool build() => false;
}

class _OnlineSocket extends _Socket {
  @override
  bool get isConnected => true;
}

class _PendingPreparation extends OrdinaryE2eeService {
  _PendingPreparation()
    : super(1, (action, {payload}) async => <String, dynamic>{});
  final pending = Completer<E2eJson?>();
  bool started = false;
  @override
  Future<E2eJson?> prepare(int chatId, {bool force = false}) {
    started = true;
    return pending.future;
  }

  @override
  Future<void> prepareMesh() async {}
}

class _MeshOn extends MeshPreference {
  @override
  bool build() => true;
}

class _NoRadio implements BleTransport {
  @override
  Stream<Map<String, dynamic>> get events => const Stream.empty();
  @override
  Future<Map<String, dynamic>> start({bool requestPermission = false}) async =>
      {'state': 'unsupported'};
  @override
  Future<void> stop() async {}
  @override
  Future<void> send(String peer, bytes) async {}
}

class _IdleMesh extends BluetoothMeshService {
  _IdleMesh(OrdinaryE2eeService ordinary)
    : super(
        userId: 1,
        scope: () => 'fixture',
        ordinary: ordinary,
        transport: _NoRadio(),
        chat: (_) => null,
        cloudSubmit: (_) async {
          throw StateError('Unexpected cloud submission');
        },
        enabled: () => true,
        online: () => true,
      );
  @override
  Future<void> replay() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Isolated ordinary history fixture', () {
    late _Socket socket;
    late ProviderContainer container;
    late Directory temporaryDirectory;
    setUpAll(() async {
      FlutterSecureStorage.setMockInitialValues({});
      EncryptedMessageCache.resetMemoryForTesting();
      temporaryDirectory = await Directory.systemTemp.createTemp(
        'ordinary_realtime_',
      );
      Hive.init(temporaryDirectory.path);
      await ChatMediaCache.ensureInitialized();
    });
    tearDownAll(() async {
      await Hive.close();
      await temporaryDirectory.delete(recursive: true);
    });
    List<ApiMessage> messages() =>
        container.read(chatMessagesProvider(9142001)).requireValue;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await EncryptedMessageCache.clearAll();
      await EncryptedMessageCache.clearAccount(1, []);
      await EncryptedMessageCache.clearAccount(2, []);
      WebSocketPushDispatcher.dispose();
      socket = _Socket();
      container = ProviderContainer(
        overrides: [
          meshPreferenceProvider.overrideWith(_InternetOnly.new),
          bluetoothMeshProvider.overrideWithValue(null),
          ordinaryE2eeProvider.overrideWithValue(null),
          authProvider.overrideWith(_Auth.new),
          chatsProvider.overrideWith(_Chats.new),
          webSocketClientProvider.overrideWithValue(socket),
          appSoundProvider.overrideWithValue(_NoopSound()),
        ],
      );
      PushNotificationService.setCurrentChat(9142001);
      await container.read(chatsProvider.future);
      container.listen(chatMessagesProvider(9142001), (_, _) {});
      for (var i = 0; i < 200 && socket.histories.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      socket.history(0, [_message(1)]);
      await container.read(chatMessagesProvider(9142001).future);
      await container
          .read(chatMessagesProvider(9142001).notifier)
          .flushHistoryArchive();
    });
    tearDown(() async {
      if (container.exists(chatMessagesProvider(9142001))) {
        await container
            .read(chatMessagesProvider(9142001).notifier)
            .flushHistoryArchive();
      }
      container.dispose();
      WebSocketPushDispatcher.dispose();
      PushNotificationService.setCurrentChat(null);
      socket.close();
      await EncryptedMessageCache.clearAccount(1, []);
      await EncryptedMessageCache.clearAccount(2, []);
      await _flush();
    });

    test(
      'sender original is durably recoverable before any network request',
      () async {
        var localSaved = false;
        socket.beforeSend = () async {
          expect(localSaved, isTrue);
          final archive = await EncryptedHistoryArchive.open(1, 9142001);
          final rows = await archive.read(limit: 20);
          expect(
            rows.any(
              (row) => row.content == 'durable sender original' && row.id < 0,
            ),
            isTrue,
          );
        };
        final sending = container
            .read(chatMessagesProvider(9142001).notifier)
            .send(
              'durable sender original',
              onLocalSaved: () => localSaved = true,
            );
        await _waitUntil(() => socket.sentMessages.isNotEmpty);
        socket.sentMessages.single.complete(
          _message(
            99,
            text: 'durable sender original',
          ).copyWith(senderId: 1).toJson(),
        );
        await sending;
      },
    );
    test(
      'disk failure keeps own text pending and never starts a network send',
      () async {
        await Hive.lazyBox<String>('enc_history_archive_v1').close();
        var localSaved = false;
        final notifier = container.read(chatMessagesProvider(9142001).notifier);
        try {
          await expectLater(
            notifier.send(
              'unsaved original',
              onLocalSaved: () => localSaved = true,
            ),
            throwsA(anything),
          );
          expect(localSaved, isFalse);
          expect(socket.outgoing, isEmpty);
          expect(
            messages().any((row) => row.content == 'unsaved original'),
            isTrue,
          );
        } finally {
          await Hive.openLazyBox<String>('enc_history_archive_v1');
          await notifier.flushHistoryArchive();
        }
      },
    );
    test(
      'failed manual retry retains the same durable original and never deletes it first',
      () async {
        final notifier = container.read(chatMessagesProvider(9142001).notifier);
        final first = notifier.send('retained retry fixture');
        await _waitUntil(() => socket.sentMessages.isNotEmpty);
        socket.sentMessages.single.completeError(StateError('fixture offline'));
        await first;
        await notifier.flushHistoryArchive();
        final original = messages().singleWhere((m) => m.id < 0);
        await Hive.lazyBox<String>('enc_history_archive_v1').close();
        try {
          await expectLater(
            notifier.send(original.content, localId: '${original.id}'),
            throwsA(anything),
          );
          expect(messages().where((m) => m.id < 0).map((m) => m.id), [
            original.id,
          ]);
          expect(
            messages().singleWhere((m) => m.id == original.id).content,
            original.content,
          );
          expect(socket.sentMessages, hasLength(1));
        } finally {
          await Hive.openLazyBox<String>('enc_history_archive_v1');
          await notifier.flushHistoryArchive();
        }
        final archive = await EncryptedHistoryArchive.open(1, 9142001);
        expect((await archive.message(original.id))?.content, original.content);
      },
    );
    test('background history does not read incoming messages', () async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      socket.readChats.clear();
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      try {
        socket.push(_message(2));
        await _waitUntil(() => messages().any((m) => m.id == 2));
        await container
            .read(chatMessagesProvider(9142001).notifier)
            .flushHistoryArchive();
        await _flush();
        await container.read(chatMessagesProvider(9142001).notifier).markRead();
        expect(socket.readChats, isEmpty);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await container.read(chatMessagesProvider(9142001).notifier).markRead();
        expect(socket.readChats, [9142001]);
      } finally {
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      }
    });

    test(
      'history and push dispatcher do not wait for Bluetooth key preparation',
      () async {
        container.dispose();
        WebSocketPushDispatcher.dispose();
        socket.close();
        socket = _OnlineSocket();
        final ordinary = _PendingPreparation(),
            mesh = _IdleMesh(_PendingPreparation());
        container = ProviderContainer(
          overrides: [
            meshPreferenceProvider.overrideWith(_MeshOn.new),
            bluetoothMeshProvider.overrideWithValue(mesh),
            ordinaryE2eeProvider.overrideWithValue(ordinary),
            authProvider.overrideWith(_Auth.new),
            chatsProvider.overrideWith(_Chats.new),
            webSocketClientProvider.overrideWithValue(socket),
            appSoundProvider.overrideWithValue(_NoopSound()),
          ],
        );
        try {
          await container.read(chatsProvider.future);
          container.listen(chatMessagesProvider(9142001), (_, _) {});
          await _waitUntil(() => ordinary.started);
          await _waitUntil(() => socket.histories.isNotEmpty);
          socket.history(0, [_message(1)]);
          await container.read(chatMessagesProvider(9142001).future);
          expect(ordinary.pending.isCompleted, isFalse);
          expect(messages().single.id, 1);
          socket.push(_message(2));
          await _waitUntil(() => messages().any((m) => m.id == 2));
          expect(ordinary.pending.isCompleted, isFalse);
        } finally {
          ordinary.pending.complete(null);
          await _flush();
          ordinary.dispose();
          mesh.ordinary.dispose();
          mesh.dispose();
        }
      },
    );

    test(
      'unobserved history expires but an active send retains its notifier',
      () async {
        container.dispose();
        WebSocketPushDispatcher.dispose();
        socket.close();
        await EncryptedMessageCache.clearAccount(1, []);
        socket = _Socket();
        final retention = ChatHistoryRetention(
          idleTtl: const Duration(milliseconds: 40),
        );
        container = ProviderContainer(
          overrides: [
            meshPreferenceProvider.overrideWith(_InternetOnly.new),
            bluetoothMeshProvider.overrideWithValue(null),
            ordinaryE2eeProvider.overrideWithValue(null),
            authProvider.overrideWith(_Auth.new),
            chatsProvider.overrideWith(_Chats.new),
            webSocketClientProvider.overrideWithValue(socket),
            appSoundProvider.overrideWithValue(_NoopSound()),
            chatHistoryRetentionProvider.overrideWithValue(retention),
            cacheServiceProvider.overrideWithValue(const _NoopCache()),
          ],
        );
        addTearDown(retention.dispose);
        final subscription = container.listen(
          chatMessagesProvider(9142001),
          (_, _) {},
        );
        await _waitUntil(() => socket.histories.isNotEmpty);
        socket.history(0, [_message(1)]);
        await container.read(chatMessagesProvider(9142001).future);
        final notifier = container.read(chatMessagesProvider(9142001).notifier);
        await notifier.flushHistoryArchive();
        final sending = notifier.send('still delivering');
        await _waitUntil(() => socket.sentMessages.isNotEmpty);
        await notifier.flushHistoryArchive();
        subscription.close();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await container.pump();
        expect(container.exists(chatMessagesProvider(9142001)), isTrue);
        expect(retention.idleCount, 0);
        socket.sentMessages.single.complete(
          _message(2, text: 'still delivering').toJson(),
        );
        await sending;
        await notifier.flushHistoryArchive();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await container.pump();
        expect(container.exists(chatMessagesProvider(9142001)), isFalse);
      },
    );

    test(
      'cold offline history reads the same account key used for saving',
      () async {
        container.dispose();
        WebSocketPushDispatcher.dispose();
        socket.close();
        await EncryptedMessageCache.clearAccount(1, []);
        FlutterSecureStorage.setMockInitialValues({});
        await EncryptedMessageCache.ensureInitialized();
        await EncryptedMessageCache.saveMessages(9142001, [
          _message(73, text: 'saved offline'),
        ], userId: 1);
        socket = _Socket();
        container = ProviderContainer(
          overrides: [
            meshPreferenceProvider.overrideWith(_InternetOnly.new),
            bluetoothMeshProvider.overrideWithValue(null),
            ordinaryE2eeProvider.overrideWithValue(null),
            authProvider.overrideWith(_Auth.new),
            chatsProvider.overrideWith(_Chats.new),
            webSocketClientProvider.overrideWithValue(socket),
            appSoundProvider.overrideWithValue(_NoopSound()),
          ],
        );
        container.listen(chatMessagesProvider(9142001), (_, _) {});
        // Encryption may complete on a real worker isolate before the fetch starts.
        for (var i = 0; i < 100 && socket.histories.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        expect(socket.histories, hasLength(1));
        socket.histories.single.completeError(StateError('offline'));
        final restored = await container.read(
          chatMessagesProvider(9142001).future,
        );
        expect(restored.single.content, 'saved offline');
      },
    );

    test(
      'an old account send response cannot enter the new account history',
      () async {
        final sending = container
            .read(chatMessagesProvider(9142001).notifier)
            .send('old account');
        await _flush();
        expect(socket.sentMessages, hasLength(1));
        (container.read(authProvider.notifier) as _Auth).switchAccount(2);
        for (var i = 0; i < 200 && socket.histories.length < 2; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        expect(socket.histories, hasLength(2));
        socket.history(1, [_message(80, text: 'new account')]);
        for (var i = 0; i < 200 && messages().isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        await container
            .read(chatMessagesProvider(9142001).notifier)
            .flushHistoryArchive();
        socket.sentMessages.single.complete(
          _message(99, text: 'old account').toJson(),
        );
        await sending;
        expect(messages().map((m) => m.content), ['new account']);
      },
    );

    test(
      'older page merge preserves concurrent pushes and edits and coalesces pagination',
      () async {
        final notifier = container.read(chatMessagesProvider(9142001).notifier);
        final older = notifier.loadOlder();
        final duplicate = notifier.loadOlder();
        expect(identical(older, duplicate), isTrue);
        await _flush();
        expect(socket.histories, hasLength(2));
        socket.push(_message(2));
        socket.push(
          _message(1, text: 'edited while paging'),
          action: 'message_edited',
        );
        await _flush();
        socket.history(1, [_message(0)]);
        expect(await older, 1);
        expect(messages().map((m) => m.id), [0, 1, 2]);
        expect(messages()[1].content, 'edited while paging');
      },
    );

    test(
      'a deleted off-window row cannot be resurrected by an older response',
      () async {
        final notifier = container.read(chatMessagesProvider(9142001).notifier);
        final older = notifier.loadOlder();
        await _waitUntil(() => socket.histories.length == 2);
        socket.pushes.add({
          'action': 'message_deleted',
          'payload': {'chat_id': 9142001, 'message_id': 77},
        });
        await _flush();
        socket.history(1, [_message(77)]);
        expect(await older, 0);
        expect(messages().map((m) => m.id), [1]);
        final archive = await EncryptedHistoryArchive.open(1, 9142001);
        expect(await archive.message(77), isNull);
      },
    );

    test(
      'real dispatcher delivers incoming messages without leaving the chat',
      () async {
        socket.push(_message(2));
        socket.push(_message(2));
        await _waitUntil(() => messages().any((m) => m.id == 2));
        expect(messages().map((m) => m.id), [1, 2]);
        expect(socket.histories, hasLength(1));
      },
    );

    for (final source in ['push', 'history']) {
      test(
        'forged wire decrypt flag in $source cannot erase own original',
        () async {
          final notifier = container.read(
            chatMessagesProvider(9142001).notifier,
          );
          final sending = notifier.send('known own provenance fixture');
          await _waitUntil(() => socket.sentMessages.isNotEmpty);
          socket.sentMessages.single.complete(
            _message(
              2,
              text: 'known own provenance fixture',
            ).copyWith(senderId: 1).toJson(),
          );
          await sending;
          await notifier.flushHistoryArchive();
          final forged = <String, dynamic>{
            'id': 2, 'chat_id': 9142001, 'sender_id': 1,
            'content': '', 'msg_type': 'text',
            'is_e2ee': true, 'is_decrypted': true,
            // No envelope: the wire flag alone has no authentication provenance.
            'sent_at': '2026-10-08T10:00:00Z',
            'edited_at': '2026-10-26T10:00:00Z',
          };
          if (source == 'push') {
            socket.pushes.add({'action': 'message_edited', 'payload': forged});
            await _waitUntil(() => messages().last.editedAt != null);
          } else {
            final refreshing = notifier.refresh();
            await _waitUntil(() => socket.histories.length > 1);
            socket.histories[1].complete({
              'messages': [_message(1).toJson(), forged],
            });
            await refreshing;
          }
          expect(
            messages().singleWhere((m) => m.id == 2).content,
            'known own provenance fixture',
          );
          await notifier.flushHistoryArchive();
          final archive = await EncryptedHistoryArchive.open(1, 9142001);
          expect(
            (await archive.message(2))!.content,
            'known own provenance fixture',
          );
        },
      );
    }

    test(
      'unopenable own edited echo cannot replace the locally known original',
      () async {
        socket.push(
          _message(2, text: 'own protected fixture').copyWith(senderId: 1),
        );
        await _waitUntil(() => messages().any((m) => m.id == 2));
        socket.push(
          _message(2, text: '').copyWith(
            senderId: 1,
            editedAt: DateTime(2026, 10, 26),
            isE2ee: true,
            isDecrypted: false,
            e2eeContent: 'corrupt-fixture',
          ),
          action: 'message_edited',
        );
        await _waitUntil(() => messages().last.editedAt != null);
        expect(messages().last.content, 'own protected fixture');
        final notifier = container.read(chatMessagesProvider(9142001).notifier);
        await notifier.flushHistoryArchive();
        final archive = await EncryptedHistoryArchive.open(1, 9142001);
        expect((await archive.message(2))!.content, 'own protected fixture');
        socket.push(
          _message(
            2,
            text: 'valid later edit',
          ).copyWith(senderId: 1, editedAt: DateTime(2026, 10, 27)),
          action: 'message_edited',
        );
        await _waitUntil(() => messages().last.content == 'valid later edit');
      },
    );

    test(
      'explicit plaintext caption removal and tombstone remain authoritative',
      () async {
        ApiMessage media(
          String text, {
          DateTime? editedAt,
          bool deleted = false,
        }) => _message(2, text: text).copyWith(
          senderId: 1,
          msgType: 'media',
          mediaUrl: 'https://fixture.invalid/image',
          editedAt: editedAt,
          isDeleted: deleted,
        );
        socket.push(media('caption from another device'));
        await _waitUntil(() => messages().any((m) => m.id == 2));
        socket.push(
          media('', editedAt: DateTime(2026, 10, 26)),
          action: 'message_edited',
        );
        await _waitUntil(() => messages().last.editedAt != null);
        expect(messages().last.content, isEmpty);
        final notifier = container.read(chatMessagesProvider(9142001).notifier);
        await notifier.flushHistoryArchive();
        final archive = await EncryptedHistoryArchive.open(1, 9142001);
        expect((await archive.message(2))!.content, isEmpty);
        socket.push(
          media('later caption', editedAt: DateTime(2026, 10, 27)),
          action: 'message_edited',
        );
        await _waitUntil(() => messages().last.content == 'later caption');
        socket.push(
          media('', editedAt: DateTime(2026, 10, 28), deleted: true),
          action: 'message_edited',
        );
        await _waitUntil(() => messages().last.isDeleted);
        expect(messages().last.content, isEmpty);
        await notifier.flushHistoryArchive();
        final deleted = await archive.message(2);
        expect(
          deleted == null || (deleted.isDeleted && deleted.content.isEmpty),
          isTrue,
        );
      },
    );

    test(
      'repeated history with unopenable own echo preserves the original on disk',
      () async {
        socket.push(
          _message(
            2,
            text: 'own durable history fixture',
          ).copyWith(senderId: 1, isE2ee: true, isDecrypted: true),
        );
        await _waitUntil(() => messages().any((m) => m.id == 2));
        final notifier = container.read(chatMessagesProvider(9142001).notifier);
        await notifier.flushHistoryArchive();
        final refresh = notifier.refresh();
        await _waitUntil(() => socket.histories.length > 1);
        socket.history(1, [
          _message(1),
          _message(2, text: '').copyWith(
            senderId: 1,
            isE2ee: true,
            isDecrypted: false,
            e2eeContent: 'corrupt-fixture',
          ),
        ]);
        await refresh;
        expect(messages().last.content, 'own durable history fixture');
        await notifier.flushHistoryArchive();
        final archive = await EncryptedHistoryArchive.open(1, 9142001);
        expect(
          (await archive.message(2))!.content,
          'own durable history fixture',
        );
      },
    );

    test(
      'production pushes, edits and send acknowledgements carry exact layout deltas',
      () async {
        final store = MessageLayoutStore()..reset(messages());
        final deltas = <MessageHistorySnapshot>[];
        final subscription = container.listen(chatMessagesProvider(9142001), (
          _,
          next,
        ) {
          final rows = next.value;
          if (rows == null) return;
          if (rows is MessageHistorySnapshot) deltas.add(rows);
          store.sync(rows);
          expect(store.messages.map((m) => m.id), rows.map((m) => m.id));
          for (final row in rows) {
            expect(store.byId[row.id], same(row));
          }
        });
        addTearDown(subscription.close);
        socket.push(_message(2));
        await _waitUntil(() => messages().any((m) => m.id == 2));
        expect(
          deltas.any((delta) => delta.appended.any((m) => m.id == 2)),
          isTrue,
        );
        socket.push(
          _message(1, text: 'Edited by push'),
          action: 'message_edited',
        );
        await _waitUntil(() => messages().first.content == 'Edited by push');
        expect(
          deltas.any(
            (delta) => delta.replacements.values.any(
              (m) => m.id == 1 && m.content == 'Edited by push',
            ),
          ),
          isTrue,
        );

        final notifier = container.read(chatMessagesProvider(9142001).notifier);
        final sending = notifier.send('Known optimistic tail');
        await _waitUntil(() => socket.sentMessages.isNotEmpty);
        expect(
          deltas.any((delta) => delta.appended.any((m) => m.id < 0)),
          isTrue,
        );
        socket.sentMessages.single.complete(
          _message(
            3,
            text: 'Known optimistic tail',
          ).copyWith(senderId: 1).toJson(),
        );
        await sending;
        await notifier.flushHistoryArchive();
        expect(
          deltas.any(
            (delta) => delta.replacements.values.any((m) => m.id == 3),
          ),
          isTrue,
        );
        expect(store.byId[3]!.content, 'Known optimistic tail');
        expect(store.messages.any((m) => m.id < 0), isFalse);
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
        await _waitUntil(() => messages().any((m) => m.id == 2));
        expect(messages().map((m) => m.id), [1, 2]);
      },
    );

    test(
      'history cannot erase a push or revert an edit or deletion received during load',
      () async {
        final refresh = container
            .read(chatMessagesProvider(9142001).notifier)
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
            .read(chatMessagesProvider(9142001).notifier)
            .refresh();
        await _flush();
        socket.pushes.add({
          'action': 'message_deleted',
          'payload': {'chat_id': 9142001, 'message_id': 1},
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
        await _waitUntil(() => messages().any((m) => m.id == 2));
        expect(messages().map((m) => m.id), [1, 2]);
      },
    );

    test(
      'a deletion from the first catch-up page stays deleted while the next page loads',
      () async {
        final notifier = container.read(chatMessagesProvider(9142001).notifier);
        final refreshing = notifier.refresh();
        await _waitUntil(() => socket.histories.length == 2);
        socket.history(1, [for (var id = 22; id <= 101; id++) _message(id)]);
        await _waitUntil(() => socket.histories.length == 3);
        socket.pushes.add({
          'action': 'message_deleted',
          'payload': {'chat_id': 9142001, 'message_id': 100},
        });
        await _flush();
        socket.history(2, [for (var id = 1; id <= 21; id++) _message(id)]);
        await refreshing;
        await notifier.flushHistoryArchive();
        expect(messages().length, 100);
        expect(messages().any((m) => m.id == 100), isFalse);
        final archive = await EncryptedHistoryArchive.open(1, 9142001);
        expect(await archive.message(100), isNull);
      },
    );

    test('catch-up pages through more than eighty missed messages', () async {
      socket.connections.add(null);
      await _flush();
      socket.history(1, [for (int id = 22; id <= 101; id++) _message(id)]);
      await _waitUntil(() => socket.pages.length == 3);
      expect(socket.pages, [1, 1, 2]);
      socket.history(2, [for (int id = 1; id <= 21; id++) _message(id)]);
      await _waitUntil(() => messages().length == 101);
      expect(messages(), hasLength(101));
      expect(messages().first.id, 1);
      expect(messages().last.id, 101);
    });
    test(
      'active archive window pages both ways, preserves pending sends and loads reply targets',
      () async {
        final notifier = container.read(chatMessagesProvider(9142001).notifier);
        final archive = await EncryptedHistoryArchive.open(1, 9142001);
        await archive.write([for (var id = 1; id <= 1600; id++) _message(id)]);
        final jumping = notifier.jumpToLatest();
        for (var i = 0; i < 300 && socket.histories.length < 2; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        socket.history(1, [for (var id = 1521; id <= 1600; id++) _message(id)]);
        await jumping;
        expect(messages().length, ChatMessagesNotifier.maxVisibleMessages);
        expect(messages().first.id, 1301);
        for (var page = 0; page < 8; page++) {
          expect(await notifier.loadOlder(), 50);
          expect(messages().length, ChatMessagesNotifier.maxVisibleMessages);
        }
        expect(messages().first.id, 901);
        expect(notifier.window.hasNewer, isTrue);
        final anchorIds = messages().map((m) => m.id).toList();
        socket.push(_message(1601));
        await _flush();
        await notifier.flushHistoryArchive();
        expect(messages().map((m) => m.id), anchorIds);
        expect((await archive.message(1601))?.content, 'Message 1601');
        final sending = notifier.send('pending outside archive window');
        await _flush();
        await notifier.flushHistoryArchive();
        expect(messages().length, ChatMessagesNotifier.maxVisibleMessages);
        expect(messages().any((m) => m.id < 0), isFalse);
        socket.sentMessages.single.completeError(StateError('offline'));
        await sending;
        expect(
          (await archive.read()).last.content,
          'pending outside archive window',
        );
        expect((await archive.read()).last.isFailed, isTrue);
        await notifier.loadNewer();
        expect(messages().first.id, 951);
        expect(messages().length, ChatMessagesNotifier.maxVisibleMessages);
        expect(await notifier.loadAround(12), isTrue);
        expect(messages().any((m) => m.id == 12), isTrue);
        expect(
          messages().length,
          lessThanOrEqualTo(ChatMessagesNotifier.maxVisibleMessages),
        );
        final latest = notifier.jumpToLatest();
        for (var i = 0; i < 300 && socket.histories.length < 3; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        socket.histories.last.completeError(StateError('offline'));
        await latest;
        expect(messages().last.content, 'pending outside archive window');
        expect(messages().last.isFailed, isTrue);
        expect(messages().length, ChatMessagesNotifier.maxVisibleMessages);
      },
    );
    test(
      'disk failure keeps the full unsaved candidate until archive retry succeeds',
      () async {
        final notifier = container.read(chatMessagesProvider(9142001).notifier);
        final archive = await EncryptedHistoryArchive.open(1, 9142001);
        final rows = [for (var id = 1; id <= 300; id++) _message(id)];
        await archive.write(rows);
        expect(await notifier.loadAround(151), isTrue);
        // Centered read has only 299 rows around this boundary; use one extra
        // saved row so the next candidate exceeds the hard in-memory window.
        notifier.setFollowingLatest(true);
        for (var id = 301; id <= 304; id++) {
          notifier.addOptimisticLocalMessage(_message(id));
        }
        await notifier.flushHistoryArchive();
        expect(messages().length, 300);
        await Hive.lazyBox<String>('enc_history_archive_v1').close();
        notifier.addOptimisticLocalMessage(
          _message(305, text: 'keep on failed disk'),
        );
        await expectLater(
          notifier.flushHistoryArchive(),
          throwsA(isA<HiveError>()),
        );
        expect(messages().length, 301);
        expect(messages().last.content, 'keep on failed disk');
        await Hive.openLazyBox<String>('enc_history_archive_v1');
        await notifier.flushHistoryArchive();
        expect(messages().length, 300);
        expect((await archive.message(305))?.content, 'keep on failed disk');
        expect((await archive.message(1))?.content, 'Message 1');
      },
    );
    test(
      'TTL disposal and reopening restore the archived window and account bookmark',
      () async {
        final archive = await EncryptedHistoryArchive.open(1, 9142001);
        await archive.write([for (var id = 1; id <= 1200; id++) _message(id)]);
        container.dispose();
        WebSocketPushDispatcher.dispose();
        socket.close();
        socket = _Socket();
        final retention = ChatHistoryRetention(
          idleTtl: const Duration(milliseconds: 40),
        );
        addTearDown(retention.dispose);
        container = ProviderContainer(
          overrides: [
            meshPreferenceProvider.overrideWith(_InternetOnly.new),
            bluetoothMeshProvider.overrideWithValue(null),
            ordinaryE2eeProvider.overrideWithValue(null),
            authProvider.overrideWith(_Auth.new),
            chatsProvider.overrideWith(_Chats.new),
            webSocketClientProvider.overrideWithValue(socket),
            appSoundProvider.overrideWithValue(_NoopSound()),
            chatHistoryRetentionProvider.overrideWithValue(retention),
          ],
        );
        var subscription = container.listen(
          chatMessagesProvider(9142001),
          (_, _) {},
        );
        await _waitUntil(() => socket.histories.length == 1);
        socket.history(0, [for (var id = 1121; id <= 1200; id++) _message(id)]);
        await container.read(chatMessagesProvider(9142001).future);
        var notifier = container.read(chatMessagesProvider(9142001).notifier);
        await notifier.flushHistoryArchive();
        await notifier.loadAround(600);
        const bookmark = ChatHistoryAnchor(messageId: 603, fraction: 0.67);
        await notifier.saveScrollAnchor(bookmark);
        subscription.close();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await container.pump();
        expect(container.exists(chatMessagesProvider(9142001)), isFalse);
        subscription = container.listen(
          chatMessagesProvider(9142001),
          (_, _) {},
        );
        await _waitUntil(() => socket.histories.length == 2);
        socket.history(1, [for (var id = 1121; id <= 1200; id++) _message(id)]);
        await container.read(chatMessagesProvider(9142001).future);
        notifier = container.read(chatMessagesProvider(9142001).notifier);
        await notifier.flushHistoryArchive();
        expect(notifier.scrollAnchor, bookmark);
        expect(messages().any((m) => m.id == 603), isTrue);
        expect(messages().length, lessThanOrEqualTo(300));
        expect(notifier.window.followingLatest, isFalse);
        expect(notifier.window.hasNewer, isTrue);
        (container.read(authProvider.notifier) as _Auth).switchAccount(2);
        await _waitUntil(() => socket.histories.length == 3);
        socket.history(2, [_message(9000)]);
        await _waitUntil(() => messages().any((m) => m.id == 9000));
        expect(notifier.scrollAnchor, isNull);
        expect(await archive.readScrollAnchor(), bookmark);
        subscription.close();
      },
    );

    test(
      'a deleted saved anchor falls back to latest without losing history',
      () async {
        final archive = await EncryptedHistoryArchive.open(1, 9142001);
        await archive.write([for (var id = 1; id <= 600; id++) _message(id)]);
        await archive.writeScrollAnchor(
          const ChatHistoryAnchor(messageId: 200, fraction: 0.6),
        );
        await archive.write([], remove: {200});
        container.invalidate(chatMessagesProvider(9142001));
        await _waitUntil(() => socket.histories.length == 2);
        socket.history(1, [for (var id = 521; id <= 600; id++) _message(id)]);
        await _waitUntil(() => messages().any((m) => m.id == 600));
        final notifier = container.read(chatMessagesProvider(9142001).notifier);
        await notifier.flushHistoryArchive();
        expect(notifier.scrollAnchor, isNull);
        expect(notifier.window.followingLatest, isTrue);
        expect(await archive.readScrollAnchor(), isNull);
        expect((await archive.message(199))?.content, 'Message 199');
      },
    );

    test(
      'an early screen refresh waits for saved archive position initialization',
      () async {
        final archive = await EncryptedHistoryArchive.open(1, 9142001);
        await archive.write([for (var id = 1; id <= 600; id++) _message(id)]);
        const anchor = ChatHistoryAnchor(messageId: 200, fraction: 0.65);
        await archive.writeScrollAnchor(anchor);
        container.invalidate(chatMessagesProvider(9142001));
        final notifier = container.read(chatMessagesProvider(9142001).notifier);
        final refreshing = notifier.refresh();
        await _waitUntil(() => socket.histories.length == 2);
        socket.history(1, [for (var id = 521; id <= 600; id++) _message(id)]);
        await _waitUntil(() => socket.histories.length == 3);
        socket.history(2, [for (var id = 521; id <= 600; id++) _message(id)]);
        await refreshing;
        await notifier.flushHistoryArchive();
        expect(notifier.scrollAnchor, anchor);
        expect(notifier.window.followingLatest, isFalse);
        expect(messages().any((m) => m.id == 200), isTrue);
        expect(messages().length, lessThanOrEqualTo(300));
      },
    );

    test(
      'ordinary E2E leaves only ciphertext on wire and decrypts own ack and offline peer push',
      () async {
        container.dispose();
        WebSocketPushDispatcher.dispose();
        socket.close();
        await EncryptedMessageCache.clearAccount(1, []);
        final alice = OrdinaryKeys(
          1,
          '00000000-0000-4000-8000-000000000001',
          List.filled(32, 1),
          List.filled(32, 11),
        );
        final bob = OrdinaryKeys(
          3,
          '00000000-0000-4000-8000-000000000003',
          List.filled(32, 3),
          List.filled(32, 13),
        );
        final recovery = randomE2eBytes(),
            alicePublic = await alice.public(),
            bobPublic = await bob.public();
        FlutterSecureStorage.setMockInitialValues({
          'niosmess.ordinary.1.v1.keys': jsonEncode({
            'keys': alice.secret(),
            'recovery': OrdinaryCodec.recoveryCode(recovery),
            'old': [],
          }),
        });
        final backup = await OrdinaryCodec.backup(alice, recovery);
        final service = OrdinaryE2eeService(1, (action, {payload}) async {
          switch (payload!['op']) {
            case 'status':
              return {
                'enabled': true,
                'identity': alicePublic,
                'backup': backup,
              };
            case 'chat':
              return {
                'eligible': true,
                'required': true,
                'own': alicePublic,
                'peer': bobPublic,
              };
            case 'identity':
              if (payload['user_id'] == 1) {
                throw StateError('Own identity endpoint unavailable');
              }
              return bobPublic;
            default:
              throw StateError('Unexpected E2E action');
          }
        });
        await service.open();
        socket = _Socket();
        container = ProviderContainer(
          overrides: [
            meshPreferenceProvider.overrideWith(_InternetOnly.new),
            bluetoothMeshProvider.overrideWithValue(null),
            ordinaryE2eeProvider.overrideWithValue(service),
            authProvider.overrideWith(_Auth.new),
            chatsProvider.overrideWith(_Chats.new),
            webSocketClientProvider.overrideWithValue(socket),
            appSoundProvider.overrideWithValue(_NoopSound()),
          ],
        );
        addTearDown(service.dispose);
        await container.read(chatsProvider.future);
        container.listen(chatMessagesProvider(9142001), (_, _) {});
        await _waitUntil(() => socket.histories.isNotEmpty);
        socket.history(0, []);
        await container.read(chatMessagesProvider(9142001).future);
        final sending = container
            .read(chatMessagesProvider(9142001).notifier)
            .send('wire secret', replyToId: 7);
        await _waitUntil(() => socket.sentMessages.isNotEmpty);
        final wire = socket.outgoing.single;
        expect(wire.containsKey('content'), isFalse);
        expect(jsonEncode(wire), isNot(contains('wire secret')));
        final ciphertext = wire['e2ee_content'] as String;
        expect(
          (await OrdinaryCodec.decrypt(
            bob,
            alicePublic,
            ciphertext,
            9142001,
            1,
            reply: 7,
          ))['text'],
          'wire secret',
        );
        socket.sentMessages.single.complete({
          'id': 10,
          'chat_id': 9142001,
          'sender_id': 1,
          'reply_to_id': 7,
          'msg_type': 'text',
          'is_e2ee': true,
          'e2ee_content': ciphertext,
          'sent_at': '2026-10-18T10:00:00Z',
        });
        await sending;
        expect(messages().single.content, 'wire secret');
        expect(messages().single.isDecrypted, isTrue);
        // Equal plaintexts are separate encrypted operations. A push arriving
        // before the request acknowledgement must retain only its own row ID.
        final notifier = container.read(chatMessagesProvider(9142001).notifier);
        final firstSend = notifier.send('repeat');
        final secondSend = notifier.send('repeat');
        await _waitUntil(() => socket.sentMessages.length == 3);
        final pending = messages().where((m) => m.id < 0).toList();
        expect(pending, hasLength(2));
        final firstWire = socket.outgoing[1]['e2ee_content'] as String;
        final secondWire = socket.outgoing[2]['e2ee_content'] as String;
        expect(firstWire, isNot(secondWire));
        final firstLocal = pending.singleWhere(
          (m) => m.e2eeContent == firstWire,
        );
        final secondLocal = pending.singleWhere(
          (m) => m.e2eeContent == secondWire,
        );
        Map<String, dynamic> ack(int id, String cipher) => {
          'id': id,
          'chat_id': 9142001,
          'sender_id': 1,
          'msg_type': 'text',
          'is_e2ee': true,
          'e2ee_content': cipher,
          'sent_at': DateTime.now().toUtc().toIso8601String(),
        };
        socket.push(ApiMessage.fromJson(ack(12, firstWire)));
        await _waitUntil(() => messages().any((m) => m.id == 12));
        expect(
          messages().singleWhere((m) => m.id == 12).clientMessageId,
          firstLocal.clientMessageId,
        );
        expect(
          messages().singleWhere((m) => m.id == secondLocal.id).isSending,
          isTrue,
        );
        socket.sentMessages[1].complete(ack(12, firstWire));
        socket.sentMessages[2].complete(ack(13, secondWire));
        await Future.wait([firstSend, secondSend]);
        expect(messages().where((m) => m.content == 'repeat'), hasLength(2));
        expect(
          messages().singleWhere((m) => m.id == 13).clientMessageId,
          secondLocal.clientMessageId,
        );
        // Alice's other device is offline; Bob's ciphertext still arrives through the server.
        final incoming =
            await OrdinaryCodec.encrypt(bob, alicePublic, 9142001, {
              'text': 'caption',
              'file_key': base64Encode(List.filled(32, 77)),
              'name': 'sample.txt',
              'size': 12,
            });
        socket.push(
          ApiMessage.fromJson({
            'id': 11,
            'chat_id': 9142001,
            'sender_id': 3,
            'msg_type': 'media',
            'is_e2ee': true,
            'e2ee_content': incoming,
            'sent_at': '2026-10-18T10:01:00Z',
          }),
        );
        await _waitUntil(() => messages().any((m) => m.id == 11));
        final message = messages().singleWhere((m) => m.id == 11);
        expect(message.content, 'caption');
        expect(message.e2eeFileKey, base64Encode(List.filled(32, 77)));
        expect(message.mediaName, 'sample.txt');

        // Quick reply uses the same encryption and must report a failed send
        // back to the banner so its encrypted draft remains available.
        final reply = notifier.sendNotificationReply(
          'reply from notification',
          localId: '-987654321',
        );
        final failedReply = expectLater(reply, throwsStateError);
        await _waitUntil(() => socket.sentMessages.length == 4);
        expect(
          jsonEncode(socket.outgoing[3]),
          isNot(contains('reply from notification')),
        );
        socket.sentMessages[3].completeError(StateError('fixture_send_failed'));
        await failedReply;
        expect(
          messages().singleWhere((m) => m.id == -987654321).isFailed,
          isTrue,
        );
        final retry = notifier.sendNotificationReply(
          'reply from notification',
          localId: '-987654321',
        );
        await _waitUntil(() => socket.sentMessages.length == 5);
        final replyCipher = socket.outgoing[4]['e2ee_content'] as String;
        expect(
          (await OrdinaryCodec.decrypt(
            bob,
            alicePublic,
            replyCipher,
            9142001,
            1,
          ))['text'],
          'reply from notification',
        );
        socket.sentMessages[4].complete(ack(14, replyCipher));
        await retry;
        expect(
          messages().where((m) => m.content == 'reply from notification'),
          hasLength(1),
        );
        expect(messages().any((m) => m.id == -987654321), isFalse);
        expect(messages().singleWhere((m) => m.id == 14).isFailed, isFalse);

        // A signed own edit from another device can legitimately clear a media
        // caption. Verify actual codec authentication + service + provider,
        // rather than trusting an isDecrypted flag supplied by a fixture.
        final fileKey = base64Encode(List.filled(32, 79));
        final captionCipher =
            await OrdinaryCodec.encrypt(alice, bobPublic, 9142001, {
              'text': 'old own caption',
              'file_key': fileKey,
              'media_kind': 'media',
              'name': 'own-image.png',
              'size': 10,
            });
        Map<String, dynamic> ownMedia(String cipher, {String? editedAt}) => {
          'id': 15,
          'chat_id': 9142001,
          'sender_id': 1,
          'content': '',
          'msg_type': 'media',
          'is_e2ee': true,
          'e2ee_content': cipher,
          'media_url': 'https://fixture.invalid/own-image',
          'sent_at': '2026-10-18T10:02:00Z',
          'edited_at': ?editedAt,
        };
        socket.push(ApiMessage.fromJson(ownMedia(captionCipher)));
        await _waitUntil(() => messages().any((m) => m.id == 15));
        expect(
          messages().singleWhere((m) => m.id == 15).content,
          'old own caption',
        );
        final forged = ownMedia(captionCipher, editedAt: '2026-10-18T10:02:30Z')
          ..remove('e2ee_content')
          ..['is_decrypted'] = true;
        socket.pushes.add({'action': 'message_edited', 'payload': forged});
        await _waitUntil(
          () =>
              messages().singleWhere((m) => m.id == 15).editedAt ==
              DateTime.utc(2026, 10, 18, 10, 2, 30),
        );
        expect(
          messages().singleWhere((m) => m.id == 15).content,
          'old own caption',
        );
        await notifier.flushHistoryArchive();
        final beforeClear = await EncryptedHistoryArchive.open(1, 9142001);
        expect((await beforeClear.message(15))!.content, 'old own caption');
        final emptyCipher =
            await OrdinaryCodec.encrypt(alice, bobPublic, 9142001, {
              'text': '',
              'file_key': fileKey,
              'media_kind': 'media',
              'name': 'own-image.png',
              'size': 10,
            }, edit: 15);
        socket.push(
          ApiMessage.fromJson(
            ownMedia(emptyCipher, editedAt: '2026-10-18T10:03:00Z'),
          ),
          action: 'message_edited',
        );
        await _waitUntil(() {
          final row = messages().singleWhere((m) => m.id == 15);
          return row.e2eeContent == emptyCipher && row.isDecrypted;
        });
        final cleared = messages().singleWhere((m) => m.id == 15);
        expect(cleared.isDecrypted, isTrue);
        expect(cleared.hasMedia, isTrue);
        expect(cleared.content, isEmpty);
        expect(cleared.e2eeFileKey, fileKey);
        await notifier.flushHistoryArchive();
        final archive = await EncryptedHistoryArchive.open(1, 9142001);
        expect((await archive.message(15))!.content, isEmpty);
      },
    );
  });
}
