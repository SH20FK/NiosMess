import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Capabilities of the implemented client paths, not a browser-name guess.
class ClientCapabilities {
  const ClientCapabilities({required this.isWeb, required this.platform});
  final bool isWeb;
  final TargetPlatform platform;

  // Current recorders hand a native file path to the upload queue.
  bool get nativeRecording => !isWeb;
  bool get haptics =>
      !isWeb &&
      (platform == TargetPlatform.android || platform == TargetPlatform.iOS);
  bool get desktopFiles =>
      !isWeb &&
      (platform == TargetPlatform.windows ||
          platform == TargetPlatform.linux ||
          platform == TargetPlatform.macOS);
  bool get browserWorkspace => isWeb;
}

final clientCapabilitiesProvider = Provider<ClientCapabilities>(
  (ref) => ClientCapabilities(isWeb: kIsWeb, platform: defaultTargetPlatform),
);
