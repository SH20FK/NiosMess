import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import 'audio_output_pipeline.dart';
import 'audio_pipeline.dart';
import 'binary_packet.dart';
import 'call_session_types.dart';
import 'call_transport.dart';
import 'nios_calls_api.dart';
import 'quic_transport.dart';
import 'video_output_pipeline.dart';
import 'video_pipeline.dart';
import 'ws_transport.dart';

/// Callback types.
typedef void OnStateChanged(CallSessionData data);
typedef void OnIncomingAudio(Uint8List opusData);

/// Main orchestrator for a NiosCalls call session.
///
/// Manages transport, heartbeat, media encryption, and state transitions.
class CallSession {
  CallSession({
    required this.callId,
    required this.roomId,
    required this.isVideo,
    required this.direction,
    required this.displayName,
    required Uint8List aesKeyBytes,
    this.onStateChanged,
    this.onIncomingAudio,
    this.onIncomingVideo,
    this.onRemoteParticipantJoined,
    this.onRemoteParticipantLeft,
  }) : aesKey = SecretKey(aesKeyBytes);

  final int callId;
  final String roomId;
  final bool isVideo;
  final CallDirection direction;
  final String displayName;
  final SecretKey aesKey;

  OnStateChanged? onStateChanged;
  OnIncomingAudio? onIncomingAudio;
  void Function(Uint8List vp8Data, int frameType, double timestamp)?
      onIncomingVideo;
  void Function(RemoteParticipant participant)? onRemoteParticipantJoined;
  void Function(int clientId)? onRemoteParticipantLeft;

  CallTransport? _transport;
  int? _localClientId;
  Timer? _heartbeatTimer;
  Timer? _durationTimer;
  int _elapsedSeconds = 0;
  bool _ended = false;
  AudioPipeline? _audioPipeline;
  AudioOutputPipeline? _audioOutput;
  VideoPipeline? _videoPipeline;
  VideoOutputPipeline? _videoOutput;

  CallSessionState _state = CallSessionState.idle;

  CallSessionData get currentData => CallSessionData(
        state: _state,
        callId: callId,
        roomId: roomId,
        isVideo: isVideo,
        direction: direction,
        localClientId: _localClientId,
        durationSeconds: _elapsedSeconds,
      );

  final StreamController<CallSessionData> _stateController =
      StreamController<CallSessionData>.broadcast();

  /// Stream of state changes.
  Stream<CallSessionData> get stateStream => _stateController.stream;

  /// Start the call: connect transport, start heartbeat.
  Future<void> start({bool preferQuic = false}) async {
    _setState(CallSessionState.connecting);

    CallTransport transport;

    if (preferQuic) {
      transport = QuicCallTransport();
      _transport = transport;
      _setupTransportListeners(transport);

      var result = await transport.connect(
        roomId: roomId,
        nickname: displayName,
      );

      if (result == TransportConnectResult.connected) {
        _setState(CallSessionState.connected);
        return;
      }

      debugPrint('[CallSession] QUIC failed, falling back to WS');
    }

    transport = WsCallTransport();
    _transport = transport;

    _setupTransportListeners(transport);

    final result = await transport.connect(
      roomId: roomId,
      nickname: displayName,
    );

    if (result == TransportConnectResult.failed) {
      _setState(CallSessionState.ended);
      return;
    }

    _setState(CallSessionState.connected);
  }

  void _setupTransportListeners(CallTransport transport) {
    transport.onPacketReceived.listen((Uint8List data) {
      _handleIncomingPacket(data);
    });

    transport.onDisconnected.listen((_) {
      if (!_ended) {
        _setState(CallSessionState.reconnecting);
        _tryReconnect();
      }
    });
  }

  void _handleIncomingPacket(Uint8List data) {
    if (data.isEmpty) return;
    final int type = data[0];

    switch (type) {
      case kPacketTypeServerClientId:
        if (data.length >= 5) {
          _localClientId = parseClientIdPacket(data);
          debugPrint('[CallSession] Got Client ID: $_localClientId');
          _startHeartbeat();
          _setState(CallSessionState.inCall);
        }
        return;
      case kPacketTypeServerEndCall:
        debugPrint('[CallSession] Server sent end_call');
        _handleRemoteEnd();
        return;
      case kPacketTypeAudio:
      case kPacketTypeVideo:
      case kPacketTypeHeartbeat:
        _handleRelayedPacket(data);
        return;
    }
  }

