import 'package:flutter/material.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';

class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({
    this.size,
    this.color,
    this.variant = LoadingIndicatorM3EVariant.defaultStyle,
    this.value,
    this.minHeight = 6,
    this.backgroundColor,
    super.key,
  });

  final double? size;
  final Color? color;
  final LoadingIndicatorM3EVariant variant;

  /// Deterministic progress in [0..1]. When provided, a linear M3 progress
  /// track is rendered instead of the morphing indicator, so upload/download
  /// percentages stay readable while keeping a single component to manage.
  final double? value;

  /// Height of the linear track (deterministic mode only).
  final double minHeight;

  /// Track color behind the deterministic progress.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final Color effectiveColor = color ?? Theme.of(context).colorScheme.primary;

    if (value != null) {
      final Widget track = SizedBox(
        height: minHeight,
        child: LinearProgressIndicator(
          value: value!.clamp(0.0, 1.0),
          color: effectiveColor,
          backgroundColor:
              backgroundColor ?? effectiveColor.withValues(alpha: 0.15),
        ),
      );
      if (size != null) {
        return SizedBox(width: size, child: track);
      }
      return track;
    }

    final LoadingIndicatorM3E indicator =
        LoadingIndicatorM3E(color: effectiveColor, variant: variant);

    if (size != null) {
      return Center(
        child: SizedBox.square(
          dimension: size!,
          child: FittedBox(child: indicator),
        ),
      );
    }

    return Center(child: indicator);
  }
}
