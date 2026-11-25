import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart' show SingleMotionController;
import 'package:pulse_flutter/core/motion/m3_motion.dart';
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
  static const double _maxDrag = 64;

  /// Extra travel the bubble can be stretched past the reply threshold.
  static const double _stretch = 32;
  static const double _stretchStiffness = 0.55;

  /// Visible bubble offset in logical pixels, zero or negative while dragging.
  late final SingleMotionController _controller;

  /// Finger travel since the drag started, before rubber-banding.
  double _rawDrag = 0;
  bool _triggered = false;

  /// Follows the finger 1:1 up to the threshold, then stretches asymptotically.
  static double _rubberBand(double raw) {
    final double over = -raw - _maxDrag;
    if (over <= 0) return raw;
    final double eased = 1 - 1 / (over * _stretchStiffness / _stretch + 1);
    return -(_maxDrag + eased * _stretch);
  }

  /// Finger offset that [_rubberBand] maps onto [visible], so a re-grab
  /// mid-flight continues from where the bubble is.
  static double _inverseRubberBand(double visible) {
    final double over = -visible - _maxDrag;
    if (over <= 0) return visible;
    final double eased = (over / _stretch).clamp(0.0, 0.99);
    return -(_maxDrag + (1 / (1 - eased) - 1) * _stretch / _stretchStiffness);
  }

  /// Ratio of bubble speed to finger speed at the finger offset [raw].
  static double _rubberBandSlope(double raw) {
    final double over = -raw - _maxDrag;
    if (over <= 0) return 1;
    final double divisor = over * _stretchStiffness / _stretch + 1;
    return _stretchStiffness / (divisor * divisor);
  }

  void _release({double? velocity}) {
    _controller.springTo(
      0.0,
      velocity: velocity,
      reduceMotion: context.reduceMotion,
    );
  }

  @override
  void initState() {
    super.initState();
    _controller = SingleMotionController(
      motion: M3Motion.spatialFast,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) {
        _controller.stop(canceled: true);
        _rawDrag = _inverseRubberBand(math.min(_controller.value, 0.0));
        _triggered = false;
      },
      onHorizontalDragUpdate: (DragUpdateDetails details) {
        _rawDrag = math.min(_rawDrag + details.delta.dx, 0.0);
        final double next = _rubberBand(_rawDrag);
        _controller.value = next;

        if (next <= -_maxDrag && !_triggered) {
          _triggered = true;
          HapticService.reaction(); // Pop when threshold met
        } else if (next > -_maxDrag + 12.0 && _triggered) {
          _triggered =
              false; // Reset with hysteresis, without chatter vibration
        }
      },
      onHorizontalDragEnd: (DragEndDetails details) {
        if (_controller.value <= -_maxDrag) {
          HapticService.tap();
          widget.onReply();
        }

        // The spring continues with the speed the bubble had under the finger.
        _release(
          velocity:
              (details.primaryVelocity ?? 0.0) * _rubberBandSlope(_rawDrag),
        );
      },
      onHorizontalDragCancel: _release,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? cachedChild) {
          final double dragX = _controller.value;
          return Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Transform.translate(offset: Offset(dragX, 0), child: cachedChild),
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
                        child: Icon(
                          Icons.reply_rounded,
                          color: widget.scheme.primary,
                          size: 20,
                        ),
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
