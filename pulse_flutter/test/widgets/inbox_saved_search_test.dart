import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/features/chats/presentation/inbox_search_screen.dart';
import 'package:pulse_flutter/features/chats/presentation/saved_messages_search.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState.initial().copyWith(
    session: const AuthSession(
      accessToken: 'fixture',
      userId: 1,
      username: 'my_user',
      displayName: 'My Name',
    ),
  );
  void switchAccount() => state = state.copyWith(
    session: const AuthSession(
      accessToken: 'second',
      userId: 2,
      username: 'other',
      displayName: 'Other',
    ),
  );
}

class _Chats extends ChatsNotifier {
  @override
  Future<List<ApiChatSummary>> build() async => const [
    ApiChatSummary(
      id: 30,
      chatType: 'direct',
      name: 'my_user',
      username: 'my_user',
      unreadCount: 0,
      membersCount: 1,
      isSaved: true,
    ),
  ];
}

class _NoSavedChats extends ChatsNotifier {
  @override
  Future<List<ApiChatSummary>> build() async => const [];
  @override
  void upsertChat(ApiChatSummary chat) => state = AsyncData([chat]);
}

class _AccountChats extends ChatsNotifier {
  @override
  Future<List<ApiChatSummary>> build() async {
    final id = ref.watch(authProvider.select((value) => value.session?.userId));
    state = const AsyncData([]);
    return id == 1
        ? const [
            ApiChatSummary(
              id: 30,
              chatType: 'direct',
              name: 'my_user',
              username: 'my_user',
              unreadCount: 0,
              membersCount: 1,
              isSaved: true,
            ),
          ]
        : const [];
  }
}

class _DelayedSearchSocket extends WebSocketClient {
  _DelayedSearchSocket()
    : super(baseUrl: 'https://fixture.invalid', readToken: () => 'fixture');
  final first = Completer<dynamic>();
  final second = Completer<dynamic>();
  int calls = 0;
  @override
  Future<dynamic> request(
    String action, {
    Map<String, dynamic>? payload,
    Duration timeout = const Duration(seconds: 15),
    int maxRetries = 2,
  }) => ++calls == 1 ? first.future : second.future;
}

class _SearchSocket extends WebSocketClient {
  _SearchSocket()
    : super(baseUrl: 'https://fixture.invalid', readToken: () => 'fixture');
  bool failSearch = false;
  @override
  Future<dynamic> request(
    String action, {
    Map<String, dynamic>? payload,
    Duration timeout = const Duration(seconds: 15),
    int maxRetries = 2,
  }) async {
    if (action == 'open_saved_messages') {
      return {
        'id': 30,
        'chat_type': 'direct',
        'name': 'my_user',
        'is_saved': true,
        'members_count': 1,
      };
    }
    if (failSearch) throw StateError('offline fixture');
    return {
      'users': [
        {'id': 1, 'username': 'my_user', 'display_name': 'My Name'},
        {'id': 2, 'username': 'my_user_fan', 'display_name': 'Other'},
      ],
      'chats': [
        {
          'id': 30,
          'chat_type': 'direct',
          'name': 'my_user',
          'username': 'my_user',
        },
      ],
      'messages': [],
    };
  }
}

void main() {
  testWidgets('late search from another account is discarded', (tester) async {
    final socket = _DelayedSearchSocket();
    addTearDown(socket.close);
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_Auth.new),
        chatsProvider.overrideWith(_AccountChats.new),
        webSocketClientProvider.overrideWithValue(socket),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: InboxSearchScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'my_user');
    await tester.pump(const Duration(milliseconds: 250));
    expect(socket.calls, 1);
    (container.read(authProvider.notifier) as _Auth).switchAccount();
    await tester.pump();
    socket.first.complete({
      'users': [
        {
          'id': 3,
          'username': 'old_private',
          'display_name': 'Old account result',
        },
      ],
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Old account result'), findsNothing);
    expect(find.text('Saved Messages'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test(
    'saved search matches username and localized title without empty @ queries',
    () {
      bool matches(String query) => matchesSavedMessagesQuery(
        query: query,
        username: 'My_User',
        displayName: 'My Name',
        savedTitle: 'Избранное',
      );
      expect(matches('@my_user'), isTrue);
      expect(matches('избран'), isTrue);
      expect(matches('my name'), isTrue);
      expect(matches('@'), isFalse);
      expect(matches('someone else'), isFalse);
    },
  );
  testWidgets(
    'own username finds saved messages without exposing own profile',
    (tester) async {
      final socket = _SearchSocket();
      addTearDown(socket.close);
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const InboxSearchScreen()),
          GoRoute(
            path: '/chat/:id',
            builder: (_, state) => Text('chat ${state.pathParameters['id']}'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(_Auth.new),
            chatsProvider.overrideWith(_Chats.new),
            webSocketClientProvider.overrideWithValue(socket),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField), '@my_user');
      await tester.pump();
      expect(find.text('Saved Messages'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(find.text('Saved Messages'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ListTile),
          matching: find.text('@my_user'),
        ),
        findsNothing,
      );
      expect(find.text('My Name'), findsNothing);
      expect(find.text('Other'), findsOneWidget);
      await tester.tap(find.text('Saved Messages'));
      await tester.pumpAndSettle();
      expect(find.text('chat 30'), findsOneWidget);
    },
  );

  testWidgets('saved chat remains searchable when the server is offline', (
    tester,
  ) async {
    final socket = _SearchSocket()..failSearch = true;
    addTearDown(socket.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_Auth.new),
          chatsProvider.overrideWith(_Chats.new),
          webSocketClientProvider.overrideWithValue(socket),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: InboxSearchScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'my_user');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(find.text('Saved Messages'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ListTile),
        matching: find.text('my_user'),
      ),
      findsNothing,
    );
  });

  testWidgets('search offers saved messages before the chat exists locally', (
    tester,
  ) async {
    final socket = _SearchSocket();
    addTearDown(socket.close);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const InboxSearchScreen()),
        GoRoute(
          path: '/chat/:id',
          builder: (_, state) => Text('chat ${state.pathParameters['id']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_Auth.new),
          chatsProvider.overrideWith(_NoSavedChats.new),
          webSocketClientProvider.overrideWithValue(socket),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'my_user');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(find.text('Saved Messages'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ListTile),
        matching: find.text('my_user'),
      ),
      findsNothing,
    );
    await tester.tap(find.text('Saved Messages'));
    await tester.pumpAndSettle();
    expect(find.text('chat 30'), findsOneWidget);
  });
}
