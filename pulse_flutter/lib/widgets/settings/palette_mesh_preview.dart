import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:mesh/mesh.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

/// Pre-bakes O'Mesh cloud shapes once per palette. Only cached images are
/// blended during motion: no per-frame mesh tessellation, blur or saveLayer.
/// The app-owned clock respects visibility, lifecycle and reduced motion.
class PaletteMeshPreview extends StatefulWidget {
  const PaletteMeshPreview({
    required this.colors,
    this.animate = false,
    super.key,
  });
  final List<Color> colors;
  final bool animate;
  @override
  State<PaletteMeshPreview> createState() => _PaletteMeshPreviewState();
}

class _PaletteMeshPreviewState extends State<PaletteMeshPreview>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const _size = Size(640, 400);
  late final AnimationController _colorBlend;
  late final Ticker _ticker;
  final _phase = ValueNotifier<double>(2.4);
  OMeshShaderProvider? _shader;
  List<ui.Image> _frames = [];
  ui.Image? _previousPalette;
  ui.Image? _fallback;
  Duration _previousElapsed = Duration.zero;
  bool _visible = true;
  bool _reducedMotion = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    assert(widget.colors.length == 4);
    _colorBlend = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      value: 1,
    );
    _ticker = createTicker((elapsed) {
      final delta = ((elapsed - _previousElapsed).inMicroseconds / 1000000)
          .clamp(0.0, 0.05);
      _previousElapsed = elapsed;
      _phase.value += delta / 18;
    });
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _fallback = _rasterize(_fallbackColors(widget.colors));
    _loadShader();
  }

  // Spatially interleaved highlights and shadows, rather than diagonal bands.
  List<Color> _cloudColors(List<Color> colors) => [
    colors[0],
    colors[1],
    colors[0],
    colors[2],
    colors[1],
    colors[0],
    colors[1],
    colors[0],
    colors[3],
    colors[1],
    colors[2],
    colors[1],
    colors[3],
    colors[0],
    colors[2],
    colors[3],
  ];

  List<Color> _fallbackColors(List<Color> colors) => _cloudColors(colors);

  Future<void> _loadShader() async {
    OMeshShaderProvider? provider;
    try {
      provider = await OMeshShaderProvider.load();
      if (!mounted) {
        provider.dispose();
        return;
      }
      _shader = provider;
      final frames = _bakeClouds(widget.colors);
      setState(() {
        _frames = frames;
        _fallback?.dispose();
        _fallback = null;
      });
      _syncMotion();
    } catch (error) {
      provider?.dispose();
      _shader = null;
      debugPrint(
        '[PaletteMeshPreview] CLOUDS_UNAVAILABLE: ${error.runtimeType}',
      );
      if (mounted) _colorBlend.value = 1;
    }
  }

  List<ui.Image> _bakeClouds(List<Color> colors) {
    final images = <ui.Image>[];
    try {
      for (int frame = 0; frame < 3; frame++) {
        final angle = frame * math.pi * 2 / 3;
        final vertices = <OVertex>[];
        for (int row = 0; row < 4; row++) {
          for (int col = 0; col < 4; col++) {
            // Fixed outer edges cover the image; only interior clouds drift.
            final interior = row > 0 && row < 3 && col > 0 && col < 3;
            final x =
                col / 3 +
                (interior ? 0.065 * math.sin(angle + row * 1.7 + col) : 0);
            final y =
                row / 3 +
                (interior ? 0.075 * math.cos(angle + col * 1.5 + row) : 0);
            vertices.add(OVertex(x, y).bezier());
          }
        }
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        OMeshRectPaint(
          shaderProvider: _shader!,
          meshRect: OMeshRect(
            width: 4,
            height: 4,
            vertices: vertices,
            colors: _cloudColors(colors),
            colorSpace: OMeshColorSpace.lab,
          ),
          tessellation: 12,
          debugMode: null,
        ).paint(canvas, Offset.zero & _size);
        final random = math.Random(41);
        final grain = Paint()
          ..color = const Color.from(
            alpha: 0.025,
            red: 0.5,
            green: 0.5,
            blue: 0.5,
          );
        for (int i = 0; i < 5000; i++) {
          canvas.drawRect(
            Rect.fromLTWH(
              random.nextDouble() * _size.width,
              random.nextDouble() * _size.height,
              1,
              1,
            ),
            grain,
          );
        }
        final picture = recorder.endRecording();
        try {
          images.add(
            picture.toImageSync(_size.width.toInt(), _size.height.toInt()),
          );
        } finally {
          picture.dispose();
        }
      }
      return images;
    } catch (_) {
      for (final image in images) {
        image.dispose();
      }
      rethrow;
    }
  }

  ui.Image _capturePalette() {
    final recorder = ui.PictureRecorder();
    _CloudPainter.draw(
      Canvas(recorder),
      _size,
      _frames,
      _phase.value,
      _previousPalette,
      _colorBlend.value,
    );
    final picture = recorder.endRecording();
    try {
      return picture.toImageSync(_size.width.toInt(), _size.height.toInt());
    } finally {
      picture.dispose();
    }
  }

  void _syncMotion() {
    final run =
        widget.animate &&
        !_reducedMotion &&
        _visible &&
        _foreground &&
        _shader != null;
    if (run && !_ticker.isActive) {
      _previousElapsed = Duration.zero;
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
    }
    if (_reducedMotion || !_foreground) _colorBlend.value = 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.valuesOf(context).enabled;
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    _syncMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant PaletteMeshPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.colors, widget.colors)) {
      if (_shader == null) {
        final next = _rasterize(_fallbackColors(widget.colors));
        _fallback?.dispose();
        _fallback = next;
        _colorBlend.value = 1;
      } else {
        final snapshot = _capturePalette();
        try {
          final next = _bakeClouds(widget.colors);
          _previousPalette?.dispose();
          _previousPalette = snapshot;
          for (final image in _frames) {
            image.dispose();
          }
          _frames = next;
          if (_reducedMotion || !_foreground) {
            _colorBlend.value = 1;
          } else {
            _colorBlend.forward(from: 0);
          }
        } catch (_) {
          snapshot.dispose();
          rethrow;
        }
      }
    }
    _syncMotion();
  }

  static double _cubic(double a, double b, double c, double d, double t) =>
      b +
      0.5 *
          t *
          (c - a + t * (2 * a - 5 * b + 4 * c - d + t * (3 * (b - c) + d - a)));

  static ui.Image _rasterize(List<Color> colors) {
    assert(colors.length == 16);
    const width = 640;
    const height = 400;
    const columns = 64;
    const rows = 28;
    final positions = <Offset>[];
    final vertexColors = <Color>[];
    final indices = <int>[];

    double channel(double u, double v, double Function(Color) read) {
      final x = (u * 3).floor().clamp(0, 2);
      final y = (v * 3).floor().clamp(0, 2);
      final tx = u * 3 - x;
      final ty = v * 3 - y;
      final samples = <double>[];
      for (int row = y - 1; row <= y + 2; row++) {
        double at(int column) =>
            read(colors[row.clamp(0, 3) * 4 + column.clamp(0, 3)]);
        samples.add(_cubic(at(x - 1), at(x), at(x + 1), at(x + 2), tx));
      }
      return _cubic(
        samples[0],
        samples[1],
        samples[2],
        samples[3],
        ty,
      ).clamp(0.0, 1.0);
    }

    for (int row = 0; row <= rows; row++) {
      final v = row / rows;
      for (int column = 0; column <= columns; column++) {
        final u = column / columns;
        positions.add(
          Offset(
            (u + 0.10 * math.sin(math.pi * u) * math.sin(2 * math.pi * v)) *
                width,
            (v + 0.12 * math.sin(math.pi * v) * math.sin(2 * math.pi * u)) *
                height,
          ),
        );
        vertexColors.add(
          Color.from(
            alpha: 1,
            red: channel(u, v, (c) => c.r),
            green: channel(u, v, (c) => c.g),
            blue: channel(u, v, (c) => c.b),
          ),
        );
        if (row < rows && column < columns) {
          final i = row * (columns + 1) + column;
          indices.addAll([
            i,
            i + 1,
            i + columns + 1,
            i + 1,
            i + columns + 2,
            i + columns + 1,
          ]);
        }
      }
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final vertices = ui.Vertices(
      ui.VertexMode.triangles,
      positions,
      colors: vertexColors,
      indices: indices,
    );
    canvas.drawVertices(vertices, BlendMode.src, Paint());
    vertices.dispose();
    final picture = recorder.endRecording();
    final result = picture.toImageSync(width, height);
    picture.dispose();
    return result;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _colorBlend.dispose();
    _phase.dispose();
    _shader?.dispose();
    _previousPalette?.dispose();
    for (final image in _frames) {
      image.dispose();
    }
    _fallback?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: _shader == null
        ? RawImage(
            image: _fallback,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          )
        : CustomPaint(
            painter: _CloudPainter(
              frames: _frames,
              previousPalette: _previousPalette,
              phase: _phase,
              progress: _colorBlend,
            ),
            child: const SizedBox.expand(),
          ),
  );
}

