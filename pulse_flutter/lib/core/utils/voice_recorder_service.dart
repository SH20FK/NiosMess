import 'dart:async';
import 'package:universal_io/io.dart';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class VoiceRecorderService {
  VoiceRecorderService._();

  static final AudioRecorder _recorder = AudioRecorder();
  static Timer? _timer;
  static Timer? _amplitudeTimer;
  static Duration _duration = Duration.zero;
  static String? _currentPath;

  static Future<bool> get isRecording => _recorder.isRecording();

  static Future<bool> startRecording({
    required void Function(Duration duration) onTick,
    void Function(double normalizedAmplitude)? onAmplitude,
  }) async {
    if (!await _recorder.hasPermission()) return false;

    final Directory tempDir = await getTemporaryDirectory();
    final String path =
        '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    _currentPath = path;

    await _recorder.start(
      RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );

    _duration = Duration.zero;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _duration += const Duration(seconds: 1);
      onTick(_duration);
    });

    // Amplitude polling for waveform visualization
    if (onAmplitude != null) {
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
            onAmplitude(normalized);
          } catch (_) {
            // Recorder may have been disposed
          }
        },
      );
    }

    return true;
  }

  static Future<String?> stopRecording() async {
    _timer?.cancel();
    _timer = null;
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    final String? path = await _recorder.stop();
    _duration = Duration.zero;
    _currentPath = null;
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
