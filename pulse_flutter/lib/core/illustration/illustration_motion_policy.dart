import 'package:flutter/widgets.dart';
import 'package:pulse_flutter/core/motion/m3_motion.dart';

enum AppIllustrationMotionPolicy {
  never,
  once,
  subtle;

  bool shouldAnimate(BuildContext context) {
    if (this == never) return false;
    return !context.reduceMotion;
  }
}
