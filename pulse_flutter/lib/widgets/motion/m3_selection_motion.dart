import 'package:flutter/widgets.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

/// Consistent, interruptible feedback for a compact selected filter or tab.
class M3SelectionMotion extends StatelessWidget {
  const M3SelectionMotion({
    required this.selected,
    required this.child,
    super.key,
  });

  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(end: selected ? 1 : 0.97),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : M3Durations.short4,
    curve: M3SpringCurves.snappy,
    builder: (context, scale, child) =>
        Transform.scale(scale: scale, transformHitTests: false, child: child),
    child: child,
  );
}
