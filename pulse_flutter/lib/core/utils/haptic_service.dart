import 'package:universal_io/io.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class HapticService {
  HapticService._();

  static bool get _supported =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  static void tap() {
    if (_supported) HapticFeedback.selectionClick();
  }

  static void selection() {
    if (_supported) HapticFeedback.selectionClick();
  }

  static void confirm() {
    if (_supported) HapticFeedback.mediumImpact();
  }

  static void destructive() {
    if (_supported) HapticFeedback.heavyImpact();
  }

  static void danger() {
    destructive();
  }

  static void reaction() {
    if (_supported) HapticFeedback.lightImpact();
  }

  static void lightImpact() {
    if (_supported) HapticFeedback.lightImpact();
  }

  static void notification() {
    if (_supported) HapticFeedback.mediumImpact();
  }

  static void mediumImpact() {
    if (_supported) HapticFeedback.mediumImpact();
  }
}
