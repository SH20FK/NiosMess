import 'package:flutter/material.dart';

class CallTokens {
  // Durations
  static const Duration incomingOverlayAnimationDuration = Duration(milliseconds: 250);
  static const Duration controlsFadeDuration = Duration(milliseconds: 200);
  static const Duration exitAnimationDuration = Duration(milliseconds: 300);
  static const Duration controlsAutoHideDuration = Duration(seconds: 3);

  // Dimensions
  static const double avatarSmallSize = 40.0;
  static const double avatarLargeSize = 96.0;
  static const double controlButtonSize = 56.0;
  static const double incomingButtonSize = 48.0;
  static const double videoPipWidth = 120.0;
  static const double videoPipHeight = 180.0;
  static const double cardBorderRadius = 24.0;
  static const double cardElevation = 3.0;

  // Curves
  static const Curve incomingOverlayCurve = Curves.easeOutCubic;
  static const Curve exitCurve = Curves.easeIn;
  static const Curve controlsFadeCurve = Curves.easeInOut;

  // Generative Bg Refresh Rate
  static const double visualizerFps = 15.0;
  static const Duration visualizerFrameDuration = Duration(milliseconds: (1000 ~/ visualizerFps));
}
