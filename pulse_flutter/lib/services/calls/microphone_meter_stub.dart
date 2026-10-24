import 'package:flutter_webrtc/flutter_webrtc.dart';

class MicrophoneMeter {
  MicrophoneMeter(this._peer);
  final RTCPeerConnection _peer;
  Future<double?> readLevel() async {
    final stats = await _peer.getStats();
    for (final report in stats) {
      final level = report.values['audioLevel'];
      if (level is num) return level.toDouble().clamp(0, 1);
    }
    return null;
  }

  Future<void> dispose() async {
    await _peer.close();
    await _peer.dispose();
  }
}

Future<MicrophoneMeter> openMicrophoneMeter(MediaStream stream) async {
  final peer = await createPeerConnection({'iceServers': []});
  try {
    for (final track in stream.getAudioTracks()) {
      await peer.addTrack(track, stream);
    }
    return MicrophoneMeter(peer);
  } catch (_) {
    await peer.close();
    await peer.dispose();
    rethrow;
  }
}
