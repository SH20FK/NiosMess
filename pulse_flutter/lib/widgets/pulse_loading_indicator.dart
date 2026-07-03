import 'package:flutter/material.dart';

class PulseLoadingIndicator extends StatefulWidget {
  const PulseLoadingIndicator({
    this.size = 48.0,
    this.color,
    super.key,
  });

  final double size;
  final Color? color;

  @override
  State<PulseLoadingIndicator> createState() => _PulseLoadingIndicatorState();
}

class _PulseLoadingIndicatorState extends State<PulseLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color effectiveColor = widget.color ?? scheme.primary;

    return Center(
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            final double t = _controller.value;
            final double scale = 0.8 + t * 0.5;
            final double opacity = 0.25 * (1 - t);

            return Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Transform.scale(
                  scale: scale,
                  child: Container(
                    width: widget.size * 1.5,
                    height: widget.size * 1.5,
                    decoration: BoxDecoration(
                      color: effectiveColor.withValues(alpha: opacity),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                SizedBox.square(
                  dimension: widget.size,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(effectiveColor),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
