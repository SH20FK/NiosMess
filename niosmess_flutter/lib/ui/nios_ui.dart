import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class NiosSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  static const EdgeInsets page = EdgeInsets.fromLTRB(16, 16, 16, 24);
}

class NiosRadii {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double pill = 999.0;
}

class NiosPalette {
  static ColorScheme _scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF4F46E5),
    brightness: Brightness.dark,
  );

  // Active theme values (Material 3 derived)
  static Color background = _scheme.surface;
  static Color surface = _scheme.surface;
  static Color surfaceAlt = _scheme.surfaceContainer;
  static Color surfaceHover = _scheme.surfaceContainerHigh;
  static Color surfaceActive = _scheme.surfaceContainerHighest;
  static Color text = _scheme.onSurface;
  static Color textSecondary = _scheme.onSurfaceVariant;
  static Color textTertiary = _scheme.onSurfaceVariant.withValues(alpha: 0.7);
  static Color accent = _scheme.primary;
  static Color accentHover = _scheme.primary;
  static Color accentLight = _scheme.primaryContainer;
  static Color messageOut = _scheme.primaryContainer;
  static Color messageIn = _scheme.surfaceContainerHigh;
  static Color border = _scheme.outline;
  static Color borderLight = _scheme.outlineVariant;
  static Color shadow = Colors.black.withValues(alpha: 0.2);
  static Color shadowGlow = _scheme.primary.withValues(alpha: 0.16);

  // Online status
  static Color online = _scheme.tertiary;

  static void apply(ColorScheme scheme) {
    _scheme = scheme;
    background = scheme.surface;
    surface = scheme.surface;
    surfaceAlt = scheme.surfaceContainer;
    surfaceHover = scheme.surfaceContainerHigh;
    surfaceActive = scheme.surfaceContainerHighest;
    text = scheme.onSurface;
    textSecondary = scheme.onSurfaceVariant;
    textTertiary = scheme.onSurfaceVariant.withValues(alpha: 0.7);
    accent = scheme.primary;
    accentHover = scheme.primary;
    accentLight = scheme.primaryContainer;
    messageOut = scheme.primaryContainer;
    messageIn = scheme.surfaceContainerHigh;
    border = scheme.outline;
    borderLight = scheme.outlineVariant;
    shadow = Colors.black.withValues(alpha: 0.2);
    shadowGlow = scheme.primary.withValues(alpha: 0.16);
    online = scheme.tertiary;
  }
}

class NiosScaffold extends StatelessWidget {
  const NiosScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.bottomNavigationBar,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      backgroundColor: Theme.of(context).colorScheme.background,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: SafeArea(child: body),
    );
  }
}

class NiosMotionWrap extends StatefulWidget {
  const NiosMotionWrap({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 520),
    this.delay = Duration.zero,
    this.offset = const Offset(0, 16),
    this.blurSigma = 12,
    this.curve = Curves.easeOutCubic,
    this.enableMotion = true,
  });

  final Widget child;
  final Duration duration;
  final Duration delay;
  final Offset offset;
  final double blurSigma;
  final Curve curve;
  final bool enableMotion;

  @override
  State<NiosMotionWrap> createState() => _NiosMotionWrapState();
}

class _NiosMotionWrapState extends State<NiosMotionWrap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
    if (widget.enableMotion) {
      _startWithDelay();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant NiosMotionWrap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.curve != widget.curve) {
      _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
    }
    if (!oldWidget.enableMotion && widget.enableMotion) {
      _controller.value = 0.0;
      _startWithDelay();
    } else if (oldWidget.enableMotion && !widget.enableMotion) {
      _delayTimer?.cancel();
      _controller.stop();
      _controller.value = 1.0;
    }
  }

  void _startWithDelay() {
    _delayTimer?.cancel();
    if (widget.delay > Duration.zero) {
      _delayTimer = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enableMotion) return widget.child;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final t = _animation.value;
        final offset =
            Offset(widget.offset.dx * (1 - t), widget.offset.dy * (1 - t));
        final blur = widget.blurSigma * (1 - t);
        Widget current = child!;
        if (blur > 0.01) {
          current = ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: current,
          );
        }
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: offset, child: current),
        );
      },
      child: widget.child,
    );
  }
}

class NiosCard extends StatelessWidget {
  const NiosCard({
    super.key,
    required this.child,
    this.padding,
    this.elevation = 0,
  });

  final Widget child;
  final EdgeInsets? padding;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: elevation,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NiosRadii.md),
        side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant, width: 0.5),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(NiosSpacing.md),
        child: child,
      ),
    );
  }
}

class NiosSectionTitle extends StatelessWidget {
  const NiosSectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class NiosPrimaryButton extends StatelessWidget {
  const NiosPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton(
      onPressed: loading ? null : onTap,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading) ...[
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.onPrimary,
              ),
            ),
            const SizedBox(width: 12),
          ] else if (icon != null) ...[
            Icon(icon, size: 18),
            const SizedBox(width: 8),
          ],
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class NiosGhostButton extends StatelessWidget {
  const NiosGhostButton({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(label),
    );
  }
}

InputDecoration niosInputDecoration(String hint, {IconData? icon}) {
  final scheme = NiosPalette._scheme;
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: scheme.surfaceVariant,
    prefixIcon:
        icon != null ? Icon(icon, color: scheme.onSurfaceVariant) : null,
    hintStyle: TextStyle(color: scheme.onSurfaceVariant),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(NiosRadii.md),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(NiosRadii.md),
      borderSide: BorderSide(color: scheme.outlineVariant),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(NiosRadii.md),
      borderSide: BorderSide(color: scheme.primary),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(NiosRadii.md),
      borderSide: BorderSide(color: scheme.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(NiosRadii.md),
      borderSide: BorderSide(color: scheme.error),
    ),
  );
}