class _CloudPainter extends CustomPainter {
  _CloudPainter({
    required this.frames,
    required this.previousPalette,
    required this.phase,
    required this.progress,
  }) : super(repaint: Listenable.merge([phase, progress]));
  final List<ui.Image> frames;
  final ui.Image? previousPalette;
  final ValueListenable<double> phase;
  final Animation<double> progress;

  static void draw(
    Canvas canvas,
    Size size,
    List<ui.Image> frames,
    double phase,
    ui.Image? previous,
    double progress,
  ) {
    if (frames.isEmpty) return;
    final dst = Offset.zero & size;
    void image(ui.Image image, double opacity) {
      if (opacity <= 0) return;
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        dst,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..color = Color.from(alpha: opacity, red: 1, green: 1, blue: 1),
      );
    }

    final position = phase % frames.length;
    final index = position.floor();
    final mix = (1 - math.cos((position - index) * math.pi)) / 2;
    image(frames[index], 1);
    image(frames[(index + 1) % frames.length], mix);
    // Cover the new palette with the captured old palette as it fades out.
    // Rapid selections capture the visible blend, preventing color jumps.
    if (previous != null) {
      image(previous, 1 - M3SpringCurves.expressiveDecel.transform(progress));
    }
  }

  @override
  void paint(Canvas canvas, Size size) =>
      draw(canvas, size, frames, phase.value, previousPalette, progress.value);

  @override
  bool shouldRepaint(covariant _CloudPainter oldDelegate) =>
      !identical(oldDelegate.frames, frames) ||
      oldDelegate.previousPalette != previousPalette;
}
