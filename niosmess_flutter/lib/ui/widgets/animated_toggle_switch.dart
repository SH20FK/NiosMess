import 'package:flutter/material.dart';
import '../nios_ui.dart';

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
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _knobAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _backgroundAnimation = ColorTween(
      begin: widget.inactiveColor ?? NiosColors.textMuted.withOpacity(0.3),
      end: widget.activeColor ?? NiosColors.accentBlue,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
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
    return GestureDetector(
      onTap: _handleTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.label != null) ...[
            Text(
              widget.label!,
              style: TextStyle(
                color: NiosColors.textWhite,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 12),
          ],
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Container(
                width: 51,
                height: 31,
                decoration: BoxDecoration(
                  color: _backgroundAnimation.value,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 3 + (_knobAnimation.value * 23),
                      top: 3,
                      child: Transform.rotate(
                        angle: _knobAnimation.value * 6.28, // 360 degrees in radians
                        child: Container(
                          width: 25,
                          height: 25,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
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
