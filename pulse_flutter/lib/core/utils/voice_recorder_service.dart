import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_io/io.dart';

import 'package:path_provider/path_provider.dart';
import 'package:pulse_flutter/services/audio/voice_filter_preset.dart';
import 'package:pulse_flutter/services/audio/voice_filter_processor.dart';
import 'package:record/record.dart';

class VoiceRecorderService {
  VoiceRecorderService._();

  static final AudioRecorder _recorder = AudioRecorder();
  static Timer? _timer;
  static Timer? _amplitudeTimer;
  static Duration _duration = Duration.zero;
  static String? _currentPath;

  static final List<double> _recordedAmplitudes = [];
  static List<double> get lastRecordedAmplitudes =>
      List<double>.unmodifiable(_recordedAmplitudes);

  static Future<bool> get isRecording => _recorder.isRecording();

  static Future<bool> startRecording({
    required void Function(Duration duration) onTick,
    void Function(double normalizedAmplitude)? onAmplitude,
  }) async {
    if (!await _recorder.hasPermission()) return false;

    _recordedAmplitudes.clear();
    final Directory tempDir = await getTemporaryDirectory();
    final bool recordWav = !kIsWeb;
    final String ext = recordWav ? 'wav' : 'm4a';
    final String path =
        '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.$ext';
    _currentPath = path;

    await _recorder.start(
      RecordConfig(
        encoder: recordWav ? AudioEncoder.wav : AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: recordWav ? 24000 : 44100,
        numChannels: recordWav ? 1 : 2,
      ),
      path: path,
    );

    _duration = Duration.zero;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _duration += const Duration(seconds: 1);
      onTick(_duration);
    });

    // Amplitude polling for waveform visualization & persistence
    _amplitudeTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) async {
        try {
          final Amplitude amp = await _recorder.getAmplitude();
          // amp.current is in dBFS (typically -160 to 0).
          // Normalize to 0.0–1.0 range for UI.
          final double dbfs = amp.current;
          final double normalized =
              ((dbfs + 50.0) / 50.0).clamp(0.0, 1.0);
          _recordedAmplitudes.add(normalized);
          onAmplitude?.call(normalized);
        } catch (_) {
          // Recorder may have been disposed
        }
      },
    );

    return true;
  }

  static Future<String?> stopRecording({
    VoiceFilterPreset filterPreset = VoiceFilterPreset.none,
  }) async {
    _timer?.cancel();
    _timer = null;
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    final String? path = await _recorder.stop();
    _duration = Duration.zero;
    _currentPath = null;
    if (path != null &&
        !kIsWeb &&
        filterPreset != VoiceFilterPreset.none &&
        path.toLowerCase().endsWith('.wav')) {
      try {
        final File file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final processed = VoiceFilterProcessor.applyToWavBytes(
            bytes,
            filterPreset,
          );
          await file.writeAsBytes(processed, flush: true);
        }
      } catch (_) {
        // Fallback to raw recording if DSP processing fails.
      }
    }
    return path;
  }

  static Future<void> cancelRecording() async {
    _timer?.cancel();
    _timer = null;
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    // Clean up orphaned temp file
    if (_currentPath != null) {
      try {
        final File tempFile = File(_currentPath!);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {
        // Best-effort cleanup
      }
    }
    _currentPath = null;
    _duration = Duration.zero;
  }

  static String formatDuration(Duration d) {
    final int minutes = d.inMinutes;
    final int seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  static void dispose() {
    _timer?.cancel();
    _amplitudeTimer?.cancel();
  }
}
