import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

class PulseScaffoldBody extends StatelessWidget {
  const PulseScaffoldBody({
    required this.child,
    this.maxWidth = 1280,
    this.topSafe = false,
    this.bottomSafe = true,
    this.bottomPadding = 0,
    this.animatedBackdrop = true,
    this.expand = false,
    this.alignment = Alignment.topCenter,
    super.key,
  });

  final Widget child;
  final double maxWidth;
  final bool topSafe;
  final bool bottomSafe;
  final double bottomPadding;
  final bool animatedBackdrop;
  final bool expand;
  final AlignmentGeometry alignment;

  bool get _isDesktop {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.windows ||
           defaultTargetPlatform == TargetPlatform.macOS ||
           defaultTargetPlatform == TargetPlatform.linux;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(child: _PulseBackdrop(animated: _isDesktop ? false : animatedBackdrop)),
        SafeArea(
          top: topSafe,
          bottom: bottomSafe,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              if (expand) {
                return SizedBox.expand(child: child);
              }
              final double width = constraints.maxWidth < maxWidth
                  ? constraints.maxWidth
                  : maxWidth;
              final double height = constraints.maxHeight - bottomPadding;

              return Align(
                alignment: alignment,
                child: SizedBox(
                  width: width,
                  height: height > 0 ? height : 0,
                  child: child,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BackdropCacheKey {
  const _BackdropCacheKey({
    required this.width,
    required this.height,
    required this.primaryColor,
    required this.brightness,
    required this.devicePixelRatio,
    required this.isWeakDevice,
  });

  final int width;
  final int height;
  final int primaryColor;
  final Brightness brightness;
  final double devicePixelRatio;
  final bool isWeakDevice;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _BackdropCacheKey &&
          width == other.width &&
          height == other.height &&
          primaryColor == other.primaryColor &&
          brightness == other.brightness &&
          devicePixelRatio == other.devicePixelRatio &&
          isWeakDevice == other.isWeakDevice;

  @override
  int get hashCode => Object.hash(
        width,
        height,
        primaryColor,
        brightness,
        devicePixelRatio,
        isWeakDevice,
      );
}

class _BackdropImageCache {
  static _BackdropCacheKey? _cachedKey;
  static ui.Image? _cachedImage;

  static ui.Image? getSync(_BackdropCacheKey key) {
    if (_cachedKey == key && _cachedImage != null) {
      return _cachedImage;
    }
    return null;
  }

  static ui.Image renderSync({
    required int width,
    required int height,
    required double devicePixelRatio,
    required bool isWeakDevice,
    required ColorScheme scheme,
    required Brightness brightness,
  }) {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Size size = Size(width.toDouble(), height.toDouble());

    final _BackdropPainter painter = _BackdropPainter(
      t: 0.5,
      scheme: scheme,
      brightness: brightness,
      isWeakDevice: isWeakDevice,
    );
    painter.paint(canvas, size);

    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = picture.toImageSync(width, height);
    picture.dispose();

    if (_cachedImage != null && _cachedImage != image) {
      _cachedImage!.dispose();
    }
    _cachedKey = _BackdropCacheKey(
      width: width,
      height: height,
      primaryColor: scheme.primary.toARGB32(),
      brightness: brightness,
      devicePixelRatio: devicePixelRatio,
      isWeakDevice: isWeakDevice,
    );
    _cachedImage = image;
    return image;
  }
}

class _PulseBackdrop extends ConsumerStatefulWidget {
  const _PulseBackdrop({required this.animated});

  final bool animated;

  @override
  ConsumerState<_PulseBackdrop> createState() => _PulseBackdropState();
}

class _PulseBackdropState extends ConsumerState<_PulseBackdrop>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.animated && !kIsWeb) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 60),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(_PulseBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animated != oldWidget.animated) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (!mounted || kIsWeb) return;
    final bool optimize = ref.read(
      uiSettingsProvider.select((s) => s.optimizeForWeakDevices),
    );
    final bool shouldAnimate = widget.animated && !optimize;

    if (shouldAnimate) {
      _controller ??= AnimationController(
        vsync: this,
        duration: const Duration(seconds: 60),
      );
      if (!_controller!.isAnimating) {
        _controller!.repeat(reverse: true);
      }
    } else {
      if (_controller != null && _controller!.isAnimating) {
        _controller!.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Brightness brightness = theme.brightness;
    final PerformanceTier tier = ref.watch(
      adaptivePerformanceProvider.select((s) => s.tier),
    );
    final bool optimize = ref.watch(
      uiSettingsProvider.select((s) => s.optimizeForWeakDevices),
    );
    final bool isWeak = tier == PerformanceTier.tierC || optimize;

    final bool shouldAnimate =
        widget.animated && !isWeak && !kIsWeb && _controller != null;

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
            return const SizedBox.shrink();
          }

          final double rawDpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
          final double dpr = rawDpr.clamp(1.0, 2.0);
          final int rawW = (constraints.maxWidth * (isWeak ? 1.0 : dpr)).ceil();
          final int rawH = (constraints.maxHeight * (isWeak ? 1.0 : dpr)).ceil();
          final int width = math.max(64, ((rawW + 15) ~/ 16) * 16);
          final int height = math.max(64, ((rawH + 15) ~/ 16) * 16);

          final _BackdropCacheKey key = _BackdropCacheKey(
            width: width,
            height: height,
            primaryColor: scheme.primary.toARGB32(),
            brightness: brightness,
            devicePixelRatio: isWeak ? 1.0 : dpr,
            isWeakDevice: isWeak,
          );

          ui.Image? image = _BackdropImageCache.getSync(key);
          image ??= _BackdropImageCache.renderSync(
            width: width,
            height: height,
            devicePixelRatio: isWeak ? 1.0 : dpr,
            isWeakDevice: isWeak,
            scheme: scheme,
            brightness: brightness,
          );

          final Widget staticImage = RawImage(
            image: image,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          );

          if (!shouldAnimate) {
            return staticImage;
          }

          return AnimatedBuilder(
            animation: _controller!,
            builder: (BuildContext context, Widget? child) {
              final double t = _controller!.value * 2 * math.pi;
              return Transform.translate(
                offset: Offset(
                  math.sin(t) * 10.0,
                  math.cos(t * 0.7) * 6.0,
                ),
                child: child,
              );
            },
            child: staticImage,
          );
        },
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter({
    required this.t,
    required this.scheme,
    required this.brightness,
    this.isWeakDevice = false,
  });

  final double t;
  final ColorScheme scheme;
  final Brightness brightness;
  final bool isWeakDevice;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !size.width.isFinite || !size.height.isFinite) return;

    final Rect rect = Offset.zero & size;
    final Paint gradientPaint = Paint()
      ..shader = AppTheme.heroGradient(scheme).createShader(rect);
    canvas.drawRect(rect, gradientPaint);

    if (isWeakDevice) {
      return;
    }

    final double tw = t * math.pi * 2;

    final bool isDark = brightness == Brightness.dark;
    final Color primaryShape = scheme.primary.withValues(alpha: isDark ? 0.18 : 0.08);
    final Color secondaryShape = scheme.secondary.withValues(alpha: isDark ? 0.15 : 0.06);
    final Color tertiaryShape = scheme.tertiary.withValues(alpha: isDark ? 0.15 : 0.06);

    _drawPolygon(
      canvas,
      size,
      alignmentX: -1.02 + (math.sin(tw) * 0.06),
      alignmentY: -0.84 + (math.cos(tw * 0.7) * 0.04),
      angle: -0.18 + (math.sin(tw * 0.45) * 0.05),
      polygonSize: 280,
      sides: 6,
      cornerRadius: 28,
      color: primaryShape,
    );

    _drawPolygon(
      canvas,
      size,
      alignmentX: 1.08 + (math.cos(tw * 0.8) * 0.05),
      alignmentY: -0.10 + (math.sin(tw * 0.6) * 0.05),
      angle: 0.24 + (math.cos(tw * 0.5) * 0.04),
      polygonSize: 220,
      sides: 5,
      cornerRadius: 24,
      color: secondaryShape,
    );

    _drawPolygon(
      canvas,
      size,
      alignmentX: 0.72 + (math.sin(tw * 0.5) * 0.04),
      alignmentY: 0.95 + (math.cos(tw * 0.9) * 0.03),
      angle: -0.12 + (math.sin(tw * 0.55) * 0.03),
      polygonSize: 180,
      sides: 7,
      cornerRadius: 22,
      color: tertiaryShape,
    );
  }

