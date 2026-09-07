import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/models/api/badge_model.dart';
import 'package:pulse_flutter/models/api/call_models.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:pulse_flutter/services/calls/call_session_types.dart';
import 'package:pulse_flutter/services/calls/call_starter.dart';

void main() {
  group('Milestone 4: WebRTC Calls Gateway & Quotas', () {
    test('ApiCallGatewayInfo parses parameters from JSON', () {
      final json = <String, dynamic>{
        'call_access_token': 'test_token_abc_123',
        'signal_url': 'wss://signal.ni-os.ru/ws',
        'ice_servers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {
            'urls': 'turn:turn.ni-os.ru:3478',
            'username': 'user',
            'credential': 'pwd'
          }
        ],
        'max_video_height': 720,
        'max_duration_seconds': 3600,
      };

      final info = ApiCallGatewayInfo.fromJson(json);
      expect(info.callAccessToken, 'test_token_abc_123');
      expect(info.signalUrl, 'wss://signal.ni-os.ru/ws');
      expect(info.iceServers.length, 2);
      expect(info.maxVideoHeight, 720);
      expect(info.maxDurationSeconds, 3600);
    });

    test('ApiCallGatewayInfo defaults: standard user gets 480p and 30 minutes', () {
      final standard = ApiCallGatewayInfo.defaultFor(
        isCallsTester: false,
        token: 'std_token',
        signalUrl: 'wss://signal.ni-os.ru',
      );
      expect(standard.maxVideoHeight, 480);
      expect(standard.maxDurationSeconds, 1800); // 30 minutes
      expect(standard.callAccessToken, 'std_token');
    });

    test('ApiCallGatewayInfo defaults: Calls Tester gets 720p and unlimited duration', () {
      final tester = ApiCallGatewayInfo.defaultFor(
        isCallsTester: true,
        token: 'tester_token',
        signalUrl: 'wss://signal.ni-os.ru',
      );
      expect(tester.maxVideoHeight, 720);
      expect(tester.maxDurationSeconds, isNull); // unlimited
      expect(tester.callAccessToken, 'tester_token');
    });

    test('ApiProfile correctly identifies isCallsTester from badges', () {
      const regularProfile = ApiProfile(
        id: 1,
        username: 'alice',
        displayName: 'Alice',
        bio: '',
        badges: [
          ApiBadge(id: 1, name: 'early_adopter', icon: '⭐', color: 'primary', description: 'Early Adopter'),
        ],
      );
      expect(regularProfile.isCallsTester, isFalse);

      const testerProfile = ApiProfile(
        id: 2,
        username: 'bob',
        displayName: 'Bob',
        bio: '',
        badges: [
          ApiBadge(id: 2, name: 'calls_tester', icon: '📞', color: 'green', description: 'Calls Tester'),
        ],
      );
      expect(testerProfile.isCallsTester, isTrue);
    });

    test('ApiCallInitiateResult parses nested gateway payload', () {
      final json = <String, dynamic>{
        'call_id': 101,
        'chat_id': 42,
        'status': 'ringing',
        'call_type': 'video',
        'message': 'OK',
        'payload': {
          'call_access_token': 'gate_tok_777',
          'signal_url': 'wss://c.ni-os.ru/signal',
          'ice_servers': [
            {'urls': 'stun:stun.ni-os.ru:3478'}
          ],
          'max_video_height': 480,
          'max_duration_seconds': 1800,
        }
      };

      final result = ApiCallInitiateResult.fromJson(json);
      expect(result.callId, 101);
      expect(result.chatId, 42);
      expect(result.gatewayInfo, isNotNull);
      expect(result.gatewayInfo!.callAccessToken, 'gate_tok_777');
      expect(result.gatewayInfo!.signalUrl, 'wss://c.ni-os.ru/signal');
      expect(result.gatewayInfo!.maxVideoHeight, 480);
      expect(result.gatewayInfo!.maxDurationSeconds, 1800);
    });
  });

  group('Milestone 4: Bot Restrictions & Listener Fallback', () {
    test('ApiChatSummary isBotChat identifies bot usernames and badges', () {
      const botChatByUsername = ApiChatSummary(
        id: 10,
        chatType: 'direct',
        name: 'Help Bot',
        username: 'help_bot',
        unreadCount: 0,
        membersCount: 2,
      );
      expect(botChatByUsername.isBotChat, isTrue);

      const botChatByBadge = ApiChatSummary(
        id: 11,
        chatType: 'direct',
        name: 'Assistant',
        unreadCount: 0,
        membersCount: 2,
        partnerBadges: [
          ApiBadge(id: 3, name: 'bot', icon: '🤖', color: 'blue', description: 'Official Bot'),
        ],
      );
      expect(botChatByBadge.isBotChat, isTrue);

      const humanChat = ApiChatSummary(
        id: 12,
        chatType: 'direct',
        name: 'Alice',
        username: 'alice',
        unreadCount: 0,
        membersCount: 2,
      );
      expect(humanChat.isBotChat, isFalse);
    });

    test('CallStartFailure enum has botForbidden value', () {
      expect(CallStartFailure.values, contains(CallStartFailure.botForbidden));
      expect(CallStartFailure.values, contains(CallStartFailure.permissions));

      const ex = CallStartException(CallStartFailure.botForbidden);
      expect(ex.toString(), contains('botForbidden'));
    });

    test('CallSessionData correctly reflects listener mode state', () {
      const normalData = CallSessionData(
        state: CallSessionState.inCall,
        callId: 1,
        isVideo: true,
        durationSeconds: 10,
        isListener: false,
      );
      expect(normalData.isListener, isFalse);
      expect(normalData.isMuted, isFalse);

      const listenerData = CallSessionData(
        state: CallSessionState.inCall,
        callId: 1,
        isVideo: true,
        isMuted: true,
        isSelfVideoEnabled: false,
        durationSeconds: 10,
        isListener: true,
      );
      expect(listenerData.isListener, isTrue);
      expect(listenerData.isMuted, isTrue);
      expect(listenerData.isSelfVideoEnabled, isFalse);
    });
  });

  group('Milestone 4: Call & System Event Messages', () {
    test('ApiMessage recognizes call system events', () {
      final json = <String, dynamic>{
        'id': 500,
        'chat_id': 12,
        'sender_id': 1,
        'sender_username': 'alice',
        'content': '📞 Звонок завершён (2:45)',
        'msg_type': 'text',
        'system_event_type': 'call',
        'system_event': {
          'duration': 165,
          'status': 'ended',
          'is_video': false,
        },
        'sent_at': '2026-09-07T12:00:00.000Z',
      };

      final msg = ApiMessage.fromJson(json);
      expect(msg.systemEventType, 'call');
      expect(msg.isCallEvent, isTrue);
      expect(msg.isSystemEvent, isTrue);
      expect(msg.systemEvent?['duration'], 165);
    });

    test('ApiMessage recognizes generic system events', () {
      final json = <String, dynamic>{
        'id': 501,
        'chat_id': 12,
        'sender_id': 0,
        'content': 'Пользователь присоединился к группе',
        'msg_type': 'system',
        'system_event_type': 'member_joined',
        'sent_at': '2026-09-07T12:00:00.000Z',
      };

      final msg = ApiMessage.fromJson(json);
      expect(msg.systemEventType, 'member_joined');
      expect(msg.isCallEvent, isFalse);
      expect(msg.isSystemEvent, isTrue);
    });
  });
}
