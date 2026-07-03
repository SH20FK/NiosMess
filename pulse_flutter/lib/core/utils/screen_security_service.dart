import 'package:flutter/services.dart';

class ScreenSecurityService {
  static const MethodChannel _channel = MethodChannel('com.niosmess.pulse/security');

  static Future<void> setSecureFlag({required bool enabled}) async {
    try {
      await _channel.invokeMethod('setSecureFlag', enabled);
    } catch (e) {
      // Platform not supported or not available
    }
  }
}