  void _handleRelayedPacket(Uint8List data) {
    final ParsedPacket parsed = unpackPacket(data);
    if (parsed.senderClientId == _localClientId) return;

    switch (parsed.type) {
      case kPacketTypeAudio:
        _handleIncomingAudio(parsed);
        return;
      case kPacketTypeVideo:
        _handleIncomingVideo(parsed);
        return;
      case kPacketTypeHeartbeat:
        final String nickname = String.fromCharCodes(parsed.payload);
        final participant = RemoteParticipant(
          clientId: parsed.senderClientId,
          nickname: nickname,
        );
        onRemoteParticipantJoined?.call(participant);
        return;
    }
  }

  Future<void> _handleIncomingAudio(ParsedPacket parsed) async {
    if (parsed.iv == null) return;
    try {
      final SecretBox secretBox = SecretBox(
        parsed.payload,
        nonce: parsed.iv!,
        mac: Mac.empty,
      );
      final List<int> decrypted = await AesGcm.with256bits().decrypt(
        secretBox,
        secretKey: aesKey,
      );
      onIncomingAudio?.call(Uint8List.fromList(decrypted));
    } catch (e) {
      debugPrint('[CallSession] Audio decrypt failed: $e');
    }
  }

  Future<void> _handleIncomingVideo(ParsedPacket parsed) async {
    if (parsed.iv == null) return;
    try {
      final SecretBox secretBox = SecretBox(
        parsed.payload,
        nonce: parsed.iv!,
        mac: Mac.empty,
      );
      final List<int> decrypted = await AesGcm.with256bits().decrypt(
        secretBox,
        secretKey: aesKey,
      );
      onIncomingVideo?.call(
        Uint8List.fromList(decrypted),
        parsed.videoFrameType ?? 0,
        parsed.videoTimestamp ?? 0,
      );
    } catch (e) {
      debugPrint('[CallSession] Video decrypt failed: $e');
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _sendHeartbeat();
    });

