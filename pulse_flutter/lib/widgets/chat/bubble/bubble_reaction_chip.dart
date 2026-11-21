import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/motion/m3_motion.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/widgets/common/touch_container.dart';
import 'package:pulse_flutter/widgets/motion/m3_reaction_burst.dart';

/// Reaction pill under a message bubble.
///
/// The pill pops in once, when the reaction first appears. A count change
/// animates only the counter, and a tap fires a particle burst.
class BubbleReactionChip extends StatefulWidget {
  const BubbleReactionChip({
    required this.label,
    required this.count,
    this.onTap,
    super.key,
  });

  /// Emoji shown before the counter.
  final String label;
  final int count;
  final VoidCallback? onTap;

  @override
  State<BubbleReactionChip> createState() => _BubbleReactionChipState();
}

class _BubbleReactionChipState extends State<BubbleReactionChip> {
  final GlobalKey<M3ReactionBurstState> _burst =
      GlobalKey<M3ReactionBurstState>();

  static Widget _counterTransition(Widget child, Animation<double> animation) {
    return FadeTransition(
      opacity: animation.drive(
        CurveTween(curve: M3SpringCurves.effectsDefault),
      ),
      child: SlideTransition(
        position: animation.drive(
          Tween<Offset>(
            begin: const Offset(0.0, 0.5),
            end: Offset.zero,
          ).chain(CurveTween(curve: M3SpringCurves.spatialFast)),
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool reduceMotion = context.reduceMotion;
    final TextStyle? style = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final VoidCallback? onTap = widget.onTap;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: reduceMotion ? 1.0 : 0.8, end: 1.0),
      duration: reduceMotion ? Duration.zero : M3Durations.spatialFast,
      curve: M3SpringCurves.spatialFast,
      builder: (BuildContext context, double scale, Widget? child) =>
          Transform.scale(scale: scale, child: child),
      child: M3ReactionBurst(
        key: _burst,
        burstRadius: 18.0,
        child: TouchContainer(
          borderRadius: AppRadii.fullRadius,
          scaleDown: 0.96,
          releaseCurve: M3SpringCurves.spatialFast,
          onTap: onTap == null
              ? null
              : () {
                  _burst.currentState?.fire();
                  onTap();
                },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: AppRadii.fullRadius,
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.25),
                width: 0.75,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(widget.label, style: style),
                const SizedBox(width: 4),
                AnimatedSwitcher(
                  duration: reduceMotion ? Duration.zero : M3Durations.short4,
                  transitionBuilder: _counterTransition,
                  child: Text(
                    '${widget.count}',
                    key: ValueKey<int>(widget.count),
                    style: style,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
