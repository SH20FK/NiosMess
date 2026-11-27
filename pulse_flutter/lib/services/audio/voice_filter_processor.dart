import 'dart:math' as math;
import 'dart:typed_data';

import 'voice_filter_preset.dart';

/// Pure-Dart DSP processor for 16-bit PCM WAV voice recordings.
class VoiceFilterProcessor {
  const VoiceFilterProcessor._();

  /// Applies [preset] to a 16-bit PCM WAV buffer and returns a new WAV buffer.
  /// Returns the original bytes unchanged when [preset] is [VoiceFilterPreset.none]
  /// or if the input is not a valid PCM16 WAV header.
  static Uint8List applyToWavBytes(
    Uint8List wavBytes,
    VoiceFilterPreset preset,
  ) {
    if (preset == VoiceFilterPreset.none) return wavBytes;
    final _WavData? parsed = _parsePcm16Wav(wavBytes);
    if (parsed == null || parsed.samples.isEmpty) return wavBytes;

    final List<double> mono = _toMonoNormalized(
      parsed.samples,
      parsed.channels,
    );
    final List<double> processed = applyToMonoSamples(
      mono,
      parsed.sampleRate,
      preset,
    );
    return _encodePcm16Wav(processed, parsed.sampleRate);
  }

  /// Processes normalized mono samples in [-1.0, 1.0].
  static List<double> applyToMonoSamples(
    List<double> input,
    int sampleRate,
    VoiceFilterPreset preset,
  ) {
    if (input.isEmpty || preset == VoiceFilterPreset.none) {
      return List<double>.from(input);
    }

    switch (preset) {
      case VoiceFilterPreset.none:
        return List<double>.from(input);
      case VoiceFilterPreset.robot:
        return _applyRobot(input, sampleRate);
      case VoiceFilterPreset.radio:
        return _applyRadio(input, sampleRate);
      case VoiceFilterPreset.deep:
        return _applyDeep(input, sampleRate);
      case VoiceFilterPreset.helium:
        return _applyPitchShift(input, 1.38);
      case VoiceFilterPreset.echo:
        return _applyEcho(input, sampleRate);
      case VoiceFilterPreset.anonymous:
        return _applyAnonymous(input, sampleRate);
    }
  }

  static List<double> _applyRobot(List<double> input, int sampleRate) {
    final out = List<double>.filled(input.length, 0.0);
    const double carrierHz = 68.0;
    const double steps = 14.0;
    for (int i = 0; i < input.length; i++) {
      final double t = i / sampleRate;
      final double ring = math.sin(2.0 * math.pi * carrierHz * t);
      final double crushed = (input[i] * steps).roundToDouble() / steps;
      final double mixed = 0.72 * (input[i] * ring * 1.35) + 0.28 * crushed;
      out[i] = mixed.clamp(-0.98, 0.98);
    }
    return out;
  }

  static List<double> _applyRadio(List<double> input, int sampleRate) {
    final out = List<double>.filled(input.length, 0.0);
    // Simple 1st-order high-pass (~380 Hz) + low-pass (~2600 Hz) + soft clip.
    final double dt = 1.0 / sampleRate;
    final double rcHp = 1.0 / (2.0 * math.pi * 380.0);
    final double alphaHp = rcHp / (rcHp + dt);
    final double rcLp = 1.0 / (2.0 * math.pi * 2600.0);
    final double alphaLp = dt / (rcLp + dt);

    double prevIn = 0.0;
    double prevHp = 0.0;
    double prevLp = 0.0;
    int seed = 1337;

    for (int i = 0; i < input.length; i++) {
      final double x = input[i];
      final double hp = alphaHp * (prevHp + x - prevIn);
      prevIn = x;
      prevHp = hp;

      final double lp = prevLp + alphaLp * (hp - prevLp);
      prevLp = lp;

      // Subtle radio static hiss
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      final double noise = ((seed / 0x7fffffff) * 2.0 - 1.0) * 0.012;

      // Soft overdrive
      final double driven = _tanhApprox((lp + noise) * 2.4);
      out[i] = (driven * 0.85).clamp(-0.98, 0.98);
    }
    return out;
  }

  static List<double> _applyDeep(List<double> input, int sampleRate) {
    final pitched = _applyPitchShift(input, 0.74);
    final int delay = (sampleRate * 0.075).round();
    final out = List<double>.from(pitched);
    for (int i = delay; i < out.length; i++) {
      out[i] = (out[i] + pitched[i - delay] * 0.25).clamp(-0.98, 0.98);
    }
    return out;
  }

  static List<double> _applyAnonymous(List<double> input, int sampleRate) {
    final pitched = _applyPitchShift(input, 0.83);
    final out = List<double>.filled(pitched.length, 0.0);
    double prevLp = 0.0;
    final double dt = 1.0 / sampleRate;
    final double rcLp = 1.0 / (2.0 * math.pi * 2100.0);
    final double alphaLp = dt / (rcLp + dt);
    for (int i = 0; i < pitched.length; i++) {
      final double mod = 0.88 + 0.12 * math.sin(2.0 * math.pi * 19.0 * (i / sampleRate));
      prevLp = prevLp + alphaLp * (pitched[i] * mod - prevLp);
      out[i] = (prevLp * 1.15).clamp(-0.98, 0.98);
    }
    return out;
  }

  static List<double> _applyEcho(List<double> input, int sampleRate) {
    final out = List<double>.from(input);
    final int d1 = (sampleRate * 0.14).round();
    final int d2 = (sampleRate * 0.28).round();
    final int d3 = (sampleRate * 0.42).round();
    for (int i = 0; i < input.length; i++) {
      double v = input[i] * 0.82;
      if (i >= d1) v += input[i - d1] * 0.42;
      if (i >= d2) v += input[i - d2] * 0.24;
      if (i >= d3) v += input[i - d3] * 0.12;
      out[i] = v.clamp(-0.98, 0.98);
    }
    return out;
  }

