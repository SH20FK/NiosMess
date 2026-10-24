import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'call_capture_profile.dart';

class CallDevices {
  const CallDevices({this.microphone = '', this.camera = '', this.output = ''});
  final String microphone, camera, output;

  Map<String, dynamic> constraints({required bool video, int maxHeight = 480}) {
    final result = CallCaptureProfile(
      maxHeight,
    ).constraints(isWeb: kIsWeb, video: video);
    if (microphone.isNotEmpty) {
      if (kIsWeb) {
        (result['audio'] as Map)['deviceId'] = {'exact': microphone};
      } else {
        final audio = result['audio'] as Map;
        audio['optional'] = <dynamic>[
          ...(audio['optional'] as List),
          {'sourceId': microphone},
        ];
      }
    }
    if (video && camera.isNotEmpty) {
      final settings = result['video'] as Map;
      settings.remove('facingMode');
      settings['deviceId'] = kIsWeb ? {'exact': camera} : camera;
      if (!kIsWeb) {
        settings['optional'] = [
          {'sourceId': camera},
        ];
      }
    }
    return result;
  }

  Future<void> applyOutput(RTCVideoRenderer renderer) async {
    if (kIsWeb) {
      if (!await renderer.audioOutput(output)) {
        throw StateError('audio_output_unavailable');
      }
    } else {
      await selectNativeCallOutput(output);
    }
  }
}

class CallDevicesNotifier extends Notifier<CallDevices> {
  @override
  CallDevices build() => const CallDevices();
  void select(CallDevices devices) => state = devices;
}

// Device IDs stay on this client and are never sent to the server.
final callDevicesProvider = NotifierProvider<CallDevicesNotifier, CallDevices>(
  CallDevicesNotifier.new,
);

Future<void> selectNativeCallOutput(String device) async {
  if (device.isNotEmpty) {
    await Helper.selectAudioOutput(device);
    return;
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    await Helper.clearAndroidCommunicationDevice();
  } else if (defaultTargetPlatform == TargetPlatform.iOS) {
    await Helper.setSpeakerphoneOn(false);
  } else {
    final outputs = (await navigator.mediaDevices.enumerateDevices())
        .where((d) => d.kind == 'audiooutput')
        .toList();
    if (outputs.isNotEmpty) {
      await Helper.selectAudioOutput(
        outputs.where((d) => d.deviceId == 'default').firstOrNull?.deviceId ??
            outputs.first.deviceId,
      );
    }
  }
}
