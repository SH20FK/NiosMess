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
import 'e2ee_key_manager.dart';

/// Callback types.
typedef void OnStateChanged(CallSessionData data);
typedef void OnIncomingAudio(Uint8List opusData);

/// Main orchestrator for a NiosCalls call session.
///
/// Manages transport, heartbeat, media encryption, and state transitions.
class CallSession {
  CallSession({
    required this.chatId,
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

  final int chatId;
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

  final E2eeKeyManager _keyManager = E2eeKeyManager();
  final List<RemoteParticipant> _remoteParticipants = [];
  List<String> _verificationEmojis = [];

  CallSessionState _state = CallSessionState.idle;
  bool _isMuted = false;
  bool _isSpeakerOn = false;

  CallSessionData get currentData => CallSessionData(
        state: _state,
        callId: callId,
        roomId: roomId,
        isVideo: isVideo,
        direction: direction,
        localClientId: _localClientId,
        durationSeconds: _elapsedSeconds,
        remoteParticipants: _remoteParticipants,
        verificationEmojis: _verificationEmojis,
        isMuted: _isMuted,
        isSpeakerOn: _isSpeakerOn,
      );

  final StreamController<CallSessionData> _stateController =
      StreamController<CallSessionData>.broadcast();

  /// Stream of state changes.
  Stream<CallSessionData> get stateStream => _stateController.stream;

  /// Start the call: connect transport, start heartbeat.
  /// BUG FIX #3: Changed preferQuic default from false to true.
  /// Server spec: "Client MUST try UDP first, fallback to TCP on failure."
  /// This implements the correct transport priority with 2s timeout fallback.
  Future<void> start({bool preferQuic = true}) async {
    _setState(CallSessionState.connecting);

    try {
      await _keyManager.initialize();
    } catch (e) {
      debugPrint('[CallSession] E2EE Init failed: $e');
    }

    CallTransport transport;

    if (preferQuic) {
      // BUG FIX #3: Implement 2-second timeout for QUIC connection attempt
      transport = QuicCallTransport();
      _transport = transport;
      _setupTransportListeners(transport);

      try {
        var result = await transport.connect(
          roomId: roomId,
          nickname: displayName,
        ).timeout(
          const Duration(seconds: 2),
          onTimeout: () => TransportConnectResult.failed,
        );

        if (result == TransportConnectResult.connected) {
          _setState(CallSessionState.connected);
          return;
        }
      } catch (e) {
        debugPrint('[CallSession] QUIC connection error: $e');
      }

      debugPrint('[CallSession] QUIC failed, falling back to WS');
      await transport.disconnect();
    }

    // Fallback to TCP WebSocket
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
          if (_keyManager.myPubKeyRaw != null) {
            final pubKeyPacket = packPublicKeyPacket(myPubKeyRaw: _keyManager.myPubKeyRaw!);
            _transport?.send(pubKeyPacket);
          }
          _startHeartbeat();
          _setState(CallSessionState.inCall);
        }
        return;
      case kPacketTypeServerEndCall:
        debugPrint('[CallSession] Server sent end_call');
        _handleRemoteEnd();
        return;
      case kPacketTypePublicKey:
        _handlePeerPublicKey(data);
        return;
      case kPacketTypeKeyExchange:
        _handlePeerKeyExchange(data);
        return;
      case kPacketTypeMedia:
        _handleIncomingMedia(data);
        return;
      case kPacketTypeHeartbeat:
        _handlePeerHeartbeat(data);
        return;
    }
  }

  void _handlePeerHeartbeat(Uint8List data) {
    final parsed = unpackPacket(data);
    if (parsed.senderClientId == _localClientId) return;
    final String nickname = String.fromCharCodes(parsed.payload);

    final idx = _remoteParticipants.indexWhere((p) => p.clientId == parsed.senderClientId);
    final participant = RemoteParticipant(
      clientId: parsed.senderClientId,
      nickname: nickname,
    );
    if (idx != -1) {
      _remoteParticipants[idx] = participant;
    } else {
      _remoteParticipants.add(participant);
    }
    onRemoteParticipantJoined?.call(participant);
    _triggerStateUpdate();
  }

  Future<void> _handlePeerPublicKey(Uint8List data) async {
    if (data.length < 70) return;
    final int peerId = ByteData.view(data.buffer, data.offsetInBytes, data.length).getUint32(1);
    final Uint8List peerPubKeyRaw = data.sublist(5, 70);

    try {
      final exchangeData = await _keyManager.generateKeyExchange(peerId, peerPubKeyRaw);
      final iv = exchangeData.sublist(0, 12);
      final encryptedKey = exchangeData.sublist(12, 60);

      final keyExchangePacket = packKeyExchangePacket(
        peerId: peerId,
        iv: iv,
        encryptedKey: encryptedKey,
      );
      await _transport?.send(keyExchangePacket);
      debugPrint('[CallSession] Sent key exchange packet (0x06) to peer $peerId');

      if (!_remoteParticipants.any((p) => p.clientId == peerId)) {
        final participant = RemoteParticipant(
          clientId: peerId,
          nickname: 'User $peerId',
        );
        _remoteParticipants.add(participant);
      }

      await _recalculateVerificationEmojis();
    } catch (e) {
      debugPrint('[CallSession] Error handling peer public key: $e');
    }
  }

