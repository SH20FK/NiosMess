import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

/// Material 3 Expressive shared axis transition widget.
///
/// Implements Material 3 shared axis pattern along [Axis.horizontal] or [Axis.vertical].
/// Used for wizard steps, tab page transitions, and structured screen state flows.
class M3SharedAxis extends StatelessWidget {
  const M3SharedAxis({
    required this.child,
    super.key,
    this.axis = Axis.horizontal,
    this.forward = true,
    this.duration = const Duration(milliseconds: 320),
    this.curve = M3SpringCurves.spatial,
    this.slideDistance = 30.0,
  });

  /// The widget to display. Must have a distinct [Key] to trigger transitions.
  final Widget child;

  /// The axis of motion (horizontal or vertical).
  final Axis axis;

  /// Direction of motion: `true` moves forward (right/down), `false` moves backward (left/up).
  final bool forward;

  /// Transition duration.
  final Duration duration;

  /// Spring curve for spatial slide translation.
  final Curve curve;

  /// Distance in logical pixels traversed during transition.
  final double slideDistance;

  @override
  Widget build(BuildContext context) {
    final bool disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (disableAnimations) {
      return child;
    }

    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.linear,
      switchOutCurve: Curves.linear,
      layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
        return Stack(
          alignment: Alignment.topLeft,
          children: <Widget>[
            ...previousChildren,
            ?currentChild,
          ],
        );
      },
      transitionBuilder: (Widget child, Animation<double> animation) {
        final bool isIncoming = child.key == this.child.key;

        // Opacity animation strictly clamped with expressiveDecel
        final Animation<double> fadeAnim = CurvedAnimation(
          parent: animation,
          curve: M3SpringCurves.expressiveDecel,
          reverseCurve: M3SpringCurves.expressiveAccel,
        );

        final Animation<double> slideAnim = CurvedAnimation(
          parent: animation,
          curve: curve,
          reverseCurve: M3SpringCurves.expressiveDecel,
        );

        final double direction = forward ? 1.0 : -1.0;
        final Offset beginOffset;
        final Offset endOffset;

        if (axis == Axis.horizontal) {
          beginOffset = Offset(direction * (slideDistance / 100.0), 0.0);
          endOffset = Offset(-direction * (slideDistance / 100.0), 0.0);
        } else {
          beginOffset = Offset(0.0, direction * (slideDistance / 100.0));
          endOffset = Offset(0.0, -direction * (slideDistance / 100.0));
        }

        final Animation<Offset> offsetAnimation = Tween<Offset>(
          begin: isIncoming ? beginOffset : Offset.zero,
          end: isIncoming ? Offset.zero : endOffset,
        ).animate(slideAnim);

        return FadeTransition(
          opacity: fadeAnim,
          child: SlideTransition(
            position: offsetAnimation,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
