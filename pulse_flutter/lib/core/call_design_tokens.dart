import 'package:flutter/material.dart';

class CallTokens {
  // Surface colors for immersive dark call mode
  static const Color darkSurface = Color(0xFF0D0F14);
  static const Color darkSurfaceContainerLow = Color(0xFF13161F);
  static const Color darkSurfaceContainer = Color(0xFF191D28);
  static const Color darkSurfaceContainerHigh = Color(0xFF202533);
  static const Color darkSurfaceContainerHighest = Color(0xFF282E3E);

  // Google Meet Layout Tokens
  static const Color meetSurface = Color(0xFF111318);
  static const Color meetTileBackground = Color(0xFF1E2025);
  static const Color meetChipBackground = Color(0xB3000000);
  static const double meetTileBorderRadius = 28.0;
  static const double meetEndButtonWidth = 78.0;
  static const double meetEndButtonHeight = 52.0;
  static const double meetActionButtonSize = 52.0;

  // Durations
  static const Duration incomingOverlayAnimationDuration = Duration(milliseconds: 280);
  static const Duration controlsFadeDuration = Duration(milliseconds: 220);
  static const Duration exitAnimationDuration = Duration(milliseconds: 300);
  static const Duration controlsAutoHideDuration = Duration(seconds: 4);
  static const Duration rippleAnimationDuration = Duration(milliseconds: 2400);

  // Dimensions
  static const double avatarSmallSize = 48.0;
  static const double avatarLargeSize = 136.0;
  static const double controlButtonSize = 56.0;
  static const double endCallButtonSize = 64.0;
  static const double incomingButtonSize = 52.0;
  static const double videoPipWidth = 124.0;
  static const double videoPipHeight = 186.0;
  static const double dockBorderRadius = 32.0;
  static const double cardBorderRadius = 28.0;
  static const double cardElevation = 3.0;
  static const double pipBorderRadius = 24.0;

  // Curves (Material 3 Expressive)
  static const Curve incomingOverlayCurve = Curves.easeOutCubic;
  static const Curve exitCurve = Curves.easeInCubic;
  static const Curve controlsFadeCurve = Curves.easeInOutCubic;
  static const Curve rippleCurve = Curves.easeOutCubic;
}
