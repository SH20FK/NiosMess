import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

class ActiveColorOrb extends ConsumerStatefulWidget {
  const ActiveColorOrb({
    required this.color,
    required this.selected,
    required this.onTap,
    required this.label,
    super.key,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final String label;

  @override
  ConsumerState<ActiveColorOrb> createState() => _ActiveColorOrbState();
}

class _ActiveColorOrbState extends ConsumerState<ActiveColorOrb>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late ColorScheme _previewScheme;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _previewScheme = ColorScheme.fromSeed(
      seedColor: widget.color,
      brightness: Theme.of(context).brightness,
    );

    if (widget.selected) {
      _pulseController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(ActiveColorOrb old) {
    super.didUpdateWidget(old);
    if (widget.color != old.color) {
      _previewScheme = ColorScheme.fromSeed(
        seedColor: widget.color,
        brightness: Theme.of(context).brightness,
      );
    }
    if (widget.selected && !old.selected) {
      _pulseController.forward(from: 0);
    } else if (!widget.selected && old.selected) {
      _pulseController.reverse();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      selected: widget.selected,
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTap: () {
          ref.read(appSoundProvider).playUiTick();
          if (ref.read(uiSettingsProvider).haptics) {
            HapticService.tap();
          }
          widget.onTap();
        },
        child: RepaintBoundary(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AnimatedBuilder(
                animation: _pulseController,
                builder: (_, _) {
                  final pulse = _pulseController.value;
                  return Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: widget.selected
                          ? Border.all(
                              color: _previewScheme.primary.withValues(alpha: 0.6),
                              width: 2,
                            )
                          : Border.all(
                              color: scheme.outlineVariant.withValues(alpha: 0.2),
                              width: 1,
                            ),
                      boxShadow: widget.selected
                          ? <BoxShadow>[
                              BoxShadow(
                                color: _previewScheme.primary.withValues(
                                    alpha: 0.3 + pulse * 0.2),
                                blurRadius: 8 + pulse * 6,
                                spreadRadius: 1 + pulse * 2,
                              ),
                            ]
                          : <BoxShadow>[
                              BoxShadow(
                                color: scheme.shadow.withValues(alpha: 0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    padding: EdgeInsets.all(2.5),
                    child: CustomPaint(
                      painter: _PaletteOrbPainter(scheme: _previewScheme),
                      child: const SizedBox.expand(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 6),
              Text(
                widget.label,
                style: textTheme.labelSmall?.copyWith(
                  color: widget.selected
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                  fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaletteOrbPainter extends CustomPainter {
  const _PaletteOrbPainter({required this.scheme});

  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.shortestSide / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    final Paint paint = Paint()..style = PaintingStyle.fill;

    final List<Color> colors = <Color>[
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
      scheme.primaryContainer,
    ];

    for (int i = 0; i < 4; i++) {
      paint.color = colors[i];
      canvas.drawArc(
        rect,
        (-math.pi / 2) + (i * math.pi / 2),
        math.pi / 2,
        true,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PaletteOrbPainter oldDelegate) {
    return oldDelegate.scheme != scheme;
  }
}
