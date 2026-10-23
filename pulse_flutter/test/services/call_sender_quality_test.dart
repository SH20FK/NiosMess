import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:pulse_flutter/services/calls/call_capture_profile.dart';
import 'package:pulse_flutter/services/calls/call_sender_quality.dart';

class _Track extends Fake implements MediaStreamTrack {
  _Track(this.kind);
  @override
  final String kind;
  @override
  Map<String, dynamic> getSettings() => {'width': 1920, 'height': 1080};
}

class _Sender extends Fake implements RTCRtpSender {
  _Sender(String kind, this.parameters) : track = _Track(kind);
  @override
  final MediaStreamTrack track;
  @override
  final RTCRtpParameters parameters;
  RTCRtpParameters? applied;
  @override
  Future<bool> setParameters(RTCRtpParameters parameters) async {
    applied = parameters;
    return true;
  }
}

void main() {
  test(
    'sender tuning preserves negotiated identifiers and a tighter engine limit',
    () async {
      final codec = RTCRTPCodec(payloadType: 96, name: 'VP8', kind: 'video');
      final encoding = RTCRtpEncoding(
        ssrc: 123,
        rid: 'f',
        maxBitrate: 600000,
        maxFramerate: 24,
      );
      final params = RTCRtpParameters(
        transactionId: 'negotiated',
        codecs: [codec],
        encodings: [encoding],
      );
      final sender = _Sender('video', params);
      expect(await configureCallSender(sender, CallCaptureProfile(480)), true);
      expect(identical(sender.applied, params), true);
      expect(params.transactionId, 'negotiated');
      expect(params.codecs, [codec]);
      expect(params.encodings, [encoding]);
      expect(encoding.ssrc, 123);
      expect(encoding.rid, 'f');
      expect(encoding.maxBitrate, 600000);
      expect(encoding.maxFramerate, 24);
      expect(encoding.minBitrate, isNull);
      expect(encoding.scaleResolutionDownBy, greaterThanOrEqualTo(1080 / 480));
      expect(params.degradationPreference, RTCDegradationPreference.BALANCED);
    },
  );
  test(
    'audio receives a bounded ceiling and priority without changing video-only fields',
    () async {
      final encoding = RTCRtpEncoding(ssrc: 5);
      final sender = _Sender('audio', RTCRtpParameters(encodings: [encoding]));
      expect(await configureCallSender(sender, CallCaptureProfile(720)), true);
      expect(encoding.maxBitrate, 64000);
      expect(encoding.priority, RTCPriorityType.high);
      expect(encoding.maxFramerate, isNull);
    },
  );
  test(
    'an unnegotiated sender is left alone instead of inventing encodings',
    () async {
      final sender = _Sender('video', RTCRtpParameters(encodings: []));
      expect(await configureCallSender(sender, CallCaptureProfile(480)), false);
      expect(sender.applied, isNull);
    },
  );
  test(
    'zero native bitrate and frame rate defaults never turn off the video sender',
    () async {
      final encoding = RTCRtpEncoding(maxBitrate: 0, maxFramerate: 0);
      final sender = _Sender('video', RTCRtpParameters(encodings: [encoding]));
      await configureCallSender(sender, CallCaptureProfile(480));
      expect(encoding.maxFramerate, 30);
      expect(encoding.maxBitrate, 1200000);
    },
  );
}
