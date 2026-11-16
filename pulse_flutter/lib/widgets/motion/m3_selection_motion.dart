import 'package:flutter/widgets.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

/// Consistent, interruptible feedback for a compact selected filter or tab.
///
/// Only the *selected* pill receives the tactile press-in scale (1.0 → 0.98,
/// the M3E pressed-state delta). Unselected pills stay at exactly 1.0: the old
/// 0.97 baseline shrank every unselected chip by 3%, so a row of visually
/// identical chips rendered with two different geometries (and softly resampled
/// text). The transform never affects layout (`transformHitTests: false`), so
/// the row cannot reflow while the selection travels.
class M3SelectionMotion extends StatelessWidget {
  const M3SelectionMotion({
    required this.selected,
    required this.child,
    super.key,
  });

  /// Scale applied to the selected pill — a hint, not a resize.
  static const double selectedScale = 0.98;

  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(end: selected ? selectedScale : 1.0),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : M3Durations.short4,
    curve: M3SpringCurves.snappy,
    builder: (context, scale, child) =>
        Transform.scale(scale: scale, transformHitTests: false, child: child),
    child: child,
  );
}
