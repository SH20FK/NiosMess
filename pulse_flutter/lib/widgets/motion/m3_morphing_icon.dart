import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

/// Material 3 Expressive morphing icon widget.
///
/// Smoothly morphs between icons using normalized spring physics ([M3SpringCurves.spatial])
/// and expressive fade easing ([M3SpringCurves.expressiveDecel]).
class M3MorphingIcon extends StatefulWidget {
  const M3MorphingIcon({
    required this.icon,
    super.key,
    this.size = 24.0,
    this.color,
    this.duration = const Duration(milliseconds: 260),
    this.curve = M3SpringCurves.spatial,
    this.semanticLabel,
  });

  /// The current icon to display.
  final IconData icon;

  /// Icon size.
  final double size;

  /// Icon color.
  final Color? color;

  /// Transition duration.
  final Duration duration;

  /// Spring curve for scale and rotation transforms.
  final Curve curve;

  /// Semantic label for accessibility.
  final String? semanticLabel;

  @override
  State<M3MorphingIcon> createState() => _M3MorphingIconState();
}

class _M3MorphingIconState extends State<M3MorphingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _fadeAnimation;

  late IconData _currentIcon;
  IconData? _previousIcon;

  @override
  void initState() {
    super.initState();
    _currentIcon = widget.icon;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 1.0,
    );
    _buildAnimations();
  }

  void _buildAnimations() {
    _scaleAnimation = Tween<double>(
      begin: 0.35,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    _rotationAnimation = Tween<double>(
      begin: -0.12,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    // Opacity strictly clamped with expressiveDecel (no spring overshoot on alpha)
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: M3SpringCurves.expressiveDecel,
    ));
  }

  @override
  void didUpdateWidget(covariant M3MorphingIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.icon != widget.icon) {
      _previousIcon = _currentIcon;
      _currentIcon = widget.icon;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (disableAnimations) {
      return Icon(
        widget.icon,
        size: widget.size,
        color: widget.color,
        semanticLabel: widget.semanticLabel,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        if (_controller.isCompleted || _previousIcon == null) {
          return Icon(
            _currentIcon,
            size: widget.size,
            color: widget.color,
            semanticLabel: widget.semanticLabel,
          );
        }

        // Outgoing icon
        final double outProgress = 1.0 - _controller.value;
        final Widget outgoing = Opacity(
          opacity: (outProgress * 1.5).clamp(0.0, 1.0),
          child: Transform.scale(
            scale: (0.35 + outProgress * 0.65).clamp(0.0, 1.0),
            child: Icon(
              _previousIcon,
              size: widget.size,
              color: widget.color,
            ),
          ),
        );

        // Incoming icon
        final Widget incoming = Opacity(
          opacity: _fadeAnimation.value.clamp(0.0, 1.0),
          child: Transform.rotate(
            angle: _rotationAnimation.value * 2 * 3.141592653589793,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Icon(
                _currentIcon,
                size: widget.size,
                color: widget.color,
                semanticLabel: widget.semanticLabel,
              ),
            ),
          ),
        );

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              outgoing,
              incoming,
            ],
          ),
        );
      },
    );
  }
}
