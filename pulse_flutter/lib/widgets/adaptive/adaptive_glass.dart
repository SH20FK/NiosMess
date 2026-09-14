import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';

/// A drop-in adaptive glass container that adjusts its backdrop blur
/// and surface opacity based on the active [PerformanceTier].
///
/// - Tier A (Flagship): Lightweight BackdropFilter with bounded sigma (<= 10).
/// - Tier B (Balanced): Crisp M3 Expressive tonal surface with 0 GPU blur passes.
/// - Tier C (PowerSaver): Solid tonal container with 0 blur passes for maximum FPS.
class AdaptiveGlass extends ConsumerWidget {
  const AdaptiveGlass({
    super.key,
    required this.child,
    this.borderRadius,
    this.tierASigma = 10.0,
    this.tierBSigma = 6.0,
    this.blurRadius,
    this.tintColor,
    this.border,
    this.padding,
    this.clipBehavior = Clip.hardEdge,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final double tierASigma;
  final double tierBSigma;
  final double? blurRadius;
  final Color? tintColor;
  final BoxBorder? border;
  final EdgeInsetsGeometry? padding;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PerformanceTier tier = ref.watch(
      adaptivePerformanceProvider.select((s) => s.tier),
    );
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final BorderRadius radius = borderRadius ?? BorderRadius.circular(20);

    // Tier B and Tier C: Completely omit BackdropFilter — zero GPU blur passes
    if (tier != PerformanceTier.tierA) {
      final double alpha = (tier == PerformanceTier.tierB) ? 0.90 : 0.98;
      return ClipRRect(
        borderRadius: radius,
        clipBehavior: clipBehavior,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tintColor ??
                scheme.surfaceContainerHigh.withValues(alpha: alpha),
            borderRadius: radius,
            border: border ??
                Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.35),
                  width: 1.0,
                ),
          ),
          child: child,
        ),
      );
    }

    // Tier A: Bounded sigma (maximum 10.0 to prevent rasterizer stalling)
    final double rawSigma = blurRadius ?? tierASigma;
    final double sigma = math.min(10.0, math.max(2.0, rawSigma));
    const double alpha = 0.65;

    return ClipRRect(
      borderRadius: radius,
      clipBehavior: clipBehavior,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tintColor ??
                scheme.surfaceContainerHigh.withValues(alpha: alpha),
            borderRadius: radius,
            border: border ??
                Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.30),
                  width: 1.0,
                ),
          ),
          child: child,
        ),
      ),
    );
  }
}
