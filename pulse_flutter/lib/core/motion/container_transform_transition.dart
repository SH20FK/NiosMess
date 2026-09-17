import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

/// Value object describing the origin element for container transform transitions.
@immutable
class NavigationOrigin {
  const NavigationOrigin({
    required this.fromRect,
    this.heroTag,
    this.fromBorderRadius = const BorderRadius.all(Radius.circular(24)),
    this.elevation = 0.0,
  });

  /// Global bounding box of the originating widget (e.g. [ChatTile]).
  final Rect fromRect;

  /// Optional Hero tag for shared elements within the container.
  final String? heroTag;

  /// Initial border radius matching the originating tile shape.
  final BorderRadius fromBorderRadius;

  /// Visual elevation or surface tier.
  final double elevation;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NavigationOrigin &&
          other.fromRect == fromRect &&
          other.heroTag == heroTag &&
          other.fromBorderRadius == fromBorderRadius;

  @override
  int get hashCode => Object.hash(fromRect, heroTag, fromBorderRadius);
}

/// Material 3 Expressive Container Transform Page Transition (TR-1...TR-5, TR-10).
///
/// Seamlessly morphs an originating list tile ([origin.fromRect]) into the full
/// screen viewport of the destination route.
///
/// Performance and Anti-Jank guarantees:
/// 1. Child constraints are strictly fixed once via [OverflowBox] to the screen size.
/// 2. [RepaintBoundary] is placed strictly INSIDE [ClipRRect] so the raster cache
///    is preserved while only clipping geometry moves per frame.
/// 3. Geometry lerping uses [M3SpringCurves.spatial] (unbounded overshoot allowed).
/// 4. Corner radius and opacity use strictly monotonic curves (no overshoot).
/// 5. Zero hard branches on animation progress (no blinking or frame freezing).
class ContainerTransformTransition extends StatelessWidget {
  const ContainerTransformTransition({
    required this.animation,
    required this.origin,
    required this.child,
    this.scrimColor,
    super.key,
  });

  final Animation<double> animation;
  final NavigationOrigin origin;
  final Widget child;
  final Color? scrimColor;

  @override
  Widget build(BuildContext context) {
    // TR-10 / RASK-13: Accessibility and reduced motion degradation
    if (MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context)) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        ),
        child: child,
      );
    }

    final Size screenSize = MediaQuery.sizeOf(context);
    final Rect screenRect = Offset.zero & screenSize;

    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? cachedChild) {
        final double t = animation.value.clamp(0.0, 1.0);

        // TR-5: Overshoot is permitted and desirable for spatial geometry
        final double spatial = M3SpringCurves.spatial.transform(t);
        final Rect currentRect = Rect.lerp(origin.fromRect, screenRect, spatial) ?? screenRect;

        // Monotonic curve for radius — strictly non-overshooting to prevent corner flash
        final double gentle = M3SpringCurves.gentle.transform(t);
        final double radiusFactor = (1.0 - gentle).clamp(0.0, 1.0);

        // Interpolate radius from tile's initial 24dp down to 0dp at full screen
        final double initialRadius = origin.fromBorderRadius.topLeft.x;
        final double currentRadius = initialRadius * radiusFactor;

        // TR-4: Content fade-through intervals
        // Destination content smoothly emerges as container expands
        final double contentOpacity = const Interval(
          0.12,
          0.55,
          curve: Curves.easeOut,
        ).transform(t);

        // Backdrop scrim fade
        final ColorScheme scheme = Theme.of(context).colorScheme;
        final Color effectiveScrim = scrimColor ?? scheme.scrim;
        final double scrimOpacity = (0.25 * t).clamp(0.0, 0.25);

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Optional subtle ambient scrim behind expanding tile
            if (scrimOpacity > 0.001)
              ColoredBox(
                color: effectiveScrim.withValues(alpha: scrimOpacity),
              ),

            // TR-3: Positioned container with fixed-constraint child inside ClipRRect
            Positioned.fromRect(
              rect: currentRect,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(currentRadius),
                child: ColoredBox(
                  color: scheme.surface,
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    minWidth: screenSize.width,
                    maxWidth: screenSize.width,
                    minHeight: screenSize.height,
                    maxHeight: screenSize.height,
                    child: RepaintBoundary(
                      child: Opacity(
                        opacity: contentOpacity,
                        child: cachedChild,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: child,
    );
  }
}
