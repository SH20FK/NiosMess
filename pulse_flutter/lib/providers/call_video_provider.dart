import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

/// The latest remote video frame as JPEG bytes.
final StateProvider<Uint8List?> remoteVideoFrameProvider =
    StateProvider<Uint8List?>((_) => null);

/// Whether the local camera is enabled.
final StateProvider<bool> localVideoEnabledProvider =
    StateProvider<bool>((_) => true);

/// Listen to a video frame stream and update [remoteVideoFrameProvider].
void startListeningToVideoFrames(
  WidgetRef ref,
  Stream<Uint8List> frameStream, {
  StreamSubscription<Uint8List>? existingSub,
}) {
  existingSub?.cancel();
  existingSub = frameStream.listen((frame) {
    ref.read(remoteVideoFrameProvider.notifier).state = frame;
  });
}
