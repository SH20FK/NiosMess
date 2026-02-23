import 'package:flutter/material.dart';
import '../nios_ui.dart';

/// Animated typing indicator with bouncing dots
class TypingIndicator extends StatefulWidget {
  final String? typingUser;
  final bool isVisible;

  const TypingIndicator({
    super.key,
    this.typingUser,
    this.isVisible = true,
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (index) {
      return AnimationController(
        duration: const Duration(milliseconds: 1400),
        vsync: this,
      )..repeat(reverse: true);
    });

    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeInOut,
        ),
      );
    }).toList();

    // Stagger the animations
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) _controllers[i].forward();
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: NiosColors.bgSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: NiosColors.textMuted.withOpacity(0.1),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.typingUser != null) ...[
            Text(
              '${widget.typingUser} печатает',
              style: TextStyle(
                color: NiosColors.textGrey,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Row(
            children: List.generate(3, (index) {
              return AnimatedBuilder(
                animation: _animations[index],
                builder: (context, child) {
                  return Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: NiosColors.accentBlue.withOpacity(0.7),
                      shape: BoxShape.circle,
                    ),
                    transform: Matrix4.translationValues(
                      0,
                      -_animations[index].value * 6,
                      0,
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
