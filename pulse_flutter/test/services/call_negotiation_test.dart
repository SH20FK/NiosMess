import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:pulse_flutter/models/api/call_models.dart';
import 'package:pulse_flutter/services/calls/call_session_types.dart';
import 'package:pulse_flutter/services/calls/webrtc_call_session.dart';

class _Peer extends Fake implements RTCPeerConnection {
  final events = <String>[];
  Completer<void>? remoteGate;
  bool failDescription = false;
  bool remoteReady = false;
  @override
  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    events.add('remote:start');
    if (failDescription) throw StateError('description rejected');
    await remoteGate?.future;
    remoteReady = true;
    events.add('remote:done');
  }
  @override
  Future<void> setLocalDescription(RTCSessionDescription description) async {
    events.add('local');
  }
  @override
  Future<RTCSessionDescription> createAnswer([Map<String, dynamic>? constraints]) async =>
      RTCSessionDescription('answer', 'answer');
  @override
  Future<RTCSessionDescription> createOffer([Map<String, dynamic>? constraints]) async =>
      RTCSessionDescription('offer', 'offer');
  @override
  Future<void> addCandidate(RTCIceCandidate candidate) async {
    if (!remoteReady) throw StateError('ICE before remote description');
    events.add('ice:${candidate.candidate}');
  }
  @override
  set onIceCandidate(void Function(RTCIceCandidate)? callback) {}
  @override
  set onTrack(void Function(RTCTrackEvent)? callback) {}
  @override
  set onConnectionState(void Function(RTCPeerConnectionState)? callback) {}
  @override
  Future<void> close() async { events.add('close'); }
  @override
  Future<void> dispose() async { events.add('dispose'); }
}

class _Renderer extends Fake implements RTCVideoRenderer {
  @override
  set srcObject(MediaStream? stream) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final video in [false, true]) {
    test('${video ? 'video' : 'audio'} buffers early ICE and serializes SDP', () async {
      final peer = _Peer()..remoteGate = Completer<void>();
      var creations = 0;
      final session = WebRtcCallSession(
        chatId: 1, callId: 2, roomId: 'fixture', isVideo: video,
        direction: CallDirection.incoming, displayName: 'Fixture', isListener: true,
        gatewayInfo: ApiCallGatewayInfo.defaultFor(),
        localRenderer: _Renderer(), remoteRenderer: _Renderer(),
        peerConnectionFactory: (_) async { creations++; return peer; },
      );
      addTearDown(session.dispose);
      await session.handleSignalingMessage({
        'type': 'ice', 'from_id': 7,
        'candidate': {'candidate': 'early', 'sdpMid': '0', 'sdpMLineIndex': 0},
      });
      final offer = session.handleSignalingMessage({
        'type': 'offer', 'from_id': 7, 'sdp': {'type': 'offer', 'sdp': 'offer'},
      });
      final laterIce = session.handleSignalingMessage({
        'type': 'ice', 'from_id': 7, 'candidate': {'candidate': 'later'},
      });
      await Future<void>.delayed(Duration.zero);
      expect(peer.events, ['remote:start']);
      peer.remoteGate!.complete();
      await Future.wait([offer, laterIce]);
      expect(creations, 1);
      expect(peer.events, ['remote:start', 'remote:done', 'ice:early', 'local', 'ice:later']);
      expect(session.currentData.fatalError, isNull);
      expect(session.wasAnswered, isFalse, reason: 'SDP alone is not connected media');
      await session.end();
      await session.end();
      expect(peer.events.where((e) => e == 'close').length, 1);
      expect(peer.events.where((e) => e == 'dispose').length, 1);
    });
  }

  test('failed negotiation ends the session and releases its peer', () async {
    final peer = _Peer()..failDescription = true;
    final session = WebRtcCallSession(
      chatId: 1, callId: 2, roomId: 'fixture', isVideo: true,
      direction: CallDirection.incoming, displayName: 'Fixture', isListener: true,
      gatewayInfo: ApiCallGatewayInfo.defaultFor(),
      localRenderer: _Renderer(), remoteRenderer: _Renderer(),
      peerConnectionFactory: (_) async => peer,
    );
    await session.handleSignalingMessage({
      'type': 'offer', 'from_id': 7, 'sdp': {'type': 'offer', 'sdp': 'bad'},
    });
    await session.dispose();
    expect(session.currentData.state, CallSessionState.ended);
    expect(session.currentData.fatalError, 'signaling_failed');
    expect(peer.events, ['remote:start', 'close', 'dispose']);
  });

  group('Native call audio routing', () {
    const channel = MethodChannel('FlutterWebRTC.Method');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late WebRtcCallSession session;
    TargetPlatform? previousPlatform;
    setUp(() {
      previousPlatform = debugDefaultTargetPlatformOverride;
      session = WebRtcCallSession(
        chatId: 1, callId: 2, roomId: 'routing', isVideo: false,
        direction: CallDirection.outgoing, displayName: 'Fixture',
        gatewayInfo: ApiCallGatewayInfo.defaultFor(),
        localRenderer: _Renderer(), remoteRenderer: _Renderer(),
      );
    });
    tearDown(() async {
      await session.dispose();
      messenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = previousPlatform;
    });

    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      test('$platform switches the real WebRTC audio device', () async {
        debugDefaultTargetPlatformOverride = platform;
        final routes = <bool>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'initialize') return null;
          expect(call.method, 'enableSpeakerphone');
          routes.add((call.arguments as Map)['enable'] as bool);
          return null;
        });
        await session.setSpeakerOn(true);
        expect(session.currentData.isSpeakerOn, isTrue);
        await session.setSpeakerOn(false);
        expect(session.currentData.isSpeakerOn, isFalse);
        expect(routes, [true, false]);
        await session.end();
        await session.setSpeakerOn(true);
        expect(routes, [true, false], reason: 'An ended call cannot change routing');
      });
    }

    test('failed device selection does not claim speaker is enabled', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(code: 'route_unavailable');
      });
      await session.setSpeakerOn(true);
      expect(session.currentData.isSpeakerOn, isFalse);
      expect(session.currentData.state, CallSessionState.idle);
    });

    test('a late route result cannot revive a finished call', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final route = Completer<void>();
      messenger.setMockMethodCallHandler(channel, (_) async {
        await route.future;
        return null;
      });
      final selection = session.setSpeakerOn(true);
      await Future<void>.delayed(Duration.zero);
      await session.end();
      route.complete();
      await selection;
      expect(session.currentData.isSpeakerOn, isFalse);
      expect(session.currentData.state, CallSessionState.ended);
    });
  });
}
