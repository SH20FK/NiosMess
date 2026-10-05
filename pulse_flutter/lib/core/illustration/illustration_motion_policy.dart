import 'package:flutter/widgets.dart';

enum AppIllustrationMotionPolicy {
  never,
  once,
  subtle;

  bool shouldAnimate(BuildContext context) {
    if (this == never) return false;
    final MediaQueryData? data = MediaQuery.maybeOf(context);
    if (data != null && data.disableAnimations) {
      return false;
    }
    return true;
  }
}
