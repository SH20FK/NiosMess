import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class WallpaperColorResolver {
  const WallpaperColorResolver._();

  static Color resolveBackground(ColorScheme scheme, String role) {
    switch (role) {
      case 'surface':
        return scheme.surface;
      case 'surfaceContainerLowest':
        return scheme.surfaceContainerLowest;
      case 'surfaceContainerLow':
        return scheme.surfaceContainerLow;
      case 'surfaceContainer':
        return scheme.surfaceContainer;
      case 'surfaceContainerHigh':
        return scheme.surfaceContainerHigh;
      case 'surfaceContainerHighest':
        return scheme.surfaceContainerHighest;
      case 'primaryContainer':
        return scheme.primaryContainer;
      case 'secondaryContainer':
        return scheme.secondaryContainer;
      case 'tertiaryContainer':
        return scheme.tertiaryContainer;
      default:
        return scheme.surfaceContainerLow;
    }
  }

  static Shader createLinearGradientShader({
    required ColorScheme scheme,
    required String role1,
    required String role2,
    required double angleDeg,
    required Size size,
  }) {
    final Color c1 = resolveBackground(scheme, role1);
    final Color c2 = resolveBackground(scheme, role2);
    final double rad = angleDeg * pi / 180.0;
    final double cx = size.width / 2.0;
    final double cy = size.height / 2.0;
    final double halfDiag = (size.width + size.height) * 0.5;
    final double dx = cos(rad) * halfDiag;
    final double dy = sin(rad) * halfDiag;
    return ui.Gradient.linear(
      Offset(cx - dx, cy - dy),
      Offset(cx + dx, cy + dy),
      <Color>[c1, c2],
    );
  }

  static Shader createRadialGlowShader({
    required ColorScheme scheme,
    required String centerRole,
    required String outerRole,
    required Size size,
  }) {
    final Color cCenter = resolveBackground(scheme, centerRole);
    final Color cOuter = resolveBackground(scheme, outerRole);
    final double radius = max(size.width, size.height) * 0.75;
    return ui.Gradient.radial(
      Offset(size.width / 2.0, size.height / 2.0),
      radius,
      <Color>[cCenter, cOuter],
    );
  }

  static Color resolveIconColor(
    ColorScheme scheme,
    String role,
    double alpha,
  ) {
    Color base;
    switch (role) {
      case 'primary':
        base = scheme.primary;
        break;
      case 'secondary':
        base = scheme.secondary;
        break;
      case 'tertiary':
        base = scheme.tertiary;
        break;
      case 'outline':
        base = scheme.outline;
        break;
      case 'outlineVariant':
        base = scheme.outlineVariant;
        break;
      case 'onSurface':
        base = scheme.onSurface;
        break;
      case 'onSurfaceVariant':
        base = scheme.onSurfaceVariant;
        break;
      case 'primaryContainer':
        base = scheme.primaryContainer;
        break;
      case 'secondaryContainer':
        base = scheme.secondaryContainer;
        break;
      case 'tertiaryContainer':
        base = scheme.tertiaryContainer;
        break;
      default:
        base = scheme.primary;
        break;
    }
    return base.withValues(alpha: alpha.clamp(0.01, 1.0));
  }
}
