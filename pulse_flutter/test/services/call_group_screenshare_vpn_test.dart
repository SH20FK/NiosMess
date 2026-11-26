import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:pulse_flutter/models/api/call_models.dart';
import 'package:pulse_flutter/services/calls/call_capture_profile.dart';
import 'package:pulse_flutter/services/calls/call_session_types.dart';
import 'package:pulse_flutter/services/calls/webrtc_call_session.dart';

class _Renderer extends Fake implements RTCVideoRenderer {
  @override
  set srcObject(MediaStream? stream) {}
}

WebRtcCallSession _session(ApiCallGatewayInfo info, {bool group = false}) =>
    WebRtcCallSession(
      chatId: 1,
      callId: 2,
      roomId: 'a' * 32,
      isVideo: true,
      isGroup: group,
      direction: CallDirection.outgoing,
      displayName: 'T',
      gatewayInfo: info,
      localRenderer: _Renderer(),
      remoteRenderer: _Renderer(),
    );

void main() {
  test('tiers: free 480p/30fps, NiosPlus 1440p/60fps', () {
    final free = ApiCallGatewayInfo.defaultFor();
    expect(free.maxVideoHeight, 480);
    expect(free.maxFps, 30);
    expect(free.maxDurationSeconds, 1800);
    final plus = ApiCallGatewayInfo.defaultFor(isNiosPlus: true);
    expect(plus.maxVideoHeight, 1440);
    expect(plus.maxScreenHeight, 1440);
    expect(plus.maxFps, 60);
    expect(plus.maxDurationSeconds, isNull);
    final parsed = ApiCallGatewayInfo.fromJson({
      'call_access_token': 't',
      'is_plus': true,
      'max_video_height': 1440,
      'max_fps': 60,
      'is_group': true,
    });
    expect(parsed.isPlus && parsed.isGroup, isTrue);
    expect(CallCaptureProfile(plus.maxVideoHeight, maxFps: plus.maxFps).width,
        2560);
  });

  test('VPN relay config forces relay and bundles; default is all', () async {
    final info = ApiCallGatewayInfo.fromJson({
      'call_access_token': 't',
      'ice_servers': [
        {
          'urls': ['turns:c.ni-os.ru:5349?transport=tcp'],
          'username': 'u',
          'credential': 'c',
        },
      ],
    });
    final s = _session(info);
    expect(s.buildRtcConfiguration()['iceTransportPolicy'], 'all');
    expect(s.buildRtcConfiguration()['bundlePolicy'], 'max-bundle');
    await s.setForceRelay(true);
    expect(s.buildRtcConfiguration()['iceTransportPolicy'], 'relay');
    expect(s.currentData.forceRelay, isTrue);
    final servers = s.buildRtcConfiguration()['iceServers'] as List;
    expect((servers.first as Map)['urls'].first, startsWith('turns:'));
    await s.dispose();
  });

  test('participant screen-share state is carried in session data', () {
    final p = RemoteParticipant(clientId: 9, nickname: 'Bob').copyWith(
      screenSharing: true,
      screenStreamId: 'scr1',
    );
    expect(p.screenSharing, isTrue);
    expect(p.screenStreamId, 'scr1');
    expect(p.copyWith(screenSharing: false, clearScreenStreamId: true).screenStreamId, isNull);
    final data = const CallSessionData(
      state: CallSessionState.inCall,
      callId: 1,
      isVideo: true,
      durationSeconds: 0,
    ).copyWith(isGroup: true, isScreenSharing: true, activeScreenPeerId: 9);
    expect(data.isGroup && data.isScreenSharing, isTrue);
    expect(data.activeScreenPeerId, 9);
  });
}
