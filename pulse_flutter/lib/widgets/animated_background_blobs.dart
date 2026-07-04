import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

class AnimatedBackgroundBlobs extends ConsumerStatefulWidget {
  const AnimatedBackgroundBlobs({
    required this.child,
    this.optimize = false,
    super.key,
  });

  final Widget child;
  final bool optimize;

  @override
  ConsumerState<AnimatedBackgroundBlobs> createState() =>
      _AnimatedBackgroundBlobsState();
}

class _AnimatedBackgroundBlobsState
    extends ConsumerState<AnimatedBackgroundBlobs>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blobController;
  bool _isActive = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool active = TickerMode.of(context);
    if (active != _isActive) {
      _isActive = active;
      if (active) {
        _blobController.repeat();
      } else {
        _blobController.stop();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _blobController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );
  }

  @override
  void dispose() {
    _blobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final UiSettingsState settings = ref.watch(uiSettingsProvider);
    final bool isOptimized = widget.optimize || settings.optimizeForWeakDevices;

    if (isOptimized) {
      _blobController.stop();
      return Scaffold(
        backgroundColor: scheme.surface,
        body: widget.child,
      );
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: <Widget>[
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _blobController,
              builder: (BuildContext context, Widget? _) {
                final double t = _blobController.value * 2 * math.pi;
                return Stack(
                  children: <Widget>[
                    _Blob(
                      cx: 0.28,
                      cy: 0.25,
                      radius: 0.35,
                      color: scheme.primary.withValues(alpha: 0.16),
                      t: t,
                      speed: 1.0,
                    ),
                    _Blob(
                      cx: 0.72,
                      cy: 0.55,
                      radius: 0.38,
                      color: scheme.tertiaryContainer.withValues(alpha: 0.18),
                      t: t * 0.7,
                      speed: 0.7,
                    ),
                    _Blob(
                      cx: 0.45,
                      cy: 0.82,
                      radius: 0.40,
                      color: scheme.secondaryContainer.withValues(alpha: 0.14),
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
}

class _Blob extends StatelessWidget {
  const _Blob({
    required this.cx,
    required this.cy,
    required this.radius,
    required this.color,
    required this.t,
    required this.speed,
  });

  final double cx, cy, radius, t, speed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
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
