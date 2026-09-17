import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/motion/nios_motion.dart';
import 'package:pulse_flutter/core/motion/tri_sync.dart';

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
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late ColorScheme _previewScheme;

  /// Static scheme memoizer to prevent heavy HCT quantization spikes on UI thread.
  static final Map<int, ColorScheme> _schemeCache = <int, ColorScheme>{};

  static ColorScheme _getScheme(Color seed, Brightness brightness) {
    final int key = seed.toARGB32() ^ (brightness == Brightness.dark ? 1 : 0);
    return _schemeCache.putIfAbsent(
      key,
      () => ColorScheme.fromSeed(seedColor: seed, brightness: brightness),
    );
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController.unbounded(
      vsync: this,
      value: widget.selected ? 1.0 : 0.0,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _previewScheme = _getScheme(widget.color, Theme.of(context).brightness);
  }

  @override
  void didUpdateWidget(ActiveColorOrb old) {
    super.didUpdateWidget(old);
    if (widget.color != old.color) {
      _previewScheme = _getScheme(widget.color, Theme.of(context).brightness);
    }
    if (widget.selected && !old.selected) {
      _pulseController.animateWithSpring(
        spring: NiosMotion.snappy,
        target: 1.0,
      );
    } else if (!widget.selected && old.selected) {
      _pulseController.animateWithSpring(
        spring: NiosMotion.snappy,
        target: 0.0,
      );
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
          TriSync.snap(ref: ref, context: context);
          widget.onTap();
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedBuilder(
              animation: _pulseController,
              builder: (_, _) {
                final pulse = _pulseController.value;
                return Material(
                  type: MaterialType.transparency,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: Transform.scale(
                    scale: 1.0 + pulse * 0.05,
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.selected
                            ? scheme.surfaceContainerHighest
                            : scheme.surfaceContainerLow,
                        border: widget.selected
                            ? Border.all(
                                color: _previewScheme.primary,
                                width: 2.5,
                              )
                            : Border.all(
                                color: scheme.outlineVariant.withValues(alpha: 0.20),
                                width: 1,
                              ),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: CustomPaint(
                        painter: _PaletteOrbPainter(scheme: _previewScheme),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              widget.label,
              style: textTheme.labelMedium?.copyWith(
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
