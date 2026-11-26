/// Capture requests use the keys actually read by Android/iOS WebRTC and
/// modern browser media constraints. Gateway limits remain authoritative.
class CallCaptureProfile {
  CallCaptureProfile(int gatewayHeight, {int maxFps = 30})
    : height = gatewayHeight > 0 ? gatewayHeight.clamp(1, 1440) : 480,
      maxFps = maxFps > 0 ? maxFps.clamp(15, 60) : 30;
  final int height;
  final int maxFps;
  int get width => (((height * 16 / 9).round() ~/ 2) * 2).clamp(2, 2560);
  int get videoBitrate => height <= 240
      ? 400000
      : height <= 480
      ? 1200000
      : height <= 720
      ? 2400000
      : height <= 1080
      ? 5000000
      : 8000000;
  int get screenBitrate => height <= 480
      ? 1500000
      : height <= 720
      ? 3000000
      : height <= 1080
      ? 6000000
      : 8000000;
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
            'frameRate': isWeb ? {'ideal': maxFps, 'max': maxFps} : maxFps,
            'facingMode': 'user',
          }
        : false,
  };

  Map<String, dynamic> screenShareConstraints({
    required bool isWeb,
    String? sourceId,
  }) {
    final int screenFps = height >= 1080 ? (maxFps >= 60 ? 60 : 30) : 20;
    if (isWeb) {
      return <String, dynamic>{
        'audio': false,
        'video': <String, dynamic>{
          'width': <String, dynamic>{'ideal': width, 'max': width},
          'height': <String, dynamic>{'ideal': height, 'max': height},
          'frameRate': <String, dynamic>{'ideal': screenFps, 'max': screenFps},
        },
      };
    }
    if (sourceId != null && sourceId.isNotEmpty) {
      return <String, dynamic>{
        'audio': false,
        'video': <String, dynamic>{
          'deviceId': <String, dynamic>{'exact': sourceId},
          'mandatory': <String, dynamic>{
            'frameRate': screenFps,
            'maxWidth': width,
            'maxHeight': height,
          },
        },
      };
    }
    return <String, dynamic>{
      'audio': false,
      'video': <String, dynamic>{
        'mandatory': <String, dynamic>{
          'frameRate': screenFps,
          'maxWidth': width,
          'maxHeight': height,
        },
      },
    };
  }
}
