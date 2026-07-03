import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SystemUtils {
  SystemUtils._();

  static const MethodChannel _channel = MethodChannel('app.niosmess/system');

  static Future<void> minimizeApp() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('minimizeApp');
    } on MissingPluginException {
      debugPrint('[SystemUtils] minimizeApp not supported on this platform');
    } catch (e) {
      debugPrint('[SystemUtils] minimizeApp error: $e');
    }
  }

  static Future<void> requestIgnoreBatteryOptimizations() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('requestIgnoreBatteryOptimizations');
    } on MissingPluginException {
      debugPrint('[SystemUtils] requestIgnoreBatteryOptimizations not supported');
    } catch (e) {
      debugPrint('[SystemUtils] requestIgnoreBatteryOptimizations error: $e');
    }
  }
}