    _durationTimer?.cancel();
    _elapsedSeconds = 0;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;
      final data = currentData;
      onStateChanged?.call(data);
      _stateController.add(data);
    });
  }

  Future<void> _sendHeartbeat() async {
    if (_transport == null || _localClientId == null) return;
    final Uint8List packet = packHeartbeatPacket(
      clientId: _localClientId!,
      nickname: displayName,
    );
    await _transport!.send(packet);
  }

  Future<void> _tryReconnect() async {
    if (_ended) return;
    await Future.delayed(const Duration(seconds: 2));
    if (_ended) return;

    final transport = WsCallTransport();
    _transport = transport;
    _setupTransportListeners(transport);

    final result = await transport.connect(
      roomId: roomId,
      nickname: displayName,
    );

    if (result == TransportConnectResult.connected) {
      _setState(CallSessionState.connected);
    } else {
      _setState(CallSessionState.ended);
    }
  }

  void _handleRemoteEnd() {
    _ended = true;
    _heartbeatTimer?.cancel();
    _durationTimer?.cancel();
    _transport?.disconnect();
    _setState(CallSessionState.ended);
  }

  /// Send an encrypted audio packet.
  Future<void> sendAudio({
    required Uint8List opusData,
    required Uint8List iv,
    required SecretKey key,
  }) async {
    if (_transport == null || _localClientId == null || _ended) return;

    final SecretBox secretBox = await AesGcm.with256bits().encrypt(
      opusData,
      secretKey: key,
      nonce: iv,
    );

    final Uint8List packet = packAudioPacket(
      clientId: _localClientId!,
      iv: iv,
      encryptedOpus: Uint8List.fromList(secretBox.cipherText),
    );

    if (packet.length <= kDatagramSizeLimit) {
      await _transport!.sendDatagram(packet);
    } else {
      await _transport!.send(packet);
    }
  }

  /// Mute / unmute local audio.
  Future<void> setMuted(bool muted) async {
    final data = currentData.copyWith(isMuted: muted);
    onStateChanged?.call(data);
    _stateController.add(data);
  }

  /// Toggle speakerphone.
  Future<void> setSpeakerOn(bool on) async {
    final data = currentData.copyWith(isSpeakerOn: on);
    onStateChanged?.call(data);
    _stateController.add(data);
  }

  /// End the call.
  /// Expose for UI to listen to remote video frames.
  VideoOutputPipeline? get videoOutput => _videoOutput;

  /// Switch between front and back camera.
  Future<void> switchCamera() async {
    await _videoPipeline?.switchCamera();
  }

  Future<void> end() async {
    if (_ended) return;
    _ended = true;
    _heartbeatTimer?.cancel();
    _durationTimer?.cancel();
    await _audioPipeline?.stop();
    _audioPipeline = null;
    await _audioOutput?.stop();
    _audioOutput = null;
    await _videoPipeline?.stop();
    _videoPipeline = null;
    await _videoOutput?.stop();
    _videoOutput = null;
    await _transport?.disconnect();
    _tryEndSfuRoom();
    _setState(CallSessionState.ended);
  }

  Future<void> _tryEndSfuRoom() async {
    try {
      final api = NiosCallsApi();
      await api.endRoom(roomId);
      api.dispose();
    } catch (_) {}
  }

  Future<void> _startAudioPipeline() async {
    _audioOutput = AudioOutputPipeline();
    await _audioOutput!.start();

    onIncomingAudio = (opusData) {
      _audioOutput?.pushOpusFrame(opusData);
    };

    _audioPipeline = AudioPipeline(
      onOpusFrame: (opusData) => sendAudio(
        opusData: opusData,
        iv: Uint8List(12),
        key: aesKey,
      ),
    );
    await _audioPipeline!.start();

    if (isVideo) {
      await _startVideoPipeline();
    }
  }

  Future<void> _startVideoPipeline() async {
    _videoOutput = VideoOutputPipeline();
    _videoOutput!.start();

    onIncomingVideo = (data, frameType, timestamp) {
      _videoOutput?.pushFrame(data);
    };

    _videoPipeline = VideoPipeline(
      onSendPacket: ({
        required int frameType,
        required double timestamp,
        required Uint8List iv,
        required Uint8List encryptedVp8,
      }) async {
        if (_transport == null || _localClientId == null || _ended) return;

        final SecretBox secretBox = await AesGcm.with256bits().encrypt(
          encryptedVp8,
          secretKey: aesKey,
          nonce: iv,
        );

        final Uint8List packet = packVideoPacket(
          clientId: _localClientId!,
          frameType: frameType,
          timestamp: timestamp,
          iv: iv,
          encryptedVp8: Uint8List.fromList(secretBox.cipherText),
        );

        await _transport!.send(packet);
      },
    );
    await _videoPipeline!.start();
  }

  Future<void> _stopAudioPipeline() async {
    await _audioPipeline?.stop();
    _audioPipeline = null;
    await _audioOutput?.stop();
    _audioOutput = null;
    await _videoPipeline?.stop();
    _videoPipeline = null;
    await _videoOutput?.stop();
    _videoOutput = null;
  }

  void _setState(CallSessionState newState) {
    _state = newState;
    final data = currentData;
    onStateChanged?.call(data);
    _stateController.add(data);

    if (newState == CallSessionState.inCall) {
      _startAudioPipeline();
    }
    if (newState == CallSessionState.ended) {
      _stopAudioPipeline();
    }
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _durationTimer?.cancel();
    _audioPipeline?.dispose();
    _audioPipeline = null;
    _audioOutput?.dispose();
    _audioOutput = null;
    _videoPipeline?.dispose();
    _videoPipeline = null;
    _videoOutput?.dispose();
    _videoOutput = null;
    _stateController.close();
    _transport?.disconnect();
    (_transport as WsCallTransport?)?.dispose();
  }
}