class NiosBadge extends StatefulWidget {
  const NiosBadge({
    super.key,
    required this.tooltip,
    this.icon = '🦊',
    this.size = 20,
    this.reduceMotion = false,
  });

  final String tooltip;
  final String icon;
  final double size;
  final bool reduceMotion;

  @override
  State<NiosBadge> createState() => _NiosBadgeState();
}

class _NiosBadgeState extends State<NiosBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  OverlayEntry? _entry;
  final ValueNotifier<bool> _tooltipVisible = ValueNotifier(false);
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    if (!widget.reduceMotion) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant NiosBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reduceMotion != widget.reduceMotion) {
      if (widget.reduceMotion) {
        _controller.stop();
      } else {
        _controller.repeat();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _removeTooltip();
    _tooltipVisible.dispose();
    super.dispose();
  }

  void _removeTooltip() {
    _entry?.remove();
    _entry = null;
  }

  void _toggleTooltip() {
    if (_open) {
      _open = false;
      _tooltipVisible.value = false;
      Future.delayed(const Duration(milliseconds: 220), _removeTooltip);
      return;
    }

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    _open = true;
    _tooltipVisible.value = true;

    _entry = OverlayEntry(
      builder: (context) {
        final screen = MediaQuery.of(context).size;
        const tooltipWidth = 280.0;
        final left = (offset.dx + size.width / 2 - tooltipWidth / 2)
            .clamp(8.0, screen.width - tooltipWidth - 8.0);
        return Positioned(
          top: offset.dy + size.height + 8,
          left: left,
          child: ValueListenableBuilder<bool>(
            valueListenable: _tooltipVisible,
            builder: (context, visible, _) => _BadgeTooltip(
              text: widget.tooltip,
              visible: visible,
              width: tooltipWidth,
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_entry!);
  }

  String _mapIcon(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '🦊';
    if (value.toLowerCase() == 'fox') return '🦊';
    return value;
  }

  Widget _buildIcon() {
    final icon = _mapIcon(widget.icon);
    final isUrl = icon.startsWith('http://') || icon.startsWith('https://');
    final isAsset = icon.startsWith('assets/') ||
        icon.endsWith('.png') ||
        icon.endsWith('.jpg') ||
        icon.endsWith('.webp');
    if (isUrl) {
      return CachedNetworkImage(
        imageUrl: icon,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) =>
            Text('🦊', style: TextStyle(fontSize: widget.size * 0.46)),
      );
    }
    if (isAsset) {
      return Image.asset(icon, fit: BoxFit.cover);
    }
    return Text(icon, style: TextStyle(fontSize: widget.size * 0.46));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleTooltip,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                painter: _BadgeParticlesPainter(_controller.value),
                size: Size(widget.size, widget.size),
              ),
            ),
            Container(
              width: widget.size * 0.72,
              height: widget.size * 0.72,
              decoration: BoxDecoration(
                color: NiosPalette.surfaceHover,
                shape: BoxShape.circle,
                border: Border.all(color: NiosPalette.borderLight),
                boxShadow: [
                  BoxShadow(
                    color: NiosPalette.shadowGlow,
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: _buildIcon(),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeTooltip extends StatelessWidget {
  const _BadgeTooltip(
      {required this.text, required this.visible, required this.width});
  final String text;
  final bool visible;
  final double width;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: visible ? 1 : 0,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        scale: visible ? 1 : 0.96,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: width,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: NiosPalette.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: NiosPalette.borderLight),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              text,
              style: TextStyle(color: NiosPalette.text, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgeParticlesPainter extends CustomPainter {
  _BadgeParticlesPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;
    final radius = size.width * 0.45;
    for (var i = 0; i < 12; i++) {
      final angle = (progress * 2 * math.pi) + (i * 0.52);
      final dist = radius + (i % 3) * 2;
      final dot = Offset(center.dx + dist * math.cos(angle),
          center.dy + dist * math.sin(angle));
      final alpha =
          (0.5 + 0.5 * math.sin(angle + progress * 6)).clamp(0.2, 0.9);
      paint.color = NiosPalette.accent.withValues(alpha: alpha);

      canvas.drawCircle(dot, i % 3 == 0 ? 1.6 : 1.1, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BadgeParticlesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class NiosNoiseLayer extends StatelessWidget {
  const NiosNoiseLayer({super.key, this.opacity = 0.2});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: CustomPaint(
        painter: _NoisePainter(),
      ),
    );
  }
}

class _NoisePainter extends CustomPainter {
  Size? _lastSize;
  List<Offset> _points = const [];

  @override
  void paint(Canvas canvas, Size size) {
    if (_lastSize != size) {
      _lastSize = size;
      final seed = size.width.toInt() * 37 + size.height.toInt() * 91;
      final rng = math.Random(seed);
      final count = (size.width * size.height / 140).round().clamp(600, 2400);
      _points = List<Offset>.generate(
        count,
        (_) => Offset(
            rng.nextDouble() * size.width, rng.nextDouble() * size.height),
      );
    }
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawPoints(ui.PointMode.points, _points, paint);
  }

  @override
  bool shouldRepaint(covariant _NoisePainter oldDelegate) => false;
}
