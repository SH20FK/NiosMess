import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Text scaler of the whole app: the system text size multiplied by the
/// in-app font size setting.
///
/// The system scaler is kept as it is, so a non-linear one (Android scales
/// large type less than small type) stays non-linear. The result is bounded:
/// layouts are tested up to 200%, and the largest system size combined with
/// the largest in-app size would go well past that.
class AppTextScaler extends TextScaler {
  const AppTextScaler({required this.system, required this.appScale});

  /// Smallest and largest text size relative to the unscaled one.
  static const double minScale = 0.85;
  static const double maxScale = 2.0;

  static const double _referenceFontSize = 14;

  /// Text size chosen in the system settings.
  final TextScaler system;

  /// Multiplier of the in-app font size setting.
  final double appScale;

  @override
  double scale(double fontSize) {
    final double scaled = system.scale(fontSize) * appScale;
    return math.min(
      math.max(scaled, fontSize * minScale),
      fontSize * maxScale,
    );
  }

  @override
  double get textScaleFactor => scale(_referenceFontSize) / _referenceFontSize;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppTextScaler &&
          other.system == system &&
          other.appScale == appScale;

  @override
  int get hashCode => Object.hash(system, appScale);

  @override
  String toString() => 'AppTextScaler($system x $appScale)';
}
