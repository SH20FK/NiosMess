import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';

class PulseLoadingIndicator extends StatelessWidget {
  const PulseLoadingIndicator({
    this.size = 48.0,
    this.color,
    super.key,
  });

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color effectiveColor = color ?? scheme.primary;

    return Center(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            // Мягкий пульсирующий фон в стиле M3
            Animate(
              onPlay: (controller) => controller.repeat(),
              effects: const <Effect<dynamic>>[
                ScaleEffect(
                  begin: Offset(0.8, 0.8),
                  end: Offset(1.3, 1.3),
                  duration: Duration(milliseconds: 1400),
                  curve: Curves.easeInOut,
                ),
                FadeEffect(
                  begin: 0.25,
                  end: 0.0,
                  duration: Duration(milliseconds: 1400),
                  curve: Curves.easeInOut,
                ),
              ],
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: effectiveColor.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(dimension: size * 1.5),
              ),
            ),
            // Красивый лоадер M3 Expressive (морфящийся многоугольник)
            SizedBox.square(
              dimension: size,
              child: LoadingIndicatorM3E(
                color: effectiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
