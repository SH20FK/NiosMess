import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_codec.dart';
import 'dart:async';
import 'package:pulse_flutter/models/interactive_message.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_io/io.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/core/storage/encrypted_message_cache.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/providers/websocket_dispatcher_provider.dart';
import 'package:pulse_flutter/services/bluetooth_mesh/bluetooth_mesh_service.dart';
import 'package:pulse_flutter/services/bluetooth_mesh/mesh_preferences.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_service.dart';

class _Auth extends AuthNotifier {
  bool signingOut = false;
  @override
  bool get isLoggingOut => signingOut;
  @override
  AuthState build() => const AuthState.initial().copyWith(
    session: const AuthSession(
      accessToken: 'fixture-old',
      userId: 1,
      username: 'one',
      displayName: 'One',
    ),
  );
  void replaceToken() => state = state.copyWith(
    session: state.session!.copyWith(accessToken: 'fixture-new'),
  );
}

class _Chats extends ChatsNotifier {
  @override
  Future<List<ApiChatSummary>> build() async => const [
    ApiChatSummary(
      id: 42,
      chatType: 'direct',
      name: 'Fixture',
      unreadCount: 0,
      membersCount: 2,
    ),
  ];
}

class _MeshOff extends MeshPreference {
  @override
  bool build() => false;
}

class _PendingKeys extends OrdinaryE2eeService {
  _PendingKeys() : super(1, (action, {payload}) async => <String, dynamic>{});
  final pending = Completer<E2eJson?>();
  bool started = false;
  @override
  Future<E2eJson?> prepare(int chatId, {bool force = false}) {
    started = true;
    return pending.future;
  }
}

Map<String, dynamic> _existing({String content = 'initial fixture'}) => {
  'id': 1,
  'chat_id': 42,
  'sender_id': 1,
  'content': content,
  'msg_type': 'text',
  'sent_at': '2026-10-26T10:00:00Z',
};

class _Socket extends WebSocketClient {
  _Socket() : super(baseUrl: 'https://fixture.invalid', readToken: () => null);
  int sends = 0;
  int edits = 0;
  int updates = 0;
  bool failEdit = false;
  @override
  Future<dynamic> request(
    String action, {
    Map<String, dynamic>? payload,
    Duration timeout = const Duration(seconds: 15),
    int maxRetries = 2,
  }) async {
    if (action == 'history') {
      return {
        'messages': [_existing()],
      };
    }
    if (action == 'send_message') sends++;
    if (action == 'interactive_update') updates++;
    if (action == 'edit_message') {
      edits++;
      if (failEdit) throw StateError('fixture edit failure');
      return _existing(content: '');
    }
    return <String, dynamic>{};
  }
}

class _Sound extends SoundService {
  @override
  Future<void> playEvent(SoundEvent event, {double? volume}) async {}
}

