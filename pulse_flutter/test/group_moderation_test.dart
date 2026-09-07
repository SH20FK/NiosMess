import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/models/api/chat_actions_models.dart';
import 'package:pulse_flutter/models/api/chat_member_model.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';

class _MockWsClient extends WebSocketClient {
  _MockWsClient()
      : super(baseUrl: 'wss://test', readToken: () => 'test_token');

  String? lastAction;
  Map<String, dynamic>? lastPayload;
  dynamic mockResponse;

  @override
  Future<dynamic> request(
    String action, {
    Map<String, dynamic>? payload,
    Duration timeout = const Duration(seconds: 15),
    int maxRetries = 2,
  }) async {
    lastAction = action;
    lastPayload = payload;
    return mockResponse ?? <String, dynamic>{'status': 'ok'};
  }
}

void main() {
  group('Milestone 4: Group & Moderation Models', () {
    test('ChatSummary auto-delete formatted duration calculation', () {
      const summaryMin = ApiChatSummary(
        id: 1,
        name: 'Group 1',
        chatType: 'group',
        unreadCount: 0,
        membersCount: 1,
        autoDeleteSeconds: 120, // 2 mins
      );
      expect(summaryMin.formattedAutoDeleteDuration, '2 мин.');

      const summaryHours = ApiChatSummary(
        id: 2,
        name: 'Group 2',
        chatType: 'group',
        unreadCount: 0,
        membersCount: 1,
        autoDeleteSeconds: 7200, // 2 hours
      );
      expect(summaryHours.formattedAutoDeleteDuration, '2 ч.');

      const summaryDays = ApiChatSummary(
        id: 3,
        name: 'Group 3',
        chatType: 'group',
        unreadCount: 0,
        membersCount: 1,
        autoDeleteSeconds: 86400 * 7, // 7 days
      );
      expect(summaryDays.formattedAutoDeleteDuration, '7 дн.');

      const summaryMonths = ApiChatSummary(
        id: 4,
        name: 'Group 4',
        chatType: 'group',
        unreadCount: 0,
        membersCount: 1,
        autoDeleteSeconds: 2592000 * 3, // 3 months
      );
      expect(summaryMonths.formattedAutoDeleteDuration, '3 мес.');

      const summaryOff = ApiChatSummary(
        id: 5,
        name: 'Group 5',
        chatType: 'group',
        unreadCount: 0,
        membersCount: 1,
        autoDeleteSeconds: null,
      );
      expect(summaryOff.formattedAutoDeleteDuration, isNull);
    });

    test('ChatSummary private invite link generation', () {
      const summaryWithToken = ApiChatSummary(
        id: 10,
        name: 'Secret Circle',
        chatType: 'group',
        unreadCount: 0,
        membersCount: 1,
        isPrivate: true,
        inviteToken: 'abcXYZ123',
      );
      expect(summaryWithToken.privateInviteUrl, '/u/+abcXYZ123');

      const summaryPublic = ApiChatSummary(
        id: 11,
        name: 'Public Channel',
        chatType: 'channel',
        unreadCount: 0,
        membersCount: 1,
        isPrivate: false,
        inviteLink: '/join/public',
      );
      expect(summaryPublic.privateInviteUrl, '/join/public');
    });

    test('ChatCreateResult parses inviteToken correctly', () {
      final res = ChatCreateResult.fromJson({
        'chat_id': 12,
        'name': 'Private Club',
        'invite_token': 'secretTok99',
      });
      expect(res.chatId, 12);
      expect(res.inviteToken, 'secretTok99');
      expect(res.privateInviteUrl, '/u/+secretTok99');
    });

    test('ApiChatMember parses mute and ban fields with reason and duration', () {
      final member = ApiChatMember.fromJson({
        'user_id': 42,
        'username': 'troublemaker',
        'display_name': 'Trouble',
        'role': 'member',
        'is_muted': true,
        'is_banned': false,
        'muted_until': '2026-10-01T12:00:00.000Z',
        'mute_reason': 'Спам в чате',
      });

      expect(member.userId, 42);
      expect(member.isMuted, isTrue);
      expect(member.muteReason, 'Спам в чате');
      expect(member.mutedUntil, isNotNull);
      expect(member.isBanned, isFalse);
    });
  });

  group('Milestone 4: ChatRepository Moderation & Auto-delete', () {
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

    test('createChat sends is_private flag', () async {
      mockWs.mockResponse = {
        'chat_id': 77,
        'name': 'Secret Group',
        'invite_token': 'token77',
      };

      final result = await repository.createChat(
        name: 'Secret Group',
        chatType: 'group',
        isPrivate: true,
      );

      expect(mockWs.lastAction, 'create_group');
      expect(mockWs.lastPayload?['is_private'], isTrue);
      expect(result?.inviteToken, 'token77');
    });

    test('updateChat sets auto_delete_seconds and clearAutoDelete', () async {
      mockWs.mockResponse = {
        'id': 12,
        'name': 'Chat 12',
        'chat_type': 'group',
        'auto_delete_seconds': 86400,
      };

      await repository.updateChat(
        12,
        autoDeleteSeconds: 86400,
      );
      expect(mockWs.lastAction, 'update_chat');
      expect(mockWs.lastPayload?['auto_delete_seconds'], 86400);

      // Clear auto delete
      await repository.updateChat(
        12,
        clearAutoDelete: true,
      );
      expect(mockWs.lastPayload?['auto_delete_seconds'], isNull);
    });

    test('muteUser sends duration_seconds and reason', () async {
      await repository.muteUser(
        12,
        42,
        true,
        durationSeconds: 3600,
        reason: 'Флуд',
      );

      expect(mockWs.lastAction, 'mute_member');
      expect(mockWs.lastPayload?['chat_id'], 12);
      expect(mockWs.lastPayload?['user_id'], 42);
      expect(mockWs.lastPayload?['muted'], isTrue);
      expect(mockWs.lastPayload?['duration_seconds'], 3600);
      expect(mockWs.lastPayload?['reason'], 'Флуд');
    });

    test('banUser sends duration_seconds and reason', () async {
      await repository.banUser(
        12,
        42,
        true,
        durationSeconds: 86400,
        reason: 'Нарушение правил',
      );

      expect(mockWs.lastAction, 'ban_member');
      expect(mockWs.lastPayload?['chat_id'], 12);
      expect(mockWs.lastPayload?['user_id'], 42);
      expect(mockWs.lastPayload?['banned'], isTrue);
      expect(mockWs.lastPayload?['duration_seconds'], 86400);
      expect(mockWs.lastPayload?['reason'], 'Нарушение правил');
    });

    test('Support user protection prevents mute and ban', () async {
      expect(
        () => repository.muteUser(12, 1, true),
        throwsException,
      );

      expect(
        () => repository.banUser(12, 1, true),
        throwsException,
      );
    });
  });
}
