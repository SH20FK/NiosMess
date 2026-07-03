import 'dart:async';
import 'dart:typed_data';

import 'package:record_platform_interface/record_platform_interface.dart';

class RecordLinux extends RecordMethodChannelPlatformInterface {
  RecordLinux() {
    try {
      RecordPlatform.instance = this;
    } catch (_) {}
  }

  /// Minimal implementation to satisfy the platform interface.
  /// Replace with real audio-capture logic for production.
  @override
  Future<Stream<Uint8List>> startStream(String recorderId, RecordConfig config) async {
    // Returning an empty stream for now to avoid compilation errors.
    return Stream<Uint8List>.empty();
  }

  /// Updated signature with the named parameter `request` required by the interface.
  @override
  Future<bool> hasPermission(String recorderId, {bool request = true}) async {
    // Minimal behavior: assume permission is granted. Replace with real checks.
    return true;
  }
}