  /// Granular overlap-add pitch shifter that preserves overall duration.
  static List<double> _applyPitchShift(List<double> input, double ratio) {
    const int grainSize = 1024;
    const int hopOut = 256;
    final int n = input.length;
    if (n < grainSize) {
      return List<double>.from(input);
    }
    final out = List<double>.filled(n, 0.0);
    final norm = List<double>.filled(n, 0.0);
    final double hopIn = hopOut * ratio;

    // Hann window
    final window = List<double>.generate(
      grainSize,
      (i) => 0.5 * (1.0 - math.cos(2.0 * math.pi * i / (grainSize - 1))),
    );

    double inPos = 0.0;
    for (int outPos = 0; outPos + grainSize <= n; outPos += hopOut) {
      final int srcStart = inPos.round().clamp(0, math.max(0, n - grainSize));
      for (int k = 0; k < grainSize; k++) {
        final double w = window[k];
        out[outPos + k] += input[srcStart + k] * w;
        norm[outPos + k] += w;
      }
      inPos += hopIn;
      if (inPos + grainSize > n) {
        inPos = (outPos / n) * (n - grainSize);
      }
    }

    for (int i = 0; i < n; i++) {
      if (norm[i] > 1e-4) {
        out[i] = (out[i] / norm[i]).clamp(-0.98, 0.98);
      } else {
        out[i] = input[i];
      }
    }
    return out;
  }

  static double _tanhApprox(double x) {
    final double x2 = x * x;
    return x * (27.0 + x2) / (27.0 + 9.0 * x2);
  }

  static _WavData? _parsePcm16Wav(Uint8List bytes) {
    if (bytes.length < 44) return null;
    final bd = ByteData.sublistView(bytes);
    // Check "RIFF" and "WAVE"
    if (bd.getUint32(0, Endian.big) != 0x52494646 ||
        bd.getUint32(8, Endian.big) != 0x57415645) {
      return null;
    }

    int offset = 12;
    int audioFormat = 1;
    int channels = 1;
    int sampleRate = 44100;
    int bitsPerSample = 16;
    int? dataOffset;
    int dataSize = 0;

    while (offset + 8 <= bytes.length) {
      final int chunkId = bd.getUint32(offset, Endian.big);
      final int chunkSize = bd.getUint32(offset + 4, Endian.little);
      final int bodyOffset = offset + 8;
      if (bodyOffset + chunkSize > bytes.length) break;

      if (chunkId == 0x666d7420 && chunkSize >= 16) {
        // "fmt "
        audioFormat = bd.getUint16(bodyOffset, Endian.little);
        channels = bd.getUint16(bodyOffset + 2, Endian.little);
        sampleRate = bd.getUint32(bodyOffset + 4, Endian.little);
        bitsPerSample = bd.getUint16(bodyOffset + 14, Endian.little);
      } else if (chunkId == 0x64617461) {
        // "data"
        dataOffset = bodyOffset;
        dataSize = chunkSize;
        break;
      }
      offset = bodyOffset + chunkSize + (chunkSize.isOdd ? 1 : 0);
    }

    if (audioFormat != 1 ||
        bitsPerSample != 16 ||
        channels < 1 ||
        dataOffset == null ||
        dataSize < 2) {
      return null;
    }

    final int sampleCount = dataSize ~/ 2;
    final samples = Int16List(sampleCount);
    for (int i = 0; i < sampleCount; i++) {
      samples[i] = bd.getInt16(dataOffset + i * 2, Endian.little);
    }
    return _WavData(
      sampleRate: sampleRate,
      channels: channels,
      samples: samples,
    );
  }

  static List<double> _toMonoNormalized(Int16List samples, int channels) {
    if (channels <= 1) {
      return List<double>.generate(
        samples.length,
        (i) => samples[i] / 32768.0,
      );
    }
    final int frames = samples.length ~/ channels;
    return List<double>.generate(frames, (i) {
      double acc = 0.0;
      for (int c = 0; c < channels; c++) {
        acc += samples[i * channels + c] / 32768.0;
      }
      return acc / channels;
    });
  }

  static Uint8List _encodePcm16Wav(List<double> mono, int sampleRate) {
    final int dataBytes = mono.length * 2;
    final out = Uint8List(44 + dataBytes);
    final bd = ByteData.sublistView(out);
    // "RIFF"
    bd.setUint32(0, 0x52494646, Endian.big);
    bd.setUint32(4, 36 + dataBytes, Endian.little);
    // "WAVE"
    bd.setUint32(8, 0x57415645, Endian.big);
    // "fmt "
    bd.setUint32(12, 0x666d7420, Endian.big);
    bd.setUint32(16, 16, Endian.little);
    bd.setUint16(20, 1, Endian.little); // PCM
    bd.setUint16(22, 1, Endian.little); // mono
    bd.setUint32(24, sampleRate, Endian.little);
    bd.setUint32(28, sampleRate * 2, Endian.little);
    bd.setUint16(32, 2, Endian.little);
    bd.setUint16(34, 16, Endian.little);
    // "data"
    bd.setUint32(36, 0x64617461, Endian.big);
    bd.setUint32(40, dataBytes, Endian.little);
    for (int i = 0; i < mono.length; i++) {
      final int pcm = (mono[i].clamp(-1.0, 1.0) * 32767.0).round();
      bd.setInt16(44 + i * 2, pcm, Endian.little);
    }
    return out;
  }
}

class _WavData {
  const _WavData({
    required this.sampleRate,
    required this.channels,
    required this.samples,
  });

  final int sampleRate;
  final int channels;
  final Int16List samples;
}
