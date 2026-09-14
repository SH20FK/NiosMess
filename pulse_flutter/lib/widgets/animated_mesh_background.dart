import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';

class AnimatedMeshBackground extends ConsumerStatefulWidget {
  const AnimatedMeshBackground({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AnimatedMeshBackground> createState() =>
      _AnimatedMeshBackgroundState();
}

class _AnimatedMeshBackgroundState extends ConsumerState<AnimatedMeshBackground>
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
    }
    _syncAnimation();
  }

  void _syncAnimation() {
    if (!mounted) return;
    final bool active = _isActive && TickerMode.valuesOf(context).enabled;
    final PerformanceTier tier =
        ref.read(adaptivePerformanceProvider.select((s) => s.tier));
    final bool optimize =
        ref.read(uiSettingsProvider.select((s) => s.optimizeForWeakDevices));

    final bool shouldRun = active && !optimize && tier == PerformanceTier.tierA;
    if (shouldRun) {
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

    if (optimize || tier == PerformanceTier.tierC) {
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

    if (tier == PerformanceTier.tierB) {
      const double t = math.pi;
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
                      _Blob(
                        size: size,
                        cx: 0.3,
                        cy: 0.3,
                        radius: 0.35,
                        color: scheme.primary.withValues(alpha: 0.10),
                        t: t,
                        speed: 1.0,
                      ),
                      _Blob(
                        size: size,
                        cx: 0.7,
                        cy: 0.55,
                        radius: 0.30,
                        color: scheme.tertiaryContainer.withValues(alpha: 0.12),
                        t: t * 0.7,
                        speed: 0.7,
                      ),
                      _Blob(
                        size: size,
                        cx: 0.45,
                        cy: 0.8,
                        radius: 0.32,
                        color:
                            scheme.secondaryContainer.withValues(alpha: 0.08),
                        t: t * 0.5,
                        speed: 0.5,
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
                    return Stack(
                      children: <Widget>[
                        _Blob(
                          size: size,
                          cx: 0.3,
                          cy: 0.3,
                          radius: 0.35,
                          color: scheme.primary.withValues(alpha: 0.10),
                          t: t,
                          speed: 1.0,
                        ),
                        _Blob(
                          size: size,
                          cx: 0.7,
                          cy: 0.55,
                          radius: 0.30,
                          color:
                              scheme.tertiaryContainer.withValues(alpha: 0.12),
                          t: t * 0.7,
                          speed: 0.7,
                        ),
                        _Blob(
                          size: size,
                          cx: 0.45,
                          cy: 0.8,
                          radius: 0.32,
                          color:
                              scheme.secondaryContainer.withValues(alpha: 0.08),
                          t: t * 0.5,
                          speed: 0.5,
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

class _Blob extends StatelessWidget {
  const _Blob({
    required this.size,
    required this.cx,
    required this.cy,
    required this.radius,
    required this.color,
    required this.t,
    required this.speed,
  });

  final Size size;
  final double cx, cy, radius, t, speed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final double dx = math.sin(t * speed) * 40;
    final double dy = math.cos(t * speed * 0.7) * 30;

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
