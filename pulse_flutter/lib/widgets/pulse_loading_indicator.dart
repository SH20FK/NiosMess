import 'package:flutter/material.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';

class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({
    this.size,
    this.color,
    this.variant = LoadingIndicatorM3EVariant.default_,
    super.key,
  });

  final double? size;
  final Color? color;
  final LoadingIndicatorM3EVariant variant;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final LoadingIndicatorM3E indicator = color != null
        ? LoadingIndicatorM3E(color: color!)
        : LoadingIndicatorM3E(variant: variant);

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
