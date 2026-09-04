import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';

/// A drop-in adaptive glass container that adjusts its backdrop blur
/// and surface opacity based on the active [PerformanceTier].
///
/// - Tier A (Flagship): Full BackdropFilter with high sigma (18-24).
/// - Tier B (Balanced): Reduced BackdropFilter with moderate sigma (6-8).
/// - Tier C (PowerSaver): Solid tonal container with 0 blur passes for maximum FPS.
class AdaptiveGlass extends ConsumerWidget {
  const AdaptiveGlass({
    super.key,
    required this.child,
    this.borderRadius,
    this.tierASigma = 20.0,
    this.tierBSigma = 8.0,
    this.blurRadius,
    this.tintColor,
    this.border,
    this.padding,
    this.clipBehavior = Clip.antiAlias,
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

    // Tier C: Completely omit BackdropFilter — zero GPU blur passes
    if (tier == PerformanceTier.tierC) {
      return ClipRRect(
        borderRadius: radius,
        clipBehavior: clipBehavior,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tintColor ?? scheme.surfaceContainerHigh.withValues(alpha: 0.95),
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

    final double effectiveTierASigma = blurRadius ?? tierASigma;
    final double effectiveTierBSigma =
        blurRadius != null ? (blurRadius! * 0.35).clamp(4.0, 10.0) : tierBSigma;
    final double sigma =
        (tier == PerformanceTier.tierA) ? effectiveTierASigma : effectiveTierBSigma;
    final double alpha = (tier == PerformanceTier.tierA) ? 0.65 : 0.85;

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
