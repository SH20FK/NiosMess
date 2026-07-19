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
  late final AnimationController _lavaController;
  late final AnimationController _pulseController;
  late Color _seedPrimary;
  bool _isActive = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool active = TickerMode.of(context);
    if (active != _isActive) {
      _isActive = active;
      if (active) {
        _lavaController.repeat();
      } else {
        _lavaController.stop();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _lavaController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _seedPrimary = ColorScheme.fromSeed(
      seedColor: widget.color,
      brightness: Theme.of(context).brightness,
    ).primary;
  }

  @override
  void didUpdateWidget(ActiveColorOrb old) {
    super.didUpdateWidget(old);
    if (widget.color != old.color) {
      _seedPrimary = ColorScheme.fromSeed(
        seedColor: widget.color,
        brightness: Theme.of(context).brightness,
      ).primary;
    }
    if (widget.selected && !old.selected) {
      _pulseController.forward(from: 0);
    } else if (!widget.selected && old.selected) {
      _pulseController.reverse();
    }
  }

  @override
  void dispose() {
    _lavaController.dispose();
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
                animation: Listenable.merge([_lavaController, _pulseController]),
                builder: (_, _) {
                  final lava = _lavaController.value;
                  final pulse = _pulseController.value;
                  const double size = 56;
                  return Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.surfaceContainerHighest,
                      border: widget.selected
                          ? Border.all(
                              color: _seedPrimary.withValues(alpha: 0.6),
                              width: 2,
                            )
                          : Border.all(
                              color: scheme.outlineVariant.withValues(alpha: 0.2),
                              width: 1,
                            ),
                      boxShadow: widget.selected
                          ? <BoxShadow>[
                              BoxShadow(
                                color: _seedPrimary.withValues(
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
                    padding: EdgeInsets.all(3.5),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: CustomPaint(
                        painter: _LavaLampPainter(
                          color1: _seedPrimary,
                          color2: widget.color,
                          t: lava,
                          selected: widget.selected,
                        ),
                        child: const SizedBox.expand(),
                      ),
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

class _LavaLampPainter extends CustomPainter {
  const _LavaLampPainter({
    required this.color1,
    required this.color2,
    required this.t,
    required this.selected,
  });

  final Color color1;
  final Color color2;
  final double t;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final double radius = size.width / 2;
    final Offset center = rect.center;

    final Paint leftPaint = Paint()..color = color1;
    final Paint rightPaint = Paint()..color = color2;

    final double wave = math.sin(t) * 0.12;

    final Path leftPath = Path();
    final Path rightPath = Path();

    leftPath.moveTo(center.dx * (1 + wave), 0);
    leftPath.lineTo(0, 0);
    leftPath.lineTo(0, size.height);
    leftPath.lineTo(center.dx * (1 + wave), size.height);

    rightPath.moveTo(center.dx * (1 + wave), 0);
    rightPath.lineTo(size.width, 0);
    rightPath.lineTo(size.width, size.height);
    rightPath.lineTo(center.dx * (1 + wave), size.height);

    for (double y = 0; y <= size.height; y += 4) {
      final double localWave = math.sin(t * 1.3 + y * 0.05) * 4;
      final double x = center.dx * (1 + wave) + localWave;
      leftPath.lineTo(x.clamp(0, center.dx * 2), y);
      rightPath.lineTo(x.clamp(0, center.dx * 2), y);
    }

    canvas.drawPath(leftPath, leftPaint);
    canvas.drawPath(rightPath, rightPaint);

    if (selected) {
      final Paint borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      for (int i = 0; i < 8; i++) {
        final double phase = t + i * 0.8;
        final double alpha = (math.sin(phase) * 0.5 + 0.5) * 0.5;
        borderPaint.color = color1.withValues(alpha: alpha);
        canvas.drawCircle(
          center,
          radius - 2 - i * 0.5,
          borderPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_LavaLampPainter old) =>
      t != old.t ||
      color1 != old.color1 ||
      color2 != old.color2 ||
      selected != old.selected;
}
