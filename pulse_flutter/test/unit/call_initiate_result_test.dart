import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/models/api/call_models.dart';

void main() {
  group('ApiCallInitiateResult.fromJson Safety Tests', () {
    test('Correctly parses payload with Map message (serialized_msg from server)', () {
      final Map<String, dynamic> rawServerResponse = <String, dynamic>{
        'action': 'start_call',
        'status': 'ringing',
        'room_id': 'abcdef0123456789abcdef0123456789',
        'message_id': 9912,
        'message': <String, dynamic>{
          'id': 9912,
          'chat_id': 42,
          'sender_id': 1,
          'msg_type': 'call_log',
          'content': 'Голосовой звонок — Вызов...',
        },
        'call_access_token': 'test-token-xyz',
        'signal_url': 'wss://signal.nioscraft.ru/ws',
        'max_video_height': 720,
        'max_duration_seconds': null,
        'ice_servers': <Map<String, dynamic>>[
          <String, dynamic>{'urls': 'stun:stun.l.google.com:19302'}
        ],
      };

      final ApiCallInitiateResult result = ApiCallInitiateResult.fromJson(
        rawServerResponse,
        isCallsTester: true,
      );

      expect(result.callId, equals(9912));
      expect(result.status, equals('ringing'));
      expect(result.callType, equals('voice'));
      expect(result.message, equals('Голосовой звонок — Вызов...'));
      expect(result.gatewayInfo, isNotNull);
      expect(result.gatewayInfo?.callAccessToken, equals('test-token-xyz'));
      expect(result.gatewayInfo?.signalUrl, equals('wss://signal.nioscraft.ru/ws'));
      expect(result.gatewayInfo?.maxVideoHeight, equals(720));
      expect(result.gatewayInfo?.maxDurationSeconds, isNull);
    });

    test('Correctly parses nested payload with String message', () {
      final Map<String, dynamic> rawServerResponse = <String, dynamic>{
        'payload': <String, dynamic>{
          'message_id': 100,
          'chat_id': 5,
          'status': 'ringing',
          'call_type': 'video',
          'message': 'Call initiated',
        },
      };

      final ApiCallInitiateResult result = ApiCallInitiateResult.fromJson(rawServerResponse);

      expect(result.callId, equals(100));
      expect(result.chatId, equals(5));
      expect(result.status, equals('ringing'));
      expect(result.callType, equals('video'));
      expect(result.message, equals('Call initiated'));
    });

    test('Correctly handles empty/missing message without type cast error', () {
      final Map<String, dynamic> rawServerResponse = <String, dynamic>{
        'call_id': 50,
      };

      final ApiCallInitiateResult result = ApiCallInitiateResult.fromJson(rawServerResponse);

      expect(result.callId, equals(50));
      expect(result.message, equals(''));
    });
  });
}