  Future<void> _handlePeerKeyExchange(Uint8List data) async {
    if (data.length < 65) return;
    final int senderId = ByteData.view(data.buffer, data.offsetInBytes, data.length).getUint32(1);
    final Uint8List iv = data.sublist(5, 17);
    final Uint8List encryptedKey = data.sublist(17, 65);

    try {
      await _keyManager.importKeyExchange(senderId, iv, encryptedKey);
      debugPrint('[CallSession] Successfully imported media key for sender $senderId');
    } catch (e) {
      debugPrint('[CallSession] Decrypt peer key failed: $e');
    }
  }

  Future<void> _handleIncomingMedia(Uint8List data) async {
    if (data.length < 17) return;
    final int senderId = ByteData.view(data.buffer, data.offsetInBytes, data.length).getUint32(1);
    final Uint8List iv = data.sublist(5, 17);
    final Uint8List ciphertext = data.sublist(17);

    final peerKey = _keyManager.peerSenderKeys[senderId];
    if (peerKey == null) return;

    try {
      final int tagOffset = ciphertext.length - 16;
      if (tagOffset <= 0) return;
      final rawCiphertext = ciphertext.sublist(0, tagOffset);
      final tag = ciphertext.sublist(tagOffset);

      final box = SecretBox(
        rawCiphertext,
        nonce: iv,
        mac: Mac(tag),
      );

      final decrypted = await AesGcm.with256bits().decrypt(
        box,
        secretKey: peerKey,
      );

      onIncomingAudio?.call(Uint8List.fromList(decrypted));
    } catch (e) {
      debugPrint('[CallSession] Media decrypt failed: $e');
    }
  }

  Future<void> _recalculateVerificationEmojis() async {
    if (_localClientId == null) return;
    _verificationEmojis = await _keyManager.getVerificationEmojis(_localClientId!);
    _triggerStateUpdate();
  }

  void _triggerStateUpdate() {
    final data = currentData;
    onStateChanged?.call(data);
    if (!_stateController.isClosed) {
      _stateController.add(data);
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
      nickname: displayName,
    );
    await _transport?.send(packet);
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

    final Uint8List encryptedMedia = Uint8List(secretBox.cipherText.length + secretBox.mac.bytes.length);
    encryptedMedia.setRange(0, secretBox.cipherText.length, secretBox.cipherText);
    encryptedMedia.setRange(secretBox.cipherText.length, encryptedMedia.length, secretBox.mac.bytes);

    final Uint8List packet = packMediaPacket(
      iv: iv,
      encryptedData: encryptedMedia,
    );

    if (packet.length <= kDatagramSizeLimit) {
      await _transport?.sendDatagram(packet);
    } else {
      await _transport?.send(packet);
    }
  }

  /// Mute / unmute local audio.
  Future<void> setMuted(bool muted) async {
    _isMuted = muted;
    final data = currentData;
    onStateChanged?.call(data);
    _stateController.add(data);
  }

  /// Toggle speakerphone.
  Future<void> setSpeakerOn(bool on) async {
    _isSpeakerOn = on;
    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: on
            ? const AVAudioSessionCategoryOptions(0x4 | 0x8) // defaultToSpeaker
            : const AVAudioSessionCategoryOptions(0x4), // earpiece
        avAudioSessionMode: AVAudioSessionMode.voiceChat,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: on ? AndroidAudioUsage.media : AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      ));
    } catch (_) {}
    final data = currentData;
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
      onOpusFrame: (opusData) {
        if (_isMuted) return;
        final iv = Uint8List(12);
        final random = Random.secure();
        for (int i = 0; i < 12; i++) {
          iv[i] = random.nextInt(256);
        }
        sendAudio(
          opusData: opusData,
          iv: iv,
          key: _keyManager.mySenderKey ?? aesKey,
        );
      },
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
          secretKey: _keyManager.mySenderKey ?? aesKey,
          nonce: iv,
        );

        final encryptedMedia = Uint8List(secretBox.cipherText.length + secretBox.mac.bytes.length);
        encryptedMedia.setRange(0, secretBox.cipherText.length, secretBox.cipherText);
        encryptedMedia.setRange(secretBox.cipherText.length, encryptedMedia.length, secretBox.mac.bytes);

        final Uint8List packet = packMediaPacket(
          iv: iv,
          encryptedData: encryptedMedia,
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
