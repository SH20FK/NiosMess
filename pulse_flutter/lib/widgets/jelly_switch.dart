import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class JellySwitch extends StatefulWidget {
  const JellySwitch({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  State<JellySwitch> createState() => _JellySwitchState();
}

class _JellySwitchState extends State<JellySwitch> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _thumbPosition;
  late Animation<double> _thumbWidth;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: widget.value ? 1.0 : 0.0,
    );
    
    _setupAnimations();
  }

  void _setupAnimations() {
    final springCurve = SpringCurve();

    _thumbPosition = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: springCurve,
      ),
    );

    // "Jelly" squash effect: wide when moving, normal when resting
    _thumbWidth = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 20.0, end: 32.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 32.0, end: 20.0), weight: 50),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void didUpdateWidget(JellySwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      if (widget.value) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.lightImpact();
    widget.onChanged(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: 'Toggle',
      toggled: widget.value,
      child: GestureDetector(
        onTap: _toggle,
        onPanUpdate: (_) => setState(() => _isDragging = true),
        onPanEnd: (_) {
          if (_isDragging) {
            setState(() => _isDragging = false);
            _toggle();
          }
        },
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final trackColor = Color.lerp(
              scheme.surfaceContainerHighest,
              scheme.primary,
              _controller.value,
            );

            return Container(
              width: 52,
              height: 28,
              decoration: BoxDecoration(
                color: trackColor,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Positioned(
                    left: 4.0 + (_thumbPosition.value * 24.0),
                    child: Container(
                      width: _isDragging ? 26.0 : _thumbWidth.value,
                      height: 20,
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.shadow.withValues(alpha: 0.12),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class SpringCurve extends Curve {
  @override
  double transformInternal(double t) {
    // A damped sine wave for a jelly/spring effect
    return (1.0 - (1.0 - t) * (1.0 - t)) + 0.15 * (1.0 - t) * t * 4.0 * (t > 0.5 ? -1 : 1);
  }
}
