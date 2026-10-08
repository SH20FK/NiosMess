import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

/// Material 3 Expressive animated badge with tactile spring pop.
///
/// Triggers a bouncy spring pop ([M3SpringCurves.bouncy]) whenever the [count]
/// or [label] updates. Seamlessly collapses to scale 0 when [count] is 0 or null.
class M3AnimatedBadge extends StatefulWidget {
  const M3AnimatedBadge({
    super.key,
    this.count,
    this.label,
    this.backgroundColor,
    this.textColor,
    this.textStyle,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    this.minSize = 18.0,
    this.duration = const Duration(milliseconds: 320),
    this.curve = M3SpringCurves.bouncy,
  });

  /// Numeric count displayed in the badge. If 0, badge collapses unless [label] is set.
  final int? count;

  /// Text label displayed in the badge. If empty and count is 0/null, badge collapses.
  final String? label;

  /// Background surface color.
  final Color? backgroundColor;

  /// Text color.
  final Color? textColor;

  /// Custom text style.
  final TextStyle? textStyle;

  /// Content padding.
  final EdgeInsetsGeometry padding;

  /// Minimum width and height.
  final double minSize;

  /// Duration of the spring pop animation.
  final Duration duration;

  /// Spring curve for the pop animation.
  final Curve curve;

  @override
  State<M3AnimatedBadge> createState() => _M3AnimatedBadgeState();
}

class _M3AnimatedBadgeState extends State<M3AnimatedBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _scaleAnimation;

  String get _displayString {
    if (widget.label != null && widget.label!.isNotEmpty) {
      return widget.label!;
    }
    if (widget.count != null && widget.count! > 0) {
      return widget.count! > 999 ? '999+' : widget.count.toString();
    }
    return '';
  }

  bool get _shouldShow => _displayString.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: _shouldShow ? 1.0 : 0.0,
    );
    _buildAnimation();
  }

  void _buildAnimation() {
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
      reverseCurve: M3SpringCurves.expressiveAccel,
    ));
  }

  @override
  void didUpdateWidget(covariant M3AnimatedBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.count != widget.count || oldWidget.label != widget.label) {
      if (_shouldShow) {
        // Trigger a spring bounce pop
        _controller.forward(from: 0.2);
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (!_shouldShow && (_controller.isDismissed || disableAnimations)) {
      return const SizedBox.shrink();
    }

    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color bg = widget.backgroundColor ?? scheme.error;
    final Color fg = widget.textColor ?? scheme.onError;

    final Widget badgeContent = Container(
      constraints: BoxConstraints(
        minWidth: widget.minSize,
        minHeight: widget.minSize,
      ),
      padding: widget.padding,
      decoration: ShapeDecoration(
        color: bg,
        shape: const StadiumBorder(),
      ),
      alignment: Alignment.center,
      child: Text(
        _displayString,
        style: widget.textStyle ??
            TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
        textAlign: TextAlign.center,
      ),
    );

    if (disableAnimations) {
      return badgeContent;
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      child: badgeContent,
    );
  }
}
