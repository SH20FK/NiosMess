import 'package:flutter/material.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';

class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({
    this.size,
    this.color,
    this.variant = LoadingIndicatorM3EVariant.defaultStyle,
    super.key,
  });

  final double? size;
  final Color? color;
  final LoadingIndicatorM3EVariant variant;

  @override
  Widget build(BuildContext context) {
    final Color effectiveColor = color ?? Theme.of(context).colorScheme.primary;
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

typedef PulseLoadingIndicator = AppLoadingIndicator;

