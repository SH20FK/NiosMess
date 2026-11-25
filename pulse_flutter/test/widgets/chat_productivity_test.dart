import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/models/chat_productivity.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/chat_productivity_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_codec.dart';
import 'package:pulse_flutter/widgets/chat_productivity.dart';
import 'package:pulse_flutter/widgets/chat/chat_filter_bar.dart';
import 'package:pulse_flutter/screens/settings_chats_screen.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';

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
  void change() => state = state.copyWith(
    session: const AuthSession(
      accessToken: 'two',
      userId: 2,
      username: 'two',
      displayName: 'Two',
    ),
  );
}

class _Chats extends ChatsNotifier {
  @override
  Future<List<ApiChatSummary>> build() async => [
    ApiChatSummary(
      id: 20,
      chatType: 'group',
      name: 'Group',
      unreadCount: 2,
      membersCount: 2,
      topicsEnabled: true,
      lastMessage: _message(1, 20),
    ),
    ApiChatSummary(
      id: 21,
      chatType: 'group',
      name: 'Bugs',
      unreadCount: 3,
      membersCount: 2,
      topicParentId: 20,
      lastMessage: _message(2, 21),
    ),
    const ApiChatSummary(
      id: 30,
      chatType: 'direct',
      name: 'Избранное',
      unreadCount: 0,
      membersCount: 1,
      isSaved: true,
    ),
  ];
  void readTopic() => state = AsyncData([
    for (final c in state.value!) c.id == 21 ? c.copyWith(unreadCount: 0) : c,
  ]);
}

ApiMessage _message(int id, int chat) => ApiMessage.fromJson({
  'id': id,
  'chat_id': chat,
  'sender_id': 2,
  'content': 'Message $id',
  'sent_at': DateTime.utc(2026, 10, 26, 10, id).toIso8601String(),
});

class _Folders extends ChatFoldersNotifier {
  @override
  Future<List<ChatFolder>> build() async => const [
    ChatFolder(id: 'folder', title: 'Work', types: ['group']),
  ];
}

class _MutableFolders extends ChatFoldersNotifier {
  List<ChatFolder> folders = const [
    ChatFolder(id: 'folder', title: 'Work', types: ['group']),
  ];
  @override
  Future<List<ChatFolder>> build() async => folders;
  void replace(List<ChatFolder> value) {
    folders = value;
    state = AsyncData(value);
  }
}

/// Serves scripted websocket answers and records every request.
class _ActionSocket extends WebSocketClient {
  _ActionSocket(this.handler)
    : super(baseUrl: 'https://fixture.invalid', readToken: () => 'fixture');
  final dynamic Function(String action, Map<String, dynamic> payload) handler;
  final requests = <(String, Map<String, dynamic>)>[];
  @override
  Future<dynamic> request(
    String action, {
    Map<String, dynamic>? payload,
    Duration timeout = const Duration(seconds: 15),
    int maxRetries = 2,
  }) async {
    final body = payload ?? const <String, dynamic>{};
    requests.add((action, body));
    return handler(action, body);
  }
}

class _Socket extends WebSocketClient {
  _Socket(this.answer)
    : super(baseUrl: 'https://fixture.invalid', readToken: () => 'fixture');
  final Completer<dynamic> answer;
  @override
  Future<dynamic> request(
    String action, {
    Map<String, dynamic>? payload,
    Duration timeout = const Duration(seconds: 15),
    int maxRetries = 2,
  }) => answer.future;
}