  void _drawPolygon(
    Canvas canvas,
    Size canvasSize, {
    required double alignmentX,
    required double alignmentY,
    required double angle,
    required double polygonSize,
    required int sides,
    required double cornerRadius,
    required Color color,
  }) {
    final double cx = (alignmentX + 1) / 2 * canvasSize.width;
    final double cy = (alignmentY + 1) / 2 * canvasSize.height;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(angle);

    final Path path = _roundedPolygonPath(polygonSize, sides, cornerRadius);

    final Rect pathBounds = Rect.fromCenter(
      center: Offset.zero,
      width: polygonSize,
      height: polygonSize,
    );
    if (!pathBounds.isFinite || pathBounds.isEmpty) {
      canvas.restore();
      return;
    }
    final Paint paint = Paint()
      ..maskFilter = kIsWeb
          ? const MaskFilter.blur(BlurStyle.normal, 16)
          : const MaskFilter.blur(BlurStyle.normal, 56)
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          color,
          color.withValues(alpha: color.a * 0.4),
        ],
      ).createShader(pathBounds);

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  Path _roundedPolygonPath(double size, int sides, double radius) {
    final int safeSides = sides < 3 ? 3 : sides;
    final double polygonRadius = size / 2;
    final List<Offset> vertices = List<Offset>.generate(safeSides, (int index) {
      final double angle = (-math.pi / 2) + ((2 * math.pi * index) / safeSides);
      return Offset(
        polygonRadius * math.cos(angle),
        polygonRadius * math.sin(angle),
      );
    });

    final Path path = Path();
    for (int index = 0; index < vertices.length; index++) {
      final Offset previous =
          vertices[(index - 1 + vertices.length) % vertices.length];
      final Offset current = vertices[index];
      final Offset next = vertices[(index + 1) % vertices.length];

      final Offset toPrevious = previous - current;
      final Offset toNext = next - current;
      final double effectiveRadius = math.min(
        radius,
        math.min(toPrevious.distance, toNext.distance) / 2,
      );

      final Offset start = current + (_normalize(toPrevious) * effectiveRadius);
      final Offset end = current + (_normalize(toNext) * effectiveRadius);

      if (index == 0) {
        path.moveTo(start.dx, start.dy);
      } else {
        path.lineTo(start.dx, start.dy);
      }

      path.quadraticBezierTo(current.dx, current.dy, end.dx, end.dy);
    }

    path.close();
    return path;
  }

  Offset _normalize(Offset offset) {
    if (offset.distance == 0) return Offset.zero;
    return Offset(offset.dx / offset.distance, offset.dy / offset.distance);
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter oldDelegate) {
    return scheme.primary != oldDelegate.scheme.primary ||
        brightness != oldDelegate.brightness ||
        isWeakDevice != oldDelegate.isWeakDevice;
  }
}
