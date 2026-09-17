import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

/// Material 3 Expressive design tokens for NiosMess calls.
class CallTokens {
  const CallTokens._();

  // Expressive Corner Radii
  static const double cardBorderRadius = 24.0;
  static const double dockBorderRadius = 28.0;
  static const double pipBorderRadius = 20.0;
  static const double buttonBorderRadius = 20.0;
  static const double pillBorderRadius = 100.0;

  // Elevation: strictly 0.0 per M3 Expressive protocol
  static const double cardElevation = 0.0;
  static const double dockElevation = 0.0;

  // Component Dimensions
  static const double avatarSmallSize = 48.0;
  static const double avatarLargeSize = 128.0;
  static const double controlButtonSize = 56.0;
  static const double endCallButtonSize = 64.0;
  static const double incomingButtonSize = 56.0;
  static const double videoPipWidth = 120.0;
  static const double videoPipHeight = 180.0;
  static const double meetEndButtonWidth = 80.0;
  static const double meetEndButtonHeight = 56.0;
  static const double meetActionButtonSize = 56.0;
  static const double meetTileBorderRadius = 24.0;

  // Dark Tonal Palette Tokens for Call Screens
  static const Color darkSurface = Color(0xFF111318);
  static const Color meetSurface = Color(0xFF131314);
  static const Color darkSurfaceContainerHigh = Color(0xFF282A2F);
  static const Color darkSurfaceContainerHighest = Color(0xFF33353A);
  static const Color meetTileBackground = Color(0xFF1E1F20);
  static const Color meetChipBackground = Color(0xFF282A2F);

  // Animation Durations
  static const Duration incomingOverlayAnimationDuration = Duration(milliseconds: 320);
  static const Duration controlsFadeDuration = Duration(milliseconds: 220);
  static const Duration exitAnimationDuration = Duration(milliseconds: 280);
  static const Duration controlsAutoHideDuration = Duration(seconds: 4);
  static const Duration rippleAnimationDuration = Duration(milliseconds: 2000);

  // M3 Expressive Animation Curves
  static const Curve incomingOverlayCurve = M3SpringCurves.spatial;
  static const Curve exitCurve = M3SpringCurves.snappy;
  // Normalized smooth curve for Opacity / FadeTransition
  static const Curve controlsFadeCurve = Curves.easeInOutCubic;
  static const Curve controlsScaleCurve = M3SpringCurves.snappy;
  static const Curve rippleCurve = M3SpringCurves.gentle;
}
