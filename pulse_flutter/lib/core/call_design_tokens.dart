import 'package:flutter/material.dart';

class CallTokens {
  // Durations
  static const Duration incomingOverlayAnimationDuration = Duration(milliseconds: 280);
  static const Duration controlsFadeDuration = Duration(milliseconds: 220);
  static const Duration exitAnimationDuration = Duration(milliseconds: 300);
  static const Duration controlsAutoHideDuration = Duration(seconds: 4);
  static const Duration rippleAnimationDuration = Duration(milliseconds: 2400);

  // Dimensions
  static const double avatarSmallSize = 44.0;
  static const double avatarLargeSize = 120.0;
  static const double controlButtonSize = 56.0;
  static const double endCallButtonSize = 64.0;
  static const double incomingButtonSize = 56.0;
  static const double videoPipWidth = 124.0;
  static const double videoPipHeight = 186.0;
  static const double dockBorderRadius = 32.0;
  static const double cardBorderRadius = 28.0;
  static const double cardElevation = 4.0;

  // Glassmorphism
  static const double glassBlur = 24.0;
  static const double glassBorderWidth = 1.0;

  // Curves
  static const Curve incomingOverlayCurve = Curves.easeOutBack;
  static const Curve exitCurve = Curves.easeInCubic;
  static const Curve controlsFadeCurve = Curves.easeInOutCubic;
  static const Curve rippleCurve = Curves.easeOutCubic;

  // Generative Bg Refresh Rate
  static const double visualizerFps = 20.0;
  static const Duration visualizerFrameDuration = Duration(milliseconds: (1000 ~/ visualizerFps));
}
