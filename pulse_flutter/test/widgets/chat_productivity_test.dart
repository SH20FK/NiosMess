import 'dart:async';
import 'package:flutter/material.dart';
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
        await tester.pumpWidget(
          app(const Scaffold(body: ChatProductivityBar())),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
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
