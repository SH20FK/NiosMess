/// Capture requests use the keys actually read by Android/iOS WebRTC and
/// modern browser media constraints. Gateway limits remain authoritative.
class CallCaptureProfile {
  CallCaptureProfile(int gatewayHeight)
    : height = gatewayHeight > 0 ? gatewayHeight.clamp(1, 1080) : 480;
  final int height;
  int get width => (((height * 16 / 9).round() ~/ 2) * 2).clamp(2, 1920);
  int get videoBitrate => height <= 240
      ? 400000
      : height <= 480
      ? 1200000
      : height <= 720
      ? 2400000
      : 4000000;
  Map<String, dynamic> constraints({
    required bool isWeb,
    required bool video,
  }) => {
    'audio': {
      'echoCancellation': true,
      'noiseSuppression': true,
      'autoGainControl': true,
      if (isWeb) 'channelCount': {'ideal': 1},
      if (isWeb) 'sampleRate': {'ideal': 48000},
      if (!isWeb)
        'optional': [
          {'googEchoCancellation': true},
          {'googNoiseSuppression': true},
          {'googAutoGainControl': true},
          {'googHighpassFilter': true},
        ],
    },
    'video': video
        ? {
            'width': isWeb ? {'ideal': width, 'max': width} : width,
            'height': isWeb ? {'ideal': height, 'max': height} : height,
            'frameRate': isWeb ? {'ideal': 30, 'max': 30} : 30,
            'facingMode': 'user',
          }
        : false,
  };
}
