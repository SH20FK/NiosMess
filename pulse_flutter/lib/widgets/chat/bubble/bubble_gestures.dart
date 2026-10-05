import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';

class SwipeToReply extends StatefulWidget {
  const SwipeToReply({
    required this.onReply,
    required this.scheme,
    required this.child,
    super.key,
  });

  final VoidCallback onReply;
  final ColorScheme scheme;
  final Widget child;

  @override
  State<SwipeToReply> createState() => SwipeToReplyState();
}

class SwipeToReplyState extends State<SwipeToReply>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final ValueNotifier<double> _dragNotifier = ValueNotifier<double>(0.0);
  static const double _maxDrag = 64;
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.addListener(() {
      _dragNotifier.value = _animation.value;
    });
  }

  @override
  void dispose() {
    _dragNotifier.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) {
        _controller.stop();
        _triggered = false;
      },
      onHorizontalDragUpdate: (DragUpdateDetails details) {
        double delta = details.delta.dx;
        // Apply friction if pulled past the threshold
        if (_dragNotifier.value < -_maxDrag && delta < 0) {
          delta *= 0.3;
        }

        final double next = (_dragNotifier.value + delta).clamp(-_maxDrag * 1.2, 0.0);
        _dragNotifier.value = next;

        if (next <= -_maxDrag && !_triggered) {
          _triggered = true;
          HapticService.reaction(); // Pop when threshold met
        } else if (next > -_maxDrag + 12.0 && _triggered) {
          _triggered = false; // Reset with hysteresis, without chatter vibration
        }
      },
      onHorizontalDragEnd: (DragEndDetails details) {
        final double current = _dragNotifier.value;
        if (current <= -_maxDrag) {
          HapticService.tap();
          widget.onReply();
        }

        // Snap back without overshooting past 0
        _animation = Tween<double>(
          begin: current,
          end: 0,
        ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));

        _controller.forward(from: 0);
      },
      child: ValueListenableBuilder<double>(
        valueListenable: _dragNotifier,
        builder: (BuildContext context, double dragX, Widget? cachedChild) {
          return Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Transform.translate(
                offset: Offset(dragX, 0),
                child: cachedChild,
              ),
              if (dragX < -8)
                Positioned(
                  right: 16,
                  top: 0,
                  bottom: 0,
                  child: Transform.scale(
                    scale: (dragX.abs() / _maxDrag).clamp(0.0, 1.0),
                    child: Center(
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: widget.scheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.reply_rounded, color: widget.scheme.primary, size: 20),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        child: widget.child,
      ),
    );
  }
}

