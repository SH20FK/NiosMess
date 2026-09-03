import 'package:flutter/material.dart';

/// A custom [ScrollPositionWithSingleContext] that animates mouse wheel events
/// with smooth cubic easing instead of abrupt instantaneous jumps.
class SmoothScrollPosition extends ScrollPositionWithSingleContext {
  SmoothScrollPosition({
    required super.physics,
    required super.context,
    super.oldPosition,
    super.initialPixels,
    super.keepScrollOffset,
    super.debugLabel,
  });

  double? _target;

  @override
  void pointerScroll(double delta) {
    if (delta == 0) return;

    // Accumulate target from current running target or current pixels
    final double base = (_target != null && isScrollingNotifier.value)
        ? _target!
        : pixels;
    final double newTarget =
        (base + delta).clamp(minScrollExtent, maxScrollExtent);
    _target = newTarget;

    if (newTarget != pixels) {
      animateTo(
        newTarget,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      ).whenComplete(() {
        if (_target == newTarget) {
          _target = null;
        }
      });
    }
  }
}

/// A drop-in [ScrollController] replacement that provides buttery smooth,
/// momentum-interpolated mouse-wheel scrolling for Desktop and Web.
class SmoothScrollController extends ScrollController {
  SmoothScrollController({
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
  });

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return SmoothScrollPosition(
      physics: physics,
      context: context,
      oldPosition: oldPosition,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      debugLabel: debugLabel,
    );
  }
}
