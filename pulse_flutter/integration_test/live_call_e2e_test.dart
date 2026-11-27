import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pulse_flutter/models/api/call_models.dart';
import 'package:pulse_flutter/services/calls/call_session_types.dart';
import 'package:pulse_flutter/services/calls/webrtc_call_session.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('live Windows WebRtcCallSession sends & receives audio + video', (
    tester,
  ) async {
    const roomId = String.fromEnvironment('CALL_ROOM_ID');
    const signalUrl = String.fromEnvironment(
      'CALL_SIGNAL_URL',
      defaultValue: 'wss://c.ni-os.ru/signal',
    );
    const callToken = String.fromEnvironment('CALL_TOKEN');
    const turnUser = String.fromEnvironment('TURN_USERNAME');
    const turnPass = String.fromEnvironment('TURN_CREDENTIAL');
    const forceRelay = bool.fromEnvironment('FORCE_RELAY', defaultValue: true);

    expect(roomId, isNotEmpty, reason: 'CALL_ROOM_ID must be provided');
    expect(callToken, isNotEmpty, reason: 'CALL_TOKEN must be provided');
    expect(turnUser, isNotEmpty, reason: 'TURN_USERNAME must be provided');
    expect(turnPass, isNotEmpty, reason: 'TURN_CREDENTIAL must be provided');

    final localRenderer = RTCVideoRenderer();
    final remoteRenderer = RTCVideoRenderer();
    await localRenderer.initialize();
    await remoteRenderer.initialize();

    final gateway = ApiCallGatewayInfo(
      signalUrl: signalUrl,
      callAccessToken: callToken,
      iceServers: [
        {
          'urls': [
            'turns:c.ni-os.ru:5349?transport=tcp',
            'turn:c.ni-os.ru:3478?transport=tcp',
            'turn:c.ni-os.ru:3478?transport=udp',
          ],
          'username': turnUser,
          'credential': turnPass,
        },
        {
          'urls': ['stun:c.ni-os.ru:3478'],
        },
      ],
      maxVideoHeight: 720,
      maxScreenHeight: 720,
      maxFps: 30,
      isPlus: true,
      isGroup: false,
    );

    final session = WebRtcCallSession(
      chatId: 1,
      callId: 1,
      roomId: roomId,
      isVideo: true,
      direction: CallDirection.outgoing,
      displayName: 'FlutterWinTester',
      peerName: 'LiveAiortcPeer',
      forceRelay: forceRelay,
      gatewayInfo: gateway,
      localRenderer: localRenderer,
      remoteRenderer: remoteRenderer,
    );

    final inCallCompleter = Completer<void>();
    final sub = session.stateStream.listen((data) {
      if (data.state == CallSessionState.inCall && !inCallCompleter.isCompleted) {
        inCallCompleter.complete();
      }
    });

    try {
      await session.start();
      await inCallCompleter.future.timeout(const Duration(seconds: 25));

      Map<String, int> stats = const {};
      final deadline = DateTime.now().add(const Duration(seconds: 12));
      while (DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        stats = await session.collectLiveMediaStats();
        final ok =
            (stats['audioBytesSent'] ?? 0) > 0 &&
            (stats['audioBytesReceived'] ?? 0) > 0 &&
            (stats['videoBytesSent'] ?? 0) > 0 &&
            (stats['videoBytesReceived'] ?? 0) > 0 &&
            (stats['videoFramesSent'] ?? 0) > 0 &&
            (stats['videoFramesDecoded'] ?? 0) > 0;
        if (ok) break;
      }

      debugPrint('[LIVE_FLUTTER_STATS] $stats');
      expect(session.currentData.state, CallSessionState.inCall);
      expect(session.remoteStreams, isNotEmpty);
      expect(remoteRenderer.srcObject, isNotNull);
      expect(localRenderer.srcObject, isNotNull);

      expect(stats['audioPacketsSent'] ?? 0, greaterThan(0));
      expect(stats['audioBytesSent'] ?? 0, greaterThan(0));
      expect(stats['audioPacketsReceived'] ?? 0, greaterThan(0));
      expect(stats['audioBytesReceived'] ?? 0, greaterThan(0));
      expect(stats['videoFramesSent'] ?? 0, greaterThan(0));
      expect(stats['videoBytesSent'] ?? 0, greaterThan(0));
      expect(stats['videoFramesDecoded'] ?? 0, greaterThan(0));
      expect(stats['videoBytesReceived'] ?? 0, greaterThan(0));
    } finally {
      await sub.cancel();
      await session.end();
      await session.dispose();
      await localRenderer.dispose();
      await remoteRenderer.dispose();
    }
  });
}
