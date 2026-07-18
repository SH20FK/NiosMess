import 'dart:async';
import 'package:universal_io/io.dart';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class VoiceRecorderService {
  VoiceRecorderService._();

  static final AudioRecorder _recorder = AudioRecorder();
  static Timer? _timer;
  static Duration _duration = Duration.zero;

  static Future<bool> get isRecording => _recorder.isRecording();

  static Future<bool> startRecording({
    required void Function(Duration duration) onTick,
  }) async {
    if (!await _recorder.hasPermission()) return false;

    final Directory tempDir = await getTemporaryDirectory();
    final String path =
        '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

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

    return true;
  }

  static Future<String?> stopRecording() async {
    _timer?.cancel();
    _timer = null;
    final String? path = await _recorder.stop();
    _duration = Duration.zero;
    return path;
  }

  static Future<void> cancelRecording() async {
    _timer?.cancel();
    _timer = null;
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    _duration = Duration.zero;
  }

  static String formatDuration(Duration d) {
    final int minutes = d.inMinutes;
    final int seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  static void dispose() {
    _timer?.cancel();
  }
}
