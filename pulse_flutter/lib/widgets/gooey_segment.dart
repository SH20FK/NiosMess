import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';

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
  late final Animation<double> _stretchAnim;
  int _previousValue = 0;

  @override
  void initState() {
    super.initState();
    _previousValue = widget.value;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _stretchAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 0.85), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.1), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 0.95), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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

          return SizedBox(
            height: 44,
            child: Stack(
              children: [
                RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _stretchAnim,
                    builder: (context, child) {
                      final double stretch = _stretchAnim.value;
                      final double targetLeft = widget.value * segmentWidth;
                      final double prevLeft = _previousValue * segmentWidth;
                      final double left = _controller.isAnimating
                          ? prevLeft + (targetLeft - prevLeft) * _controller.value
                          : targetLeft;

                      final double capsuleWidth = segmentWidth - 8;
                      final double stretchedW = capsuleWidth * stretch;
                      final double extraW = (stretchedW - capsuleWidth) / 2;
                      final double capsuleLeft = left + 4 - extraW;
                      final double capsuleTop = 4;
                      final double capsuleH = 36;

                      return Positioned(
                        left: capsuleLeft,
                        top: capsuleTop,
                        width: stretchedW,
                        height: capsuleH,
                        child: Container(
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer.withValues(alpha: 0.8),
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
                        child: GestureDetector(
                          onTap: selected ? null : () => widget.onChanged(index),
                          behavior: HitTestBehavior.opaque,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            alignment: Alignment.center,
                            child: Text(
                              widget.options[index],
                              style: textTheme.labelMedium?.copyWith(
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                color: selected
                                    ? scheme.onSecondaryContainer
                                    : scheme.onSurfaceVariant,
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
