import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';

/// Material 3 Expressive design tokens for NiosMess calls.
class CallTokens {
  const CallTokens._();

  // Expressive Corner Radii
  static const double cardBorderRadius = 24.0;
  static const double dockBorderRadius = AppRadii.xl;
  static const double pipBorderRadius = 20.0;
  static const double buttonBorderRadius = 20.0;
  static const double pillBorderRadius = AppRadii.full;

  // Component Dimensions
  static const double avatarLargeSize = 128.0;
  static const double incomingButtonSize = AppHeights.lg;
  static const double videoPipWidth = 120.0;
  static const double videoPipHeight = 180.0;
  static const double meetEndButtonWidth = 80.0;
  static const double meetEndButtonHeight = AppHeights.lg;

  // Call screens are always dark. These mirror the dark ladder of
  // AppSurfaces; test/unit/call_tokens_test.dart keeps them in sync.
  static const Color darkSurface = Color(0xFF1A1A1A);
  static const Color darkSurfaceContainerHigh = Color(0xFF343434);
  static const Color darkSurfaceContainerHighest = Color(0xFF404040);

  /// Text and icons drawn over video or a dark call surface.
  static const Color onDarkSurface = Color(0xFFE6E6E6);

  // Animation Durations
  static const Duration incomingOverlayAnimationDuration = Duration(
    milliseconds: 320,
  );
  static const Duration controlsFadeDuration = M3Durations.effectsDefault;
  static const Duration controlsAutoHideDuration = Duration(seconds: 4);
  static const Duration rippleAnimationDuration = Duration(milliseconds: 2000);

  // M3 Expressive Animation Curves
  static const Curve incomingOverlayCurve = M3SpringCurves.spatialDefault;
  // Normalized smooth curve for Opacity / FadeTransition
  static const Curve controlsFadeCurve = M3SpringCurves.effectsDefault;
}
