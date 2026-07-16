import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class RemoteVideoFrameNotifier extends Notifier<Uint8List?> {
  @override
  Uint8List? build() => null;
  void set(Uint8List? frame) => state = frame;
}

/// The latest remote video frame as JPEG bytes.
final remoteVideoFrameProvider = NotifierProvider<RemoteVideoFrameNotifier, Uint8List?>(
  RemoteVideoFrameNotifier.new,
);

class LocalVideoEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  void set(bool enabled) => state = enabled;
}

/// Whether the local camera is enabled.
final localVideoEnabledProvider = NotifierProvider<LocalVideoEnabledNotifier, bool>(
  LocalVideoEnabledNotifier.new,
);

/// Listen to a video frame stream and update [remoteVideoFrameProvider].
void startListeningToVideoFrames(
  WidgetRef ref,
  Stream<Uint8List> frameStream, {
  StreamSubscription<Uint8List>? existingSub,
}) {
  existingSub?.cancel();
  existingSub = frameStream.listen((frame) {
    ref.read(remoteVideoFrameProvider.notifier).set(frame);
  });
}
