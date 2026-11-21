import 'dart:math' as math;

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

/// Row of reaction pills under a message bubble.
///
/// A reaction that was taken away stays for a short fade-out instead of
/// vanishing. Taps on a leaving pill are ignored.
class BubbleReactionRow extends StatefulWidget {
  const BubbleReactionRow({
    required this.reactions,
    required this.alignEnd,
    required this.labelBuilder,
    this.onReactionTap,
    super.key,
  });

  /// Reaction key to its count, in display order.
  final Map<String, int> reactions;
  final bool alignEnd;

  /// Maps a reaction key to the emoji shown in the pill.
  final String Function(String key) labelBuilder;
  final ValueChanged<String>? onReactionTap;

  @override
  State<BubbleReactionRow> createState() => _BubbleReactionRowState();
}

class _BubbleReactionRowState extends State<BubbleReactionRow> {
  late List<String> _order = widget.reactions.keys.toList();

  /// Reactions that are fading out, with the last count they showed.
  final Map<String, int> _leaving = <String, int>{};

  @override
  void didUpdateWidget(BubbleReactionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final Map<String, int> next = widget.reactions;
    if (next.isEmpty && _order.isEmpty) return;

    _leaving.removeWhere((String key, int _) => next.containsKey(key));
    if (context.reduceMotion) {
      _leaving.clear();
    } else {
      for (final MapEntry<String, int> entry in oldWidget.reactions.entries) {
        if (!next.containsKey(entry.key)) _leaving[entry.key] = entry.value;
      }
    }

    // Leaving pills keep the slot they had, the rest follow the new order.
    final List<String> merged = next.keys.toList();
    for (int i = 0; i < _order.length; i++) {
      final String key = _order[i];
      if (_leaving.containsKey(key)) {
        merged.insert(math.min(i, merged.length), key);
      }
    }
    _order = merged;
  }

  void _onGone(String key) {
    if (!mounted || !_leaving.containsKey(key)) return;
    setState(() {
      _leaving.remove(key);
      _order.remove(key);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_order.isEmpty) return const SizedBox.shrink();
    final ValueChanged<String>? onReactionTap = widget.onReactionTap;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: widget.alignEnd ? WrapAlignment.end : WrapAlignment.start,
        children: <Widget>[
          for (final String key in _order)
            _ReactionPresence(
              key: ValueKey<String>('react_$key'),
              leaving: _leaving.containsKey(key),
              onGone: () => _onGone(key),
              child: BubbleReactionChip(
                label: widget.labelBuilder(key),
                count: widget.reactions[key] ?? _leaving[key] ?? 0,
                onTap: onReactionTap == null || _leaving.containsKey(key)
                    ? null
                    : () => onReactionTap(key),
              ),
            ),
        ],
      ),
    );
  }
}

/// Fades and shrinks a pill out when its reaction is taken away.
class _ReactionPresence extends StatefulWidget {
  const _ReactionPresence({
    required this.leaving,
    required this.onGone,
    required this.child,
    super.key,
  });

  final bool leaving;
  final VoidCallback onGone;
  final Widget child;

  @override
  State<_ReactionPresence> createState() => _ReactionPresenceState();
}

class _ReactionPresenceState extends State<_ReactionPresence>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: M3Durations.short4,
      value: widget.leaving ? 0.0 : 1.0,
    )..addStatusListener(_onStatus);
    _opacity = _controller.drive(
      CurveTween(curve: M3SpringCurves.effectsFast),
    );
    _scale = _opacity.drive(Tween<double>(begin: 0.8, end: 1.0));
  }

  @override
  void didUpdateWidget(_ReactionPresence oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.leaving == oldWidget.leaving) return;
    if (widget.leaving) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && widget.leaving) {
      widget.onGone();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: widget.leaving,
      child: FadeTransition(
        opacity: _opacity,
        child: ScaleTransition(scale: _scale, child: widget.child),
      ),
    );
  }
}
