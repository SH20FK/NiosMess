import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';

/// An adaptive tonal container that adjusts its surface tone and opacity
/// based on the active [PerformanceTier].
/// Strictly enforces bounded GPU blur passes for static panels on Tier A,
/// and zero live blur passes on Tier B/C or inside scrollables to maintain 120 FPS.
class AdaptiveGlass extends ConsumerWidget {
  const AdaptiveGlass({
    super.key,
    required this.child,
    this.borderRadius,
    this.tierASigma = 0.0,
    this.tierBSigma = 0.0,
    this.blurRadius,
    this.tintColor,
    this.border,
    this.padding,
    this.clipBehavior = Clip.hardEdge,
    this.isStaticPanel = false,
    this.inScrollable,
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
  final bool isStaticPanel;
  final bool? inScrollable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PerformanceTier tier = ref.watch(
      adaptivePerformanceProvider.select((s) => s.tier),
    );
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final BorderRadius radius = borderRadius ?? BorderRadius.circular(20);

    // Tier C / PowerSaver: fully opaque tonal surface (0.98 alpha)
    // Tier A/B: clean M3 Expressive tonal surface (0.92 alpha)
    final double alpha = (tier == PerformanceTier.tierC) ? 0.98 : 0.92;
    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: tintColor ??
            scheme.surfaceContainerHigh.withValues(alpha: alpha),
        borderRadius: radius,
        border: border ??
            Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.25),
              width: 1.0,
            ),
      ),
      child: child,
    );

    // Pure Material 3 Expressive tonal surface with zero live raster blur passes
    // to maintain 60-120 FPS fluidity across all device tiers.

    if (clipBehavior == Clip.none) {
      return content;
    }
    return ClipRRect(
      borderRadius: radius,
      clipBehavior: clipBehavior,
      child: content,
    );
  }
}
