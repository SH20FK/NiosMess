import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'package:dart_webrtc/dart_webrtc.dart' show MediaStreamWeb;
import 'package:flutter_webrtc/flutter_webrtc.dart';

class MicrophoneMeter {
  MicrophoneMeter(this._context, this._source, this._analyser);
  final web.AudioContext _context;
  final web.MediaStreamAudioSourceNode _source;
  final web.AnalyserNode _analyser;
  final _samples = Float32List(1024);
  Future<double?> readLevel() async {
    _analyser.getFloatTimeDomainData(_samples.toJS);
    var sum = 0.0;
    for (final sample in _samples) {
      sum += sample * sample;
    }
    return (math.sqrt(sum / _samples.length) * 4).clamp(0, 1);
  }

  Future<void> dispose() async {
    _source.disconnect();
    _analyser.disconnect();
    await _context.close().toDart;
  }
}

Future<MicrophoneMeter> openMicrophoneMeter(MediaStream stream) async {
  final context = web.AudioContext();
  try {
    await context.resume().toDart;
    final source = context.createMediaStreamSource(
      (stream as MediaStreamWeb).jsStream,
    );
    final analyser = context.createAnalyser()..fftSize = 1024;
    source.connect(
      analyser,
    ); // Deliberately disconnected from speakers: no feedback.
    return MicrophoneMeter(context, source, analyser);
  } catch (_) {
    await context.close().toDart;
    rethrow;
  }
}
