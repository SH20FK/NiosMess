import 'package:flutter/widgets.dart';
import 'package:pulse_flutter/core/motion/m3_motion.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';

/// Press feedback shared by every pressable surface in the app.
///
/// The child compresses on an effects curve, so nothing overshoots under the
/// finger, and releases on the fast spatial spring. The caller owns the
/// gesture and passes [pressed]. With reduced motion the child keeps its size.
class M3PressScale extends StatelessWidget {
  const M3PressScale({
    required this.pressed,
    required this.child,
    this.scale = AppMotion.scalePressed,
    this.releaseCurve,
    super.key,
  });

  final bool pressed;
  final Widget child;

  /// Scale of the child while pressed.
  final double scale;

  /// Curve of the release; defaults to [AppMotion.spring].
  final Curve? releaseCurve;

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = context.reduceMotion;
    return AnimatedScale(
      scale: pressed && !reduceMotion ? scale : 1.0,
      duration: reduceMotion
          ? Duration.zero
          : pressed
          ? AppMotion.durationPress
          : AppMotion.durationRelease,
      curve: pressed
          ? AppMotion.pressCurve
          : (releaseCurve ?? AppMotion.spring),
      child: child,
    );
  }
}
