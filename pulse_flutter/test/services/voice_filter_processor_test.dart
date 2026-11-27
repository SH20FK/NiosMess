import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/services/audio/voice_filter_preset.dart';
import 'package:pulse_flutter/services/audio/voice_filter_processor.dart';

Uint8List _buildTestWav({int sampleRate = 24000, int durationMs = 200}) {
  final int numSamples = (sampleRate * durationMs) ~/ 1000;
  final int dataBytes = numSamples * 2;
  final bytes = Uint8List(44 + dataBytes);
  final bd = ByteData.sublistView(bytes);
  bd.setUint32(0, 0x52494646, Endian.big); // RIFF
  bd.setUint32(4, 36 + dataBytes, Endian.little);
  bd.setUint32(8, 0x57415645, Endian.big); // WAVE
  bd.setUint32(12, 0x666d7420, Endian.big); // fmt
  bd.setUint32(16, 16, Endian.little);
  bd.setUint16(20, 1, Endian.little);
  bd.setUint16(22, 1, Endian.little);
  bd.setUint32(24, sampleRate, Endian.little);
  bd.setUint32(28, sampleRate * 2, Endian.little);
  bd.setUint16(32, 2, Endian.little);
  bd.setUint16(34, 16, Endian.little);
  bd.setUint32(36, 0x64617461, Endian.big); // data
  bd.setUint32(40, dataBytes, Endian.little);
  for (int i = 0; i < numSamples; i++) {
    final double s = math.sin(2.0 * math.pi * 220.0 * i / sampleRate);
    bd.setInt16(44 + i * 2, (s * 16000).round(), Endian.little);
  }
  return bytes;
}

void main() {
  test('VoiceFilterProcessor preserves none and produces valid WAV for all presets', () {
    final raw = _buildTestWav();
    expect(
      VoiceFilterProcessor.applyToWavBytes(raw, VoiceFilterPreset.none),
      same(raw),
    );

    for (final preset in VoiceFilterPreset.values) {
      if (preset == VoiceFilterPreset.none) continue;
      final out = VoiceFilterProcessor.applyToWavBytes(raw, preset);
      expect(out.length, greaterThan(44), reason: preset.id);
      final bd = ByteData.sublistView(out);
      expect(bd.getUint32(0, Endian.big), 0x52494646, reason: preset.id);
      expect(bd.getUint32(8, Endian.big), 0x57415645, reason: preset.id);
      // Verify audio is non-silent.
      double energy = 0;
      for (int i = 44; i + 1 < out.length; i += 2) {
        final v = bd.getInt16(i, Endian.little) / 32768.0;
        energy += v * v;
      }
      expect(energy, greaterThan(1.0), reason: preset.id);
    }
  });
}
