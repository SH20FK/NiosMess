import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

/// Material 3 Expressive morphing surface container.
///
/// Transitions shape, border radii, and tonal surface elevation smoothly
/// using normalized spring motion ([M3SpringCurves.spatial]) with zero harsh
/// drop shadows and zero save-layer overhead.
class M3MorphingSurface extends StatelessWidget {
  const M3MorphingSurface({
    required this.child,
    super.key,
    this.color,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.border,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.duration = const Duration(milliseconds: 260),
    this.curve = M3SpringCurves.spatial,
    this.clipBehavior = Clip.none,
  });

  /// The child widget.
  final Widget child;

  /// Surface fill color. Defaults to `colorScheme.surfaceContainerLow`.
  final Color? color;

  /// Border radius geometry.
  final BorderRadiusGeometry borderRadius;

  /// Optional outline border.
  final BoxBorder? border;

  /// Internal padding.
  final EdgeInsetsGeometry? padding;

  /// External margin.
  final EdgeInsetsGeometry? margin;

  /// Explicit width.
  final double? width;

  /// Explicit height.
  final double? height;

  /// Duration of the shape and color morph.
  final Duration duration;

  /// Spring curve for shape transitions.
  final Curve curve;

  /// Clip behavior (strictly defaults to [Clip.none] to avoid unnecessary save-layers).
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color surfaceColor = color ?? scheme.surfaceContainerLow;

    final bool disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (disableAnimations) {
      return Container(
        width: width,
        height: height,
        margin: margin,
        padding: padding,
        clipBehavior: clipBehavior,
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: borderRadius,
          border: border,
        ),
        child: child,
      );
    }

    return AnimatedContainer(
      duration: duration,
      curve: curve,
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: borderRadius,
        border: border,
      ),
      child: child,
    );
  }
}
