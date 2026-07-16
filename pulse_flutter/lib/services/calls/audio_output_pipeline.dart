import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audio_session/audio_session.dart';
import 'package:audioplayers/audioplayers.dart' hide AVAudioSessionCategory;
import 'package:flutter/foundation.dart';
import 'package:opus_codec_dart/opus_codec_dart.dart';

class AudioOutputPipeline {
  AudioOutputPipeline({
    this.sampleRate = 48000,
    this.channels = 1,
    this.frameTime = FrameTime.ms20,
    this.bufferDurationMs = 200,
  });

  final int sampleRate;
  final int channels;
  final FrameTime frameTime;
  final int bufferDurationMs;

  SimpleOpusDecoder? _decoder;
  AudioPlayer? _player;
  final List<int> _pcmBuffer = [];
  bool _started = false;
  bool _stopped = false;
  bool _isPlaying = false;
  Timer? _flushTimer;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _stopped = false;

    await _initDecoder();
    await _configureAudioSession();

    _player = AudioPlayer(
      playerId: 'call_output_${identityHashCode(this)}',
    );

    _flushTimer = Timer.periodic(
      Duration(milliseconds: bufferDurationMs),
      (_) => _flushBuffer(),
    );
  }

  Future<void> _initDecoder() async {
    try {
      _decoder = SimpleOpusDecoder(
        sampleRate: sampleRate,
        channels: channels,
      );
      debugPrint('[AudioOutput] Opus decoder initialized');
    } catch (e) {
      debugPrint('[AudioOutput] Decoder init failed: $e');
    }
  }

  Future<void> _configureAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions(0x4 | 0x8),
      avAudioSessionMode: AVAudioSessionMode.voiceChat,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        usage: AndroidAudioUsage.voiceCommunication,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: true,
    ));
  }

  void pushOpusFrame(Uint8List opusData) {
    if (_stopped || _decoder == null) return;
    try {
      final Int16List pcm = _decoder!.decode(input: opusData);
      for (final int sample in pcm) {
        _pcmBuffer.add(sample & 0xFF);
        _pcmBuffer.add((sample >> 8) & 0xFF);
      }
    } catch (e) {
      debugPrint('[AudioOutput] Decode error: $e');
    }
  }

  void _flushBuffer() {
    if (_pcmBuffer.isEmpty || _player == null || _isPlaying) return;

    final int chunkSamples = sampleRate ~/ (1000 ~/ bufferDurationMs) * channels;
    final int chunkBytes = chunkSamples * 2;
    final int takeBytes = math.min(chunkBytes, _pcmBuffer.length);

    if (takeBytes < 160) return;

    final List<int> chunk = _pcmBuffer.take(takeBytes).toList();
    _pcmBuffer.removeRange(0, takeBytes);

    _playPcm(chunk);
  }

  Future<void> _playPcm(List<int> pcm16) async {
    try {
      _isPlaying = true;
      final Uint8List wav = _buildWav(pcm16);

      final source = BytesSource(wav);
      await _player!.stop();
      await _player!.play(source);

      _player!.onPlayerComplete.first.then((_) {
        _isPlaying = false;
      }).timeout(const Duration(seconds: 5), onTimeout: () {
        _isPlaying = false;
      });
    } catch (e) {
      _isPlaying = false;
      debugPrint('[AudioOutput] Playback error: $e');
    }
  }

  Uint8List _buildWav(List<int> pcm16) {
    final int dataSize = pcm16.length;
    final int fileSize = 44 + dataSize;
    final ByteData wav = ByteData(fileSize);

    wav.setUint8(0, 0x52); // R
    wav.setUint8(1, 0x49); // I
    wav.setUint8(2, 0x46); // F
    wav.setUint8(3, 0x46); // F
    wav.setUint32(4, fileSize - 8, Endian.little);
    wav.setUint8(8, 0x57); // W
    wav.setUint8(9, 0x41); // A
    wav.setUint8(10, 0x56); // V
    wav.setUint8(11, 0x45); // E

    wav.setUint8(12, 0x66); // f
    wav.setUint8(13, 0x6D); // m
    wav.setUint8(14, 0x74); // t
    wav.setUint8(15, 0x20); // space

    wav.setUint32(16, 16, Endian.little); // Subchunk1Size
    wav.setUint16(20, 1, Endian.little);  // PCM
    wav.setUint16(22, channels, Endian.little);
    wav.setUint32(24, sampleRate, Endian.little);
    wav.setUint32(28, sampleRate * channels * 2, Endian.little); // byte rate
    wav.setUint16(32, channels * 2, Endian.little); // block align
    wav.setUint16(34, 16, Endian.little); // bits per sample

    wav.setUint8(36, 0x64); // d
    wav.setUint8(37, 0x61); // a
    wav.setUint8(38, 0x74); // t
    wav.setUint8(39, 0x61); // a
    wav.setUint32(40, dataSize, Endian.little);

    for (int i = 0; i < dataSize; i++) {
      wav.setUint8(44 + i, pcm16[i]);
    }

    return wav.buffer.asUint8List();
  }

  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    _flushTimer?.cancel();
    _flushTimer = null;
    _pcmBuffer.clear();
    await _player?.stop();
    _player?.dispose();
    _player = null;
    _decoder?.destroy();
    _decoder = null;
    debugPrint('[AudioOutput] Stopped');
  }

  void dispose() {
    stop();
  }
}
