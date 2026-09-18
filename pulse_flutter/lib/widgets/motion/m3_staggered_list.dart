import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

/// Material 3 Expressive staggered list entrance item.
///
/// Implements cascade appearance for list tiles strictly limited to the first
/// [maxStaggerIndex] items (default 8) to eliminate frame drops during scrolling.
/// Items beyond [maxStaggerIndex] or rendered when animations are disabled skip
/// the animation entirely and render immediately.
class M3StaggeredItem extends StatefulWidget {
  const M3StaggeredItem({
    required this.index,
    required this.child,
    super.key,
    this.maxStaggerIndex = 8,
    this.itemDelay = const Duration(milliseconds: 30),
    this.duration = const Duration(milliseconds: 280),
    this.curve = M3SpringCurves.spatial,
    this.slideOffset = 18.0,
  });

  /// Index of the item in the list.
  final int index;

  /// Child widget.
  final Widget child;

  /// Maximum index eligible for staggered entrance animation.
  final int maxStaggerIndex;

  /// Delay increment per index.
  final Duration itemDelay;

  /// Transition duration.
  final Duration duration;

  /// Spring curve for slide offset.
  final Curve curve;

  /// Vertical slide offset in pixels.
  final double slideOffset;

  @override
  State<M3StaggeredItem> createState() => _M3StaggeredItemState();
}

class _M3StaggeredItemState extends State<M3StaggeredItem>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _delayTimer;

  bool get _shouldAnimate => widget.index < widget.maxStaggerIndex;

  @override
  void initState() {
    super.initState();
    if (_shouldAnimate) {
      _controller = AnimationController(
        vsync: this,
        duration: widget.duration,
      );

      _slideAnimation = Tween<double>(
        begin: widget.slideOffset,
        end: 0.0,
      ).animate(CurvedAnimation(
        parent: _controller!,
        curve: widget.curve,
      ));

      _fadeAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _controller!,
        curve: M3SpringCurves.expressiveDecel,
      ));

      final int delayMs = widget.index * widget.itemDelay.inMilliseconds;
      if (delayMs > 0) {
        _delayTimer = Timer(Duration(milliseconds: delayMs), () {
          if (mounted) {
            _controller?.forward();
          }
        });
      } else {
        _controller!.forward();
      }
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (!_shouldAnimate || disableAnimations || _controller == null) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller!,
      builder: (BuildContext context, Widget? child) {
        if (_controller!.isCompleted) {
          return child!;
        }
        return Opacity(
          opacity: _fadeAnimation.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
