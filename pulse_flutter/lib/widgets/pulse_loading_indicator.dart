import 'package:flutter/material.dart';

class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({
    this.size = 48,
    this.strokeWidth = 4,
    this.color,
    super.key,
  });

  final double size;
  final double strokeWidth;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Center(
      child: SizedBox.square(
        dimension: size,
        child: CircularProgressIndicator(
          strokeWidth: strokeWidth,
          color: color ?? scheme.primary,
        ),
      ),
    );
  }
}
