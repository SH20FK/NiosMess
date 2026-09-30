import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/models/api/call_models.dart';
import 'package:pulse_flutter/services/calls/webrtc_signaling_client.dart';

void main() {
  group('WebRTC Signaling & Models Unit Tests', () {
    test('WebRtcPeerInfo parses from JSON correctly', () {
      final json = {
        'user_id': 42,
        'name': 'Alice',
        'video': true,
      };

      final peer = WebRtcPeerInfo.fromJson(json);
      expect(peer.userId, equals(42));
      expect(peer.name, equals('Alice'));
      expect(peer.video, isTrue);
    });

    test('ApiCallGatewayInfo parses WebRTC signal_url and ice_servers', () {
      final json = {
        'call_access_token': 'test_token.123',
        'signal_url': 'wss://c.ni-os.ru/signal',
        'ice_servers': [
          {'urls': ['stun:c.ni-os.ru:3478']},
          {
            'urls': ['turn:c.ni-os.ru:3478?transport=udp'],
            'username': 'test_user',
            'credential': 'secret_password',
          }
        ],
        'max_video_height': 720,
        'max_duration_seconds': 3600,
      };

      final info = ApiCallGatewayInfo.fromJson(json, isCallsTester: true);
      expect(info.callAccessToken, equals('test_token.123'));
      expect(info.signalUrl, equals('wss://c.ni-os.ru/signal'));
      expect(info.iceServers.length, equals(2));
      expect(info.maxVideoHeight, equals(720));
      expect(info.maxDurationSeconds, equals(3600));
    });

    test('ApiCallGatewayInfo default fallback sets Google STUN', () {
      final info = ApiCallGatewayInfo.defaultFor(
        isCallsTester: false,
        token: 'token123',
        signalUrl: 'wss://c.ni-os.ru/signal',
      );

      expect(info.callAccessToken, equals('token123'));
      expect(info.signalUrl, equals('wss://c.ni-os.ru/signal'));
      expect(info.iceServers.first['urls'], equals('stun:stun.l.google.com:19302'));
      expect(info.maxVideoHeight, equals(480));
      expect(info.maxDurationSeconds, equals(1800));
    });
  });
}
