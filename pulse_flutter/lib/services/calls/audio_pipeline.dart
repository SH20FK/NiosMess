import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:opus_codec/opus_codec.dart' as opus;
import 'package:opus_codec_dart/opus_codec_dart.dart';
import 'package:record/record.dart';

class AudioPipeline {
  AudioPipeline({
    required this.onOpusFrame,
    this.sampleRate = 48000,
    this.channels = 1,
    this.frameTime = FrameTime.ms20,
  });

  final void Function(Uint8List opusData) onOpusFrame;
  final int sampleRate;
  final int channels;
  final FrameTime frameTime;

  AudioRecorder? _recorder;
  StreamSubscription<dynamic>? _micSub;
  bool _started = false;
  bool _stopped = false;

  static bool _opusInitialized = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _stopped = false;

    await _initOpus();
    await _configureAudioSession();
    await _startMicStream();
  }

  Future<void> _initOpus() async {
    if (_opusInitialized) return;
    _opusInitialized = true;
    try {
      final lib = await opus.load();
      initOpus(lib);
      debugPrint('[AudioPipeline] Opus initialized');
    } catch (e) {
      debugPrint('[AudioPipeline] Opus init failed: $e');
    }
  }

  Future<void> _configureAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions(0x4 | 0x8),
      avAudioSessionMode: AVAudioSessionMode.voiceChat,
      avAudioSessionRouteSharingPolicy:
          AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        usage: AndroidAudioUsage.voiceCommunication,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: true,
    ));
  }

  Future<void> _startMicStream() async {
    _recorder = AudioRecorder();

    if (!await _recorder!.hasPermission()) {
      debugPrint('[AudioPipeline] No mic permission');
      return;
    }

    final stream = await _recorder!.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        numChannels: 1,
        sampleRate: 48000,
        echoCancel: true,
        noiseSuppress: true,
      ),
    );

    final encoder = StreamOpusEncoder.bytes(
      frameTime: frameTime,
      floatInput: false,
      sampleRate: sampleRate,
      channels: channels,
      application: Application.voip,
    ) as StreamTransformer<Uint8List, Uint8List>;

    _micSub = stream.transform(encoder).listen(
      (data) => onOpusFrame(data),
      onError: (e) => debugPrint('[AudioPipeline] Error: $e'),
    );
  }

  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;

    await _micSub?.cancel();
    _micSub = null;

    try {
      await _recorder?.stop();
    } catch (_) {}
    _recorder = null;

    debugPrint('[AudioPipeline] Stopped');
  }

  void dispose() {
    stop();
  }
}
