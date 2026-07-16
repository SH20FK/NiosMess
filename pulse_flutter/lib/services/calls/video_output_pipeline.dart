import 'dart:async';
import 'package:flutter/foundation.dart';

/// Callback when a new remote video frame is available.
typedef OnVideoFrame = void Function(Uint8List jpeg);

/// Receives decrypted video frames and notifies the UI.
///
/// In Phase 2, this stores the latest JPEG frame and emits it
/// to registered listeners. With a proper VP8 decoder, this would
/// decode VP8 → YUV → display.
class VideoOutputPipeline {
  VideoOutputPipeline();

  int _frameCount = 0;
  Uint8List? _latestFrame;
  bool _stopped = false;

  final StreamController<Uint8List> _frameController =
      StreamController<Uint8List>.broadcast();

  /// Stream of decoded video frames as JPEG bytes.
  Stream<Uint8List> get frameStream => _frameController.stream;

  /// The most recent frame, or null.
  Uint8List? get latestFrame => _latestFrame;
  int get frameCount => _frameCount;

  void start() {
    _stopped = false;
    debugPrint('[VideoOutput] Started');
  }

  /// Push a decrypted video payload (JPEG bytes or VP8 ES).
  void pushFrame(Uint8List data) {
    if (_stopped) return;
    _latestFrame = data;
    _frameCount++;
    _frameController.add(data);
  }

  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    _latestFrame = null;
    debugPrint('[VideoOutput] Stopped');
  }

  void dispose() {
    stop();
    _frameController.close();
  }
}
