import 'package:audioplayers/audioplayers.dart';
import 'output_test_tone.dart';

/// Native playback uses the system output, independently of WebRTC routing.
/// The UI names this test accordingly rather than claiming sink selection.
Future<void> playOutputTest(String device) async {
  final player = AudioPlayer();
  try {
    await player.play(BytesSource(outputTestTone(), mimeType: 'audio/wav'));
    await Future<void>.delayed(const Duration(milliseconds: 650));
  } finally {
    await player.dispose();
  }
}
