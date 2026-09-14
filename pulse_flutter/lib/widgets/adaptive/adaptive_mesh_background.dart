import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

/// An adaptive mesh background that scales its visual complexity based on [PerformanceTier].
///
/// - Tier A (Flagship): Full animated rotating radial gradient blobs.
/// - Tier B (Balanced): Static multi-point radial gradient composite with zero ticker rebuilds.
/// - Tier C (PowerSaver / Weak Devices): Ultrafast static linear hero gradient with 0 CustomPaint.
class AdaptiveMeshBackground extends ConsumerStatefulWidget {
  const AdaptiveMeshBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<AdaptiveMeshBackground> createState() =>
      _AdaptiveMeshBackgroundState();
}

class _AdaptiveMeshBackgroundState extends ConsumerState<AdaptiveMeshBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool active = TickerMode.valuesOf(context).enabled;
    if (active != _isActive) {
      _isActive = active;
      if (active) {
        _syncAnimation();
      } else {
        _controller.stop();
      }
    }
  }

  void _syncAnimation() {
    final tier = ref.read(adaptivePerformanceProvider.select((s) => s.tier));
    final optimize = ref.read(uiSettingsProvider.select((s) => s.optimizeForWeakDevices));
    if (tier == PerformanceTier.tierA && !optimize) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      if (_controller.isAnimating) _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      adaptivePerformanceProvider.select((s) => s.tier),
      (_, _) => _syncAnimation(),
    );
    ref.listen(
      uiSettingsProvider.select((s) => s.optimizeForWeakDevices),
      (_, _) => _syncAnimation(),
    );

    final ColorScheme scheme = Theme.of(context).colorScheme;
    final PerformanceTier tier = ref.watch(
      adaptivePerformanceProvider.select((s) => s.tier),
    );
    final bool optimize = ref.watch(
      uiSettingsProvider.select((s) => s.optimizeForWeakDevices),
    );

    // Tier C or manual weak device override: Zero tickers, zero stacks of blobs, single draw call
    if (tier == PerformanceTier.tierC || optimize) {
      return ColoredBox(
        color: scheme.surface,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppTheme.heroGradient(scheme),
          ),
          child: widget.child,
        ),
      );
    }

    // Tier B: Static radial gradient composite (zero continuous ticker ticks)
    if (tier == PerformanceTier.tierB) {
      return ColoredBox(
        color: scheme.surface,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            RepaintBoundary(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final Size size = constraints.biggest;
                  return Stack(
                    children: <Widget>[
                      _AdaptiveBlob(
                        size: size,
                        cx: 0.3,
                        cy: 0.3,
                        radius: 0.35,
                        color: scheme.primary.withValues(alpha: 0.10),
                        dx: 0,
                        dy: 0,
                      ),
                      _AdaptiveBlob(
                        size: size,
                        cx: 0.7,
                        cy: 0.55,
                        radius: 0.30,
                        color: scheme.tertiaryContainer.withValues(alpha: 0.12),
                        dx: 0,
                        dy: 0,
                      ),
                      _AdaptiveBlob(
                        size: size,
                        cx: 0.45,
                        cy: 0.8,
                        radius: 0.32,
                        color: scheme.secondaryContainer.withValues(alpha: 0.08),
                        dx: 0,
                        dy: 0,
                      ),
                    ],
                  );
                },
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: <Color>[
                      Colors.transparent,
                      scheme.surface.withValues(alpha: 0.4),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(child: widget.child),
          ],
        ),
      );
    }

    // Tier A: Animated multi-point mesh gradient blobs
    return ColoredBox(
      color: scheme.surface,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          RepaintBoundary(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final Size size = constraints.biggest;
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (BuildContext context, Widget? child) {
                    final double t = _controller.value * 2 * math.pi;
                    final double dx1 = math.sin(t) * 35;
                    final double dy1 = math.cos(t * 0.7) * 25;
                    final double dx2 = math.cos(t * 0.8) * 30;
                    final double dy2 = math.sin(t * 0.6) * 20;
                    final double dx3 = math.sin(t * 0.5) * 25;
                    final double dy3 = math.cos(t * 0.9) * 30;

                    return Stack(
                      children: <Widget>[
                        _AdaptiveBlob(
                          size: size,
                          cx: 0.3,
                          cy: 0.3,
                          radius: 0.35,
                          color: scheme.primary.withValues(alpha: 0.10),
                          dx: dx1,
                          dy: dy1,
                        ),
                        _AdaptiveBlob(
                          size: size,
                          cx: 0.7,
                          cy: 0.55,
                          radius: 0.30,
                          color:
                              scheme.tertiaryContainer.withValues(alpha: 0.12),
                          dx: dx2,
                          dy: dy2,
                        ),
                        _AdaptiveBlob(
                          size: size,
                          cx: 0.45,
                          cy: 0.8,
                          radius: 0.32,
                          color:
                              scheme.secondaryContainer.withValues(alpha: 0.08),
                          dx: dx3,
                          dy: dy3,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: <Color>[
                    Colors.transparent,
                    scheme.surface.withValues(alpha: 0.4),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(child: widget.child),
        ],
      ),
    );
  }
}

class _AdaptiveBlob extends StatelessWidget {
  const _AdaptiveBlob({
    required this.size,
    required this.cx,
    required this.cy,
    required this.radius,
    required this.color,
    required this.dx,
    required this.dy,
  });

  final Size size;
  final double cx, cy, radius, dx, dy;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: size.width * cx - size.width * radius + dx,
      top: size.height * cy - size.height * radius + dy,
      width: size.width * radius * 2,
      height: size.height * radius * 2,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[color, color.withValues(alpha: 0)],
            stops: const <double>[0.2, 1.0],
          ),
        ),
      ),
    );
  }
}
