import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/models/api/chat_actions_models.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';

class _MockWsClient extends WebSocketClient {
  _MockWsClient()
      : super(baseUrl: 'wss://test', readToken: () => 'test_token');

  final List<String> dispatchedActions = <String>[];
  final List<Map<String, dynamic>?> dispatchedPayloads =
      <Map<String, dynamic>?>[];
  dynamic mockResponse;

  @override
  Future<dynamic> request(
    String action, {
    Map<String, dynamic>? payload,
    Duration timeout = const Duration(seconds: 15),
    int maxRetries = 2,
  }) async {
    dispatchedActions.add(action);
    dispatchedPayloads.add(payload);
    return mockResponse ?? <String, dynamic>{'status': 'ok'};
  }
}

void main() {
  late _MockWsClient mockWs;
  late ProviderContainer container;
  late ChatRepository repository;

  setUp(() {
    mockWs = _MockWsClient();
    container = ProviderContainer(
      overrides: [
        webSocketClientProvider.overrideWithValue(mockWs),
      ],
    );
    repository = container.read(chatRepositoryProvider);
  });

  tearDown(() {
    container.dispose();
  });

  group('Chat Creation & Direct Restoration Tests', () {
    test('createChat handles group creation payload correctly', () async {
      mockWs.mockResponse = <String, dynamic>{
        'chat_id': 42,
        'name': 'Cool Devs',
        'chat_type': 'group',
      };

      final ChatCreateResult? result = await repository.createChat(
        name: 'Cool Devs',
        chatType: 'group',
        description: 'Engineering discussions',
        isPrivate: true,
      );

      expect(result, isNotNull);
      expect(result!.chatId, 42);
      expect(mockWs.dispatchedActions.last, 'create_group');
      final Map<String, dynamic>? payload = mockWs.dispatchedPayloads.last;
      expect(payload?['name'], 'Cool Devs');
      expect(payload?['chat_type'], 'group');
      expect(payload?['description'], 'Engineering discussions');
      expect(payload?['is_private'], isTrue);
    });

    test('createChat handles channel creation with comments and public username', () async {
      mockWs.mockResponse = <String, dynamic>{
        'chat_id': 108,
        'name': 'News Broadcast',
        'chat_type': 'channel',
      };

      final ChatCreateResult? result = await repository.createChat(
        name: 'News Broadcast',
        chatType: 'channel',
        description: 'Public announcements',
        username: 'news_feed',
        commentsEnabled: true,
        isPrivate: false,
      );

      expect(result, isNotNull);
      expect(result!.chatId, 108);
      expect(mockWs.dispatchedActions.last, 'create_group');
      final Map<String, dynamic>? payload = mockWs.dispatchedPayloads.last;
      expect(payload?['name'], 'News Broadcast');
      expect(payload?['chat_type'], 'channel');
      expect(payload?['username'], 'news_feed');
      expect(payload?['comments_enabled'], isTrue);
      expect(payload?['is_private'], isFalse);
    });

    test('inviteUsers iterates and invites all candidate user IDs', () async {
      mockWs.mockResponse = <String, dynamic>{'status': 'ok'};

      await repository.inviteUsers(42, <int>[101, 102, 103]);

      expect(mockWs.dispatchedActions.length, 3);
      for (final String action in mockWs.dispatchedActions) {
        expect(action, 'invite_user');
      }
      expect(mockWs.dispatchedPayloads[0]?['chat_id'], 42);
      expect(mockWs.dispatchedPayloads[0]?['user_id'], 101);
      expect(mockWs.dispatchedPayloads[1]?['user_id'], 102);
      expect(mockWs.dispatchedPayloads[2]?['user_id'], 103);
    });

    test('openDirectChatByUsername requests open_direct to restore chat membership', () async {
      mockWs.mockResponse = <String, dynamic>{
        'chat_id': 777,
        'status': 'opened',
      };

      final DirectChatOpenResult? result =
          await repository.openDirectChatByUsername('alice');

      expect(result, isNotNull);
      expect(result!.chatId, 777);
      expect(mockWs.dispatchedActions.last, 'open_direct');
      expect(mockWs.dispatchedPayloads.last?['username'], 'alice');
      expect(mockWs.dispatchedPayloads.last?['is_secret'], isFalse);
    });

    test('leaveChat dispatches leave_chat action', () async {
      mockWs.mockResponse = <String, dynamic>{'status': 'left'};

      await repository.leaveChat(777);

      expect(mockWs.dispatchedActions.last, 'leave_chat');
      expect(mockWs.dispatchedPayloads.last?['chat_id'], 777);
    });
  });
}