Future<void> _until(bool Function() predicate) async {
  for (var i = 0; i < 100 && !predicate(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(predicate(), isTrue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final replaceToken in [false, true]) {
    test(
      'pending key preparation cannot send after ${replaceToken ? 'token replacement' : 'logout begins'}',
      () async {
        SharedPreferences.setMockInitialValues({});
        FlutterSecureStorage.setMockInitialValues({});
        EncryptedMessageCache.resetMemoryForTesting();
        final directory = await Directory.systemTemp.createTemp(
          'send-account-fence-',
        );
        Hive.init(directory.path);
        final socket = _Socket(), keys = _PendingKeys();
        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith(_Auth.new),
            chatsProvider.overrideWith(_Chats.new),
            webSocketClientProvider.overrideWithValue(socket),
            ordinaryE2eeProvider.overrideWithValue(keys),
            meshPreferenceProvider.overrideWith(_MeshOff.new),
            bluetoothMeshProvider.overrideWithValue(null),
            appSoundProvider.overrideWithValue(_Sound()),
          ],
        );
        try {
          container.listen(chatMessagesProvider(42), (_, _) {});
          await container.read(chatMessagesProvider(42).future);
          var saved = false;
          final sending = container
              .read(chatMessagesProvider(42).notifier)
              .send(
                'durable pending fixture',
                onLocalSaved: () => saved = true,
              );
          await _until(() => keys.started);
          expect(saved, isTrue);
          final auth = container.read(authProvider.notifier) as _Auth;
          if (replaceToken) {
            auth.replaceToken();
          } else {
            auth.signingOut = true;
          }
          keys.pending.complete(null);
          await sending;
          expect(socket.sends, 0);
          final archive = await EncryptedHistoryArchive.open(1, 42);
          expect(
            (await archive.read(
              limit: 20,
            )).any((m) => m.content == 'durable pending fixture'),
            isTrue,
          );
        } finally {
          final notifier = container.exists(chatMessagesProvider(42))
              ? container.read(chatMessagesProvider(42).notifier)
              : null;
          await notifier?.flushHistoryArchive();
          container.dispose();
          await notifier?.drainCacheWrites();
          WebSocketPushDispatcher.dispose();
          socket.close();
          keys.dispose();
          await Hive.close();
          await directory.delete(recursive: true);
        }
      },
    );
  }
  for (final action in ['edit', 'interactive']) {
    for (final replaceToken in [false, true]) {
      test(
        '$action pending prepare cannot cross ${replaceToken ? 'token' : 'logout'} boundary',
        () async {
          SharedPreferences.setMockInitialValues({});
          FlutterSecureStorage.setMockInitialValues({});
          EncryptedMessageCache.resetMemoryForTesting();
          final directory = await Directory.systemTemp.createTemp(
            'action-account-fence-',
          );
          Hive.init(directory.path);
          final socket = _Socket(), keys = _PendingKeys();
          final container = ProviderContainer(
            overrides: [
              authProvider.overrideWith(_Auth.new),
              chatsProvider.overrideWith(_Chats.new),
              webSocketClientProvider.overrideWithValue(socket),
              ordinaryE2eeProvider.overrideWithValue(keys),
              meshPreferenceProvider.overrideWith(_MeshOff.new),
              bluetoothMeshProvider.overrideWithValue(null),
              appSoundProvider.overrideWithValue(_Sound()),
            ],
          );
          try {
            container.listen(chatMessagesProvider(42), (_, _) {});
            await container.read(chatMessagesProvider(42).future);
            final notifier = container.read(chatMessagesProvider(42).notifier);
            final content = InteractiveMessage.encode({
              'kind': 'update',
              'document': 'fixture-doc',
              'root': 1,
              'definition': List.filled(64, 'a').join(),
              'action': 'vote',
              'choices': [0],
            }, 'vote');
            final operation = action == 'edit'
                ? notifier.editMessage(1, 'edited fixture')
                : notifier.sendInteractiveUpdate(
                    content,
                    rootId: 1,
                    encryptedRoot: false,
                  );
            final checked = action == 'interactive'
                ? expectLater(operation, throwsStateError)
                : operation;
            await _until(() => keys.started);
            final auth = container.read(authProvider.notifier) as _Auth;
            if (replaceToken) {
              auth.replaceToken();
            } else {
              auth.signingOut = true;
            }
            keys.pending.complete(null);
            await checked;
            expect(socket.edits, 0);
            expect(socket.updates, 0);
            await notifier.flushHistoryArchive();
          } finally {
            final notifier = container.exists(chatMessagesProvider(42))
                ? container.read(chatMessagesProvider(42).notifier)
                : null;
            await notifier?.flushHistoryArchive();
            container.dispose();
            await notifier?.drainCacheWrites();
            WebSocketPushDispatcher.dispose();
            socket.close();
            keys.dispose();
            await Hive.close();
            await directory.delete(recursive: true);
          }
        },
      );
    }
  }
  for (final fails in [false, true]) {
    test(
      'own edit ${fails ? 'failure propagates and restores text' : 'empty ACK preserves original and archive'}',
      () async {
        SharedPreferences.setMockInitialValues({});
        FlutterSecureStorage.setMockInitialValues({});
        EncryptedMessageCache.resetMemoryForTesting();
        final directory = await Directory.systemTemp.createTemp(
          'edit-original-',
        );
        Hive.init(directory.path);
        final socket = _Socket()..failEdit = fails;
        final keys = _PendingKeys();
        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith(_Auth.new),
            chatsProvider.overrideWith(_Chats.new),
            webSocketClientProvider.overrideWithValue(socket),
            ordinaryE2eeProvider.overrideWithValue(keys),
            meshPreferenceProvider.overrideWith(_MeshOff.new),
            bluetoothMeshProvider.overrideWithValue(null),
            appSoundProvider.overrideWithValue(_Sound()),
          ],
        );
        try {
          container.listen(chatMessagesProvider(42), (_, _) {});
          await container.read(chatMessagesProvider(42).future);
          final notifier = container.read(chatMessagesProvider(42).notifier);
          final operation = notifier.editMessage(1, 'edited original fixture');
          final checked = fails
              ? expectLater(operation, throwsStateError)
              : operation;
          await _until(() => keys.started);
          keys.pending.complete(null);
          await checked;
          final expected = fails
              ? 'initial fixture'
              : 'edited original fixture';
          expect(
            container
                .read(chatMessagesProvider(42))
                .requireValue
                .single
                .content,
            expected,
          );
          await notifier.flushHistoryArchive();
          final archive = await EncryptedHistoryArchive.open(1, 42);
          expect((await archive.read(limit: 20)).single.content, expected);
        } finally {
          final notifier = container.exists(chatMessagesProvider(42))
              ? container.read(chatMessagesProvider(42).notifier)
              : null;
          await notifier?.flushHistoryArchive();
          container.dispose();
          await notifier?.drainCacheWrites();
          WebSocketPushDispatcher.dispose();
          socket.close();
          keys.dispose();
          await Hive.close();
          await directory.delete(recursive: true);
        }
      },
    );
  }
}
