import 'package:flutter/services.dart';

class HapticService {
  HapticService._();

  static void tap() => HapticFeedback.selectionClick();
  static void confirm() => HapticFeedback.mediumImpact();
  static void destructive() => HapticFeedback.heavyImpact();
  static void reaction() => HapticFeedback.lightImpact();
  static void notification() => HapticFeedback.mediumImpact();
}
