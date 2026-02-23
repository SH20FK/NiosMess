import 'package:flutter/material.dart';

/// Animated Toggle Switch with smooth knob animation
class AnimatedToggleSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final Color? activeColor;
  final Color? inactiveColor;

  const AnimatedToggleSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.label,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  State<AnimatedToggleSwitch> createState() => _AnimatedToggleSwitchState();
}

class _AnimatedToggleSwitchState extends State<AnimatedToggleSwitch>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _knobAnimation;
  late Animation<Color?> _backgroundAnimation;

  @override
  void initState() {
    super.initState();
    final scheme = Theme.of(context).colorScheme;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
    );

    _knobAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuart,
    ));

    _backgroundAnimation = ColorTween(
      begin: widget.inactiveColor ?? scheme.surfaceContainerHighest,
      end: widget.activeColor ?? scheme.primary,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuart,
    ));

    if (widget.value) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(AnimatedToggleSwitch oldWidget) {
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

  void _handleTap() {
    if (widget.onChanged != null) {
      widget.onChanged!(!widget.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onChanged == null ? null : _handleTap,
      borderRadius: BorderRadius.circular(18),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.label != null) ...[
            Text(
              widget.label!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 12),
          ],
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final disabled = widget.onChanged == null;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: 51,
                height: 31,
                decoration: BoxDecoration(
                  color: disabled
                      ? Theme.of(context).colorScheme.surfaceContainerHighest
                      : _backgroundAnimation.value,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 3 + (_knobAnimation.value * 23),
                      top: 3,
                      child: Container(
                        width: 25,
                        height: 25,
                        decoration: BoxDecoration(
                          color: disabled
                              ? Theme.of(context).colorScheme.onSurface.withOpacity(0.38)
                              : Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.16),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
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
        ],
      ),
    );
  }
}
