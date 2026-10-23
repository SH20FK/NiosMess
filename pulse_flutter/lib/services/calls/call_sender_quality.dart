import 'dart:math' as math;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'call_capture_profile.dart';

/// Caps are ceilings, not forced rates. WebRTC retains congestion control,
/// downscaling and recovery; no SDP munging or minimum bitrate is imposed.
Future<bool> configureCallSender(
  RTCRtpSender sender,
  CallCaptureProfile profile,
) async {
  final kind = sender.track?.kind;
  if (kind != 'audio' && kind != 'video') return false;
  final parameters = sender.parameters;
  final encodings = parameters.encodings;
  // Preserve the negotiated encoding count, transaction, codecs and SSRCs.
  if (encodings == null || encodings.isEmpty) return false;
  for (final encoding in encodings) {
    final limit = kind == 'audio' ? 64000 : profile.videoBitrate;
    final existingLimit = encoding.maxBitrate;
    encoding.maxBitrate = existingLimit != null && existingLimit > 0
        ? math.min(existingLimit, limit)
        : limit;
    encoding.priority = kind == 'audio'
        ? RTCPriorityType.high
        : RTCPriorityType.medium;
    if (kind == 'video') {
      final existingRate = encoding.maxFramerate;
      encoding.maxFramerate = existingRate != null && existingRate > 0
          ? math.min(existingRate, 30)
          : 30;
      try {
        final settings = sender.track!.getSettings();
        final height = settings['height'];
        final width = settings['width'];
        final scale = math.max(
          height is num ? height / profile.height : 1.0,
          width is num ? width / profile.width : 1.0,
        );
        encoding.scaleResolutionDownBy = math.max(
          encoding.scaleResolutionDownBy ?? 1.0,
          scale,
        );
      } catch (_) {
        /* Track settings are optional on older native engines. */
      }
    }
  }
  if (kind == 'video') {
    parameters.degradationPreference = RTCDegradationPreference.BALANCED;
  }
  return sender.setParameters(parameters);
}
