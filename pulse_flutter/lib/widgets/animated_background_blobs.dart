import 'dart:math' as math;
import 'dart:ui' as ui;
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
  ConsumerState<AnimatedBackgroundBlobs> createState() => _AnimatedBackgroundBlobsState();
}

class _AnimatedBackgroundBlobsState extends ConsumerState<AnimatedBackgroundBlobs>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blobController;

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
    final Size size = MediaQuery.sizeOf(context);
    final UiSettingsState settings = ref.watch(uiSettingsProvider);
    final bool isOptimized = widget.optimize || settings.optimizeForWeakDevices;

    if (isOptimized) {
      _blobController.stop();
      return Scaffold(
        backgroundColor: scheme.surface,
        body: widget.child,
      );
    }

    if (!_blobController.isAnimating) {
      _blobController.repeat();
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _blobController,
            builder: (context, _) {
              final double t = _blobController.value * 2 * math.pi;
              return CustomPaint(
                painter: _BlobPainter(t: t, scheme: scheme, size: size),
                size: size,
              );
            },
          ),
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          Positioned.fill(child: widget.child),
        ],
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  const _BlobPainter({
    required this.t,
    required this.scheme,
    required this.size,
  });

  final double t;
  final ColorScheme scheme;
  final Size size;

  @override
  void paint(Canvas canvas, Size _) {
    final List<_BlobData> blobs = [
      _BlobData(
        cx: size.width * 0.28, cy: size.height * 0.25,
        radius: 180, color: scheme.primary.withValues(alpha: 0.16),
        orbitR: 80, orbitSpeed: 1.0, deformAmp: 24, deformSpeed: 1.3, vertexCount: 8,
      ),
      _BlobData(
        cx: size.width * 0.72, cy: size.height * 0.55,
        radius: 200, color: scheme.tertiaryContainer.withValues(alpha: 0.18),
        orbitR: 100, orbitSpeed: 0.7, deformAmp: 28, deformSpeed: 0.9, vertexCount: 10,
      ),
      _BlobData(
        cx: size.width * 0.45, cy: size.height * 0.82,
        radius: 220, color: scheme.secondaryContainer.withValues(alpha: 0.14),
        orbitR: 90, orbitSpeed: 0.5, deformAmp: 20, deformSpeed: 1.1, vertexCount: 9,
      ),
    ];

    for (final blob in blobs) {
      _drawBlob(canvas, blob);
    }
  }

  void _drawBlob(Canvas canvas, _BlobData blob) {
    final double orbitAngle = t * blob.orbitSpeed;
    final double cx = blob.cx + math.cos(orbitAngle) * blob.orbitR;
    final double cy = blob.cy + math.sin(orbitAngle * 0.7) * blob.orbitR * 0.6;

    final Path path = Path();
    final int n = blob.vertexCount;

    for (int i = 0; i < n; i++) {
      final double baseAngle = (2 * math.pi * i) / n - math.pi / 2;
      final double deform = math.sin(t * blob.deformSpeed + i * 1.7) * blob.deformAmp;
      final double r = blob.radius + deform;

      final double x = cx + r * math.cos(baseAngle);
      final double y = cy + r * math.sin(baseAngle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final double prevAngle = (2 * math.pi * (i - 1)) / n - math.pi / 2;
        final double prevDeform = math.sin(t * blob.deformSpeed + (i - 1) * 1.7) * blob.deformAmp;
        final double prevR = blob.radius + prevDeform;
        final double prevX = cx + prevR * math.cos(prevAngle);
        final double prevY = cy + prevR * math.sin(prevAngle);

        final double cpX = (prevX + x) / 2 + math.cos(baseAngle - math.pi / 4) * r * 0.2;
        final double cpY = (prevY + y) / 2 + math.sin(baseAngle - math.pi / 4) * r * 0.2;

        path.quadraticBezierTo(cpX, cpY, x, y);
      }
    }
    path.close();

    final Paint paint = Paint()
      ..shader = RadialGradient(
        colors: [blob.color, blob.color.withValues(alpha: blob.color.a * 0.3)],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: blob.radius));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BlobPainter old) => t != old.t || scheme != old.scheme;
}

class _BlobData {
  const _BlobData({
    required this.cx,
    required this.cy,
    required this.radius,
    required this.color,
    required this.orbitR,
    required this.orbitSpeed,
    required this.deformAmp,
    required this.deformSpeed,
    required this.vertexCount,
  });

  final double cx, cy, radius;
  final Color color;
  final double orbitR, orbitSpeed;
  final double deformAmp, deformSpeed;
  final int vertexCount;
}