class _RetrySocket extends WebSocketClient {
  _RetrySocket()
    : super(baseUrl: 'https://fixture.invalid', readToken: () => 'fixture');
  final requests = <Map<String, dynamic>>[];
  @override
  Future<dynamic> request(
    String action, {
    Map<String, dynamic>? payload,
    Duration timeout = const Duration(seconds: 15),
    int maxRetries = 2,
  }) async {
    requests.add(payload!);
    if (requests.length == 1) throw StateError('Connection lost after commit');
    return {'jobs': []};
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'folder selection combines explicit chats and types, excludes topics and applies unread rule',
    () {
      const f = ChatFolder(
        id: 'f',
        title: 'Work',
        chatIds: [30],
        types: ['group'],
        unreadOnly: true,
      );
      expect(
        f.includes(
          const ApiChatSummary(
            id: 20,
            chatType: 'group',
            name: 'Group',
            unreadCount: 1,
            membersCount: 2,
          ),
        ),
        isTrue,
      );
      expect(
        f.includes(
          const ApiChatSummary(
            id: 21,
            chatType: 'group',
            name: 'Topic',
            unreadCount: 1,
            membersCount: 2,
            topicParentId: 20,
          ),
        ),
        isFalse,
      );
      expect(
        f.includes(
          const ApiChatSummary(
            id: 30,
            chatType: 'direct',
            name: 'Saved',
            unreadCount: 0,
            membersCount: 1,
          ),
        ),
        isFalse,
      );
      expect(ChatFolder.fromJson(f.toJson()).types, ['group']);
    },
  );
  test(
    'saved/topic metadata survives cached summaries and message updates',
    () {
      final c = ApiChatSummary.fromJson({
        'id': 4,
        'chat_type': 'direct',
        'name': 'User name',
        'is_saved': true,
        'topic_parent_id': 8,
        'topic_closed': true,
        'topics_enabled': true,
      });
      final restored = ApiChatSummary.fromJson(
        c.copyWith(unreadCount: 5).toJson(),
      );
      expect(restored.isSaved, isTrue);
      expect(restored.name, 'Избранное');
      expect(restored.topicParentId, 8);
      expect(restored.topicClosed, isTrue);
    },
  );
  test(
    'own-account encryption produces a readable self recipient without a second user',
    () async {
      final own = OrdinaryKeys.create(1), public = await own.public();
      final cipher = await OrdinaryCodec.encrypt(own, public, 30, {
        'text': 'Личная заметка',
      });
      final clear = await OrdinaryCodec.decrypt(own, public, cipher, 30, 1);
      expect(clear['text'], 'Личная заметка');
      final stranger = OrdinaryKeys.create(2);
      await expectLater(
        OrdinaryCodec.decrypt(stranger, public, cipher, 30, 1),
        throwsA(anything),
      );
    },
  );
  test(
    'topic inbox combines unread and latest content without duplicate chats',
    () async {
      final c = ProviderContainer(
        overrides: [chatsProvider.overrideWith(_Chats.new)],
      );
      addTearDown(c.dispose);
      await c.read(chatsProvider.future);
      final visible = c.read(visibleChatsProvider).requireValue;
      expect(visible.map((x) => x.id), [20, 30]);
      expect(visible.first.unreadCount, 5);
      expect(visible.first.lastMessage?.id, 2);
      (c.read(chatsProvider.notifier) as _Chats).readTopic();
      expect(c.read(visibleChatsProvider).requireValue.first.unreadCount, 2);
    },
  );
  test(
    'old-account productivity response cannot be accepted after account switch',
    () async {
      final pending = Completer<dynamic>();
      final actual = _Socket(pending);
      addTearDown(actual.close);
      final c = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_Auth.new),
          webSocketClientProvider.overrideWithValue(actual),
        ],
      );
      addTearDown(c.dispose);
      final result = c
          .read(chatProductivityRepositoryProvider)
          .call('list_chat_folders');
      final assertion = expectLater(result, throwsA(isA<StateError>()));
      (c.read(authProvider.notifier) as _Auth).change();
      pending.complete({'folders': []});
      await assertion;
    },
  );
  test(
    'lost schedule acknowledgement retries the same operation and payload',
    () async {
      final socket = _RetrySocket();
      addTearDown(socket.close);
      final c = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_Auth.new),
          chatsProvider.overrideWith(_Chats.new),
          webSocketClientProvider.overrideWithValue(socket),
        ],
      );
      addTearDown(c.dispose);
      await c.read(chatsProvider.future);
      final repo = c.read(chatProductivityRepositoryProvider);
      final due = DateTime.now().add(const Duration(hours: 1));
      await expectLater(
        repo.schedule(20, 'Text', due, operationId: 'same-operation'),
        throwsStateError,
      );
      await expectLater(
        repo.schedule(20, 'Changed text', due, operationId: 'same-operation'),
        throwsStateError,
      );
      expect(socket.requests.length, 1);
      await repo.schedule(20, 'Text', due, operationId: 'same-operation');
      expect(socket.requests.length, 2);
      expect(identical(socket.requests[0], socket.requests[1]), isTrue);
      expect(socket.requests.last['id'], 'same-operation');
    },
  );
  test(
    'folder save sends every selected chat and adopts the authoritative list',
    () async {
      final socket = _ActionSocket(
        (action, payload) => {
          'folders': [
            {
              'id': 'folder',
              'title': 'Work',
              'rules': {
                'chat_ids': [30, 999],
                'types': <String>[],
                'unread_only': false,
              },
              'position': 0,
              'version': 4,
            },
          ],
        },
      );
      addTearDown(socket.close);
      final c = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_Auth.new),
          webSocketClientProvider.overrideWithValue(socket),
        ],
      );
      addTearDown(c.dispose);
      await c.read(chatFoldersProvider.future);
      await c
          .read(chatFoldersProvider.notifier)
          .save(
            const ChatFolder(
              id: 'folder',
              title: 'Work',
              chatIds: [30, 999],
              version: 3,
            ),
          );
      final sent = socket.requests.single.$2;
      expect(sent['version'], 3);
      expect((sent['rules'] as Map)['chat_ids'], [30, 999]);
      expect(
        c.read(chatFoldersProvider).requireValue.single.version,
        4,
      );
    },
  );
  test('stale folder version is reported as a conflict', () async {
    final socket = _ActionSocket(
      (action, payload) => {
        'error': 'Папка изменена на другом устройстве. Обновите список',
      },
    );
    addTearDown(socket.close);
    final c = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_Auth.new),
        webSocketClientProvider.overrideWithValue(socket),
      ],
    );
    addTearDown(c.dispose);
    await c.read(chatFoldersProvider.future);
    await expectLater(
      c
          .read(chatFoldersProvider.notifier)
          .save(const ChatFolder(id: 'folder', title: 'Work', version: 2)),
      throwsA(isA<ChatFolderVersionConflict>()),
    );
    expect(socket.requests.single.$1, 'save_chat_folder');
    expect(socket.requests.single.$2['version'], 2);
  });
  test('reorder writes each position once and applies one final list', () async {
    final socket = _ActionSocket(
      (action, payload) => {
        'folders': [
          {
            'id': 'b',
            'title': 'B',
            'rules': {'chat_ids': <int>[], 'types': <String>[], 'unread_only': false},
            'position': 0,
            'version': 2,
          },
          {
            'id': 'a',
            'title': 'A',
            'rules': {'chat_ids': <int>[], 'types': <String>[], 'unread_only': false},
            'position': 1,
            'version': 2,
          },
        ],
      },
    );
    addTearDown(socket.close);
    final c = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_Auth.new),
        webSocketClientProvider.overrideWithValue(socket),
      ],
    );
    addTearDown(c.dispose);
    await c.read(chatFoldersProvider.future);
    await c.read(chatFoldersProvider.notifier).reorder(const [
      ChatFolder(id: 'b', title: 'B', version: 1),
      ChatFolder(id: 'a', title: 'A', version: 1),
    ]);
    expect(socket.requests.map((r) => r.$1), everyElement('save_chat_folder'));
    expect(socket.requests.map((r) => r.$2['position']), [0, 1]);
    expect(c.read(chatFoldersProvider).requireValue.first.id, 'b');
  });
  test('saved chat id is memoised for the account', () async {
    final c = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_Auth.new),
        chatsProvider.overrideWith(_Chats.new),
      ],
    );
    addTearDown(c.dispose);
    await c.read(chatsProvider.future);
    final repo = c.read(chatProductivityRepositoryProvider);
    expect(repo.cachedSavedChatId, isNull);
    expect((await repo.saved()).id, 30);
    expect(repo.cachedSavedChatId, 30);
  });
  test('folder selection survives a restart and dies with its folder', () async {
    SharedPreferences.setMockInitialValues({
      'chat_selected_folder_v1_1': 'folder',
    });
    final c = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_Auth.new),
        chatFoldersProvider.overrideWith(_MutableFolders.new),
      ],
    );
    addTearDown(c.dispose);
    await c.read(chatFoldersProvider.future);
    c.read(selectedChatFolderProvider);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(c.read(selectedChatFolderProvider), 'folder');

    (c.read(chatFoldersProvider.notifier) as _MutableFolders).replace(const []);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(c.read(selectedChatFolderProvider), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('chat_selected_folder_v1_1'), isNull);
  });
  testWidgets('chat folders are managed from chat settings', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_Auth.new),
          chatFoldersProvider.overrideWith(_Folders.new),
        ],
        child: const MaterialApp(
          locale: Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsChatsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Папки чатов').last);
    await tester.pumpAndSettle();
    expect(find.byType(ChatFoldersScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final brightness in Brightness.values) {
    testWidgets(
      'productivity bar, folder editor and topics fit 320px at 200% $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(320, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Widget app(Widget body) => ProviderScope(
          overrides: [
            authProvider.overrideWith(_Auth.new),
            chatsProvider.overrideWith(_Chats.new),
            chatFoldersProvider.overrideWith(_Folders.new),
            scheduledChatMessagesProvider.overrideWith(
              (ref, id) async => [
                ScheduledChatMessage(
                  id: 'job',
                  chatId: 20,
                  dueAt: DateTime(2026, 10, 27, 9),
                  kind: 'reminder',
                  payload: const {},
                  preview: 'Позвонить маме вечером',
                ),
              ],
            ),
            groupTopicsProvider.overrideWith(
              (ref, id) async => GroupTopics(id, true, const [
                ChatTopic(id: 20, title: 'Общее'),
                ChatTopic(
                  id: 21,
                  title: 'Ошибки и предложения',
                  unreadCount: 3,
                ),
              ]),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: body,
          ),
        );
        // The inbox scope row (folders replace the base types once configured)
        // replaced the old folder-only productivity bar.
        await tester.pumpWidget(app(const Scaffold(body: ChatFilterBar())));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey<String>('chat-filter-folder-folder')),
          findsOneWidget,
        );
        expect(find.text('Все'), findsOneWidget);
        // Folder management moved from the removed overflow menu to a
        // long-press on the "Все" pill.
        expect(
          find.byKey(const ValueKey<String>('chat-filter-more')),
          findsNothing,
        );
        await tester.longPress(
          find.byKey(const ValueKey<String>('chat-filter-all')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ChatFoldersScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        Navigator.of(tester.element(find.byType(ChatFoldersScreen))).pop();
        await tester.pumpAndSettle();
        await tester.pumpWidget(app(const Scaffold(body: ChatFolderEditor())));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(app(const GroupTopicsScreen(chatId: 20)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Создать тему'), findsOneWidget);
        await tester.tap(find.text('Создать тему'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(app(const ScheduledMessagesScreen()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(
          app(
            Scaffold(
              body: Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () => showScheduledMessageComposer(
                    context,
                    ref,
                    chatId: 20,
                    text: 'Текст',
                  ),
                  child: const Text('Open schedule'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open schedule'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Отложенная отправка'), findsOneWidget);
      },
    );
  }
}
