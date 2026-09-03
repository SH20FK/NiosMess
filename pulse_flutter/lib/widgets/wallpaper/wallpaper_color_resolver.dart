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
