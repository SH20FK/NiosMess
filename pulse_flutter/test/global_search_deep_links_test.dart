import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/models/api/search_models.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/search_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/widgets/chat/chat_search_bar.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState.initial();
}

class MockWebSocketClient extends WebSocketClient {
  MockWebSocketClient()
      : super(baseUrl: 'wss://test', readToken: () => 'token');

  final List<Map<String, dynamic>> sentRequests = <Map<String, dynamic>>[];
  dynamic nextResponse;

  @override
  bool get isConnected => true;

  @override
  Stream<Map<String, dynamic>> get pushStream =>
      const Stream<Map<String, dynamic>>.empty();

  @override
  Future<dynamic> request(
    String action, {
    Map<String, dynamic>? payload,
    Duration timeout = const Duration(seconds: 10),
    int maxRetries = 2,
  }) async {
    sentRequests.add(<String, dynamic>{
      'action': action,
      'payload': payload,
    });
    return nextResponse ?? <String, dynamic>{};
  }
}

void main() {
  group('ApiSearchResult 4-Section Global Search Model', () {
    test('parses users, chats, messages, and posts correctly', () {
      final json = <String, dynamic>{
        'users': [
          {
            'id': 1,
            'username': 'alice',
            'display_name': 'Alice Smith',
            'bio': 'Developer',
          }
        ],
        'chats': [
          {
            'id': 10,
            'chat_type': 'group',
            'name': 'Flutter Devs',
            'members_count': 150,
          }
        ],
        'messages': [
          {
            'id': 100,
            'chat_id': 10,
            'content': 'Hello Flutter world',
            'sender_display_name': 'Alice Smith',
          }
        ],
        'posts': [
          {
            'id': 501,
            'content': 'Check out NiosMess 3.0!',
            'author': {
              'id': 1,
              'username': 'alice',
              'display_name': 'Alice Smith',
            },
            'likes_count': 25,
            'dislikes_count': 0,
            'comments_count': 5,
          }
        ],
      };

      final result = ApiSearchResult.fromJson(json);

      expect(result.isEmpty, false);
      expect(result.users.length, 1);
      expect(result.users.first.username, 'alice');
      expect(result.chats.length, 1);
      expect(result.chats.first.name, 'Flutter Devs');
      expect(result.messages.length, 1);
      expect(result.messages.first.content, 'Hello Flutter world');
      expect(result.posts.length, 1);
      expect(result.posts.first.content, 'Check out NiosMess 3.0!');
      expect(result.posts.first.author.username, 'alice');
    });

    test('empty result reports isEmpty true', () {
      const result = ApiSearchResult.empty();
      expect(result.isEmpty, true);
      expect(result.users, isEmpty);
      expect(result.chats, isEmpty);
      expect(result.messages, isEmpty);
      expect(result.posts, isEmpty);
    });
  });

  group('DebouncedSearchNotifier with 4 categories', () {
    test('search sends action: search with query parameter', () async {
      final mockWs = MockWebSocketClient();
      mockWs.nextResponse = <String, dynamic>{
        'users': [],
        'chats': [],
        'messages': [],
        'posts': [
          {
            'id': 88,
            'content': 'NiosGram announcement',
            'author': {'id': 2, 'username': 'admin', 'display_name': 'Admin'},
          }
        ],
      };

      final container = ProviderContainer(
        overrides: [
          webSocketClientProvider.overrideWithValue(mockWs),
          authProvider.overrideWith(() => _FakeAuthNotifier()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(chatListSearchProvider.notifier);
      notifier.search('announcement');

      // Wait for debounce timer (300ms)
      await Future<void>.delayed(const Duration(milliseconds: 350));

      final req = mockWs.sentRequests
          .firstWhere((Map<String, dynamic> r) => r['action'] == 'search');
      expect(req['action'], 'search');
      expect(req['payload']['q'], 'announcement');

      final result = container.read(chatListSearchProvider).value;
      expect(result, isNotNull);
      expect(result!.posts.length, 1);
      expect(result.posts.first.content, 'NiosGram announcement');
    });
  });

  group('Deep Link Scheme & Path Parsing', () {
    test('parses niosmess:// scheme paths correctly', () {
      final uri1 = Uri.parse('niosmess://u/alice');
      String path1 = uri1.path;
      if (uri1.scheme == 'niosmess') {
        if (uri1.host.isNotEmpty && !path1.startsWith('/${uri1.host}')) {
          path1 = '/${uri1.host}$path1';
        }
      }
      expect(path1, '/u/alice');

      final uri2 = Uri.parse('niosmess://u/+INVITE_TOKEN_XYZ');
      String path2 = uri2.path;
      if (uri2.scheme == 'niosmess') {
        if (uri2.host.isNotEmpty && !path2.startsWith('/${uri2.host}')) {
          path2 = '/${uri2.host}$path2';
        }
      }
      expect(path2, '/u/+INVITE_TOKEN_XYZ');

      final uri3 = Uri.parse('niosmess://g/creator_username');
      String path3 = uri3.path;
      if (uri3.scheme == 'niosmess') {
        if (uri3.host.isNotEmpty && !path3.startsWith('/${uri3.host}')) {
          path3 = '/${uri3.host}$path3';
        }
      }
      expect(path3, '/g/creator_username');
    });
  });

  group('ChatSearchBar Widget', () {
    testWidgets('renders search anchor bar with category chips', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChatSearchBar(),
            ),
          ),
        ),
      );

      expect(find.byType(ChatSearchBar), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    });
  });
}
