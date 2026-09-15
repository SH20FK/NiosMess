import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';

/// Expressive Material 3 segmented selector featuring fluid spatial spring motion,
/// synchronized capsule morphing, 48dp touch targets, and tactile haptics.
class GooeySegment extends StatefulWidget {
  const GooeySegment({
    required this.options,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final List<String> options;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<GooeySegment> createState() => _GooeySegmentState();
}

class _GooeySegmentState extends State<GooeySegment>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curveAnim;
  int _previousValue = 0;

  @override
  void initState() {
    super.initState();
    _previousValue = widget.value;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _curveAnim = CurvedAnimation(
      parent: _controller,
      curve: M3SpringCurves.spatial,
    );
  }

  @override
  void didUpdateWidget(GooeySegment old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _previousValue = old.value;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: context.l10n.semanticsSegmentSelector,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double totalWidth = constraints.maxWidth;
          final double segmentWidth = totalWidth / widget.options.length;
          const double totalHeight = 48.0;
          const double capsuleH = 40.0;
          const double capsuleTop = 4.0;

          return SizedBox(
            height: totalHeight,
            child: Stack(
              children: [
                RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _curveAnim,
                    builder: (context, child) {
                      final double progress = _curveAnim.value;
                      final double targetLeft = widget.value * segmentWidth;
                      final double prevLeft = _previousValue * segmentWidth;
                      final double left = _controller.isAnimating
                          ? prevLeft + (targetLeft - prevLeft) * progress
                          : targetLeft;

                      // Subtle organic stretch during flight (peaks at mid-transition)
                      final double stretch = _controller.isAnimating
                          ? 1.0 + 0.10 * math.sin(progress.clamp(0.0, 1.0) * math.pi)
                          : 1.0;

                      final double capsuleWidth = segmentWidth - 8.0;
                      final double stretchedW = capsuleWidth * stretch;
                      final double extraW = (stretchedW - capsuleWidth) / 2;
                      final double capsuleLeft = left + 4.0 - extraW;

                      return Positioned(
                        left: capsuleLeft,
                        top: capsuleTop,
                        width: stretchedW,
                        height: capsuleH,
                        child: Container(
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(capsuleH / 2),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Row(
                  children: List.generate(widget.options.length, (index) {
                    final bool selected = index == widget.value;
                    return Expanded(
                      child: Semantics(
                        button: true,
                        selected: selected,
                        label: widget.options[index],
                        child: Material(
                          color: Colors.transparent,
                          child: InkResponse(
                            onTap: selected
                                ? null
                                : () {
                                    HapticService.selection();
                                    widget.onChanged(index);
                                  },
                            borderRadius: BorderRadius.circular(capsuleH / 2),
                            splashColor: scheme.primary.withValues(alpha: 0.12),
                            highlightColor: Colors.transparent,
                            child: Container(
                              height: totalHeight,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                curve: M3SpringCurves.spatial,
                                style: (textTheme.labelMedium ?? const TextStyle()).copyWith(
                                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                  color: selected
                                      ? scheme.onSecondaryContainer
                                      : scheme.onSurfaceVariant,
                                ),
                                child: Text(
                                  widget.options[index],
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
