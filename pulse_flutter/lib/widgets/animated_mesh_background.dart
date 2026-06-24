import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';

class AnimatedMeshBackground extends ConsumerStatefulWidget {
  const AnimatedMeshBackground({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AnimatedMeshBackground> createState() => _AnimatedMeshBackgroundState();
}

class _AnimatedMeshBackgroundState extends ConsumerState<AnimatedMeshBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Size size = MediaQuery.sizeOf(context);
    final UiSettingsState settings = ref.watch(uiSettingsProvider);
    final bool optimize = settings.optimizeForWeakDevices;

    // Control animation controller based on optimize settings
    if (optimize) {
      if (_controller.isAnimating) {
        _controller.stop();
      }
    } else {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    }

    if (optimize) {
      return Scaffold(
        backgroundColor: scheme.surface,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: AppTheme.heroGradient(scheme),
          ),
          child: widget.child,
        ),
      );
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: <Widget>[
          // Анимированные фоновые blobs
          AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, Widget? child) {
              final double t = _controller.value * 2 * math.pi;

              // Координаты сфер
              // Сфера 1: круговое движение
              final double x1 = size.width * 0.3 + math.sin(t) * 100;
              final double y1 = size.height * 0.3 + math.cos(t) * 100;

              // Сфера 2: движение по восьмерке (лемнискате)
              final double x2 = size.width * 0.7 + math.sin(t * 2) * 120;
              final double y2 = size.height * 0.6 + math.cos(t) * 80;

              // Сфера 3: хаотичное колебание снизу
              final double x3 = size.width * 0.4 + math.cos(t * 1.5) * 150;
              final double y3 = size.height * 0.8 + math.sin(t * 2.5) * 70;

              return Stack(
                children: <Widget>[
                  // Основной фон
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Color.alphaBlend(
                      scheme.primary.withValues(alpha: 0.02),
                      scheme.surface,
                    ),
                  ),
                  // Blob 1 (Primary)
                  Positioned(
                    left: x1 - 180,
                    top: y1 - 180,
                    child: Container(
                      width: 360,
                      height: 360,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.primary.withValues(alpha: 0.16),
                      ),
                    ),
                  ),
                  // Blob 2 (Tertiary Container / Secondary Container)
                  Positioned(
                    left: x2 - 200,
                    top: y2 - 200,
                    child: Container(
                      width: 400,
                      height: 400,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.tertiaryContainer.withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                  // Blob 3 (Secondary Container)
                  Positioned(
                    left: x3 - 220,
                    top: y3 - 220,
                    child: Container(
                      width: 440,
                      height: 440,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.secondaryContainer.withValues(alpha: 0.14),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          // Эффект размытия матового стекла (Frosted Glass Blur)
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 85, sigmaY: 85),
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),
          ),
          // Контент поверх фона
          Positioned.fill(
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
