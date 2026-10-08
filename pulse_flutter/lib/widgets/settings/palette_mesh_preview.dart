import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

/// Uses mesh_gradient's shader and public renderer with an app-owned clock.
/// Motion uses elapsed time, respects visibility/lifecycle and pauses for
/// accessibility and power saving. Color changes blend without resetting time.
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
  static ui.FragmentProgram? _program;
  static const shaderAsset =
      'packages/mesh_gradient/shaders/animated_mesh_gradient.frag';
  late final AnimationController _colorBlend;
  late final Ticker _ticker;
  final _phase = ValueNotifier<double>(2.4);
  late List<Color> _from;
  late List<Color> _to;
  ui.FragmentShader? _shader;
  ui.Image? _fallback;
  Duration _previousElapsed = Duration.zero;
  bool _visible = true;
  bool _reducedMotion = false;
  bool _foreground = true;
  final _options = AnimatedMeshGradientOptions(
    frequency: 2,
    amplitude: 50,
    speed: 0.4,
    grain: 0,
  );

  @override
  void initState() {
    super.initState();
    assert(widget.colors.length == 4);
    _from = List.of(widget.colors);
    _to = List.of(widget.colors);
    _colorBlend = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      value: 1,
    );
    _ticker = createTicker((elapsed) {
      final delta = ((elapsed - _previousElapsed).inMicroseconds / 1000000)
          .clamp(0.0, 0.05);
      _previousElapsed = elapsed;
      _phase.value += delta * 0.5;
    });
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _fallback = _rasterize(_fallbackColors(widget.colors));
    _loadShader();
  }

  List<Color> _fallbackColors(List<Color> colors) => [
    colors[0],
    colors[1],
    colors[2],
    colors[3],
    colors[0],
    colors[1],
    colors[2],
    colors[3],
    colors[0],
  ];

  Future<void> _loadShader() async {
    try {
      final program = _program ??= await ui.FragmentProgram.fromAsset(
        shaderAsset,
      );
      if (!mounted) return;
      setState(() {
        _shader = program.fragmentShader();
        _fallback?.dispose();
        _fallback = null;
      });
      _syncMotion();
    } catch (error) {
      debugPrint(
        '[PaletteMeshPreview] SHADER_UNAVAILABLE: ${error.runtimeType}',
      );
      // The cached CPU image also covers renderers without runtime shaders.
      if (mounted) _colorBlend.value = 1;
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
      final progress = M3SpringCurves.expressiveDecel.transform(
        _colorBlend.value,
      );
      _from = List.generate(4, (i) => Color.lerp(_from[i], _to[i], progress)!);
      _to = List.of(widget.colors);
      if (_shader == null) {
        _fallback?.dispose();
        _fallback = _rasterize(_fallbackColors(widget.colors));
      }
      if (_reducedMotion || !_foreground || _shader == null) {
        _colorBlend.value = 1;
      } else {
        _colorBlend.forward(from: 0);
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
    assert(colors.length == 9);
    const width = 640;
    const height = 256;
    const columns = 64;
    const rows = 28;
    final positions = <Offset>[];
    final vertexColors = <Color>[];
    final indices = <int>[];

    double channel(double u, double v, double Function(Color) read) {
      final x = (u * 2).floor().clamp(0, 1);
      final y = (v * 2).floor().clamp(0, 1);
      final tx = u * 2 - x;
      final ty = v * 2 - y;
      final samples = <double>[];
      for (int row = y - 1; row <= y + 2; row++) {
        double at(int column) =>
            read(colors[row.clamp(0, 2) * 3 + column.clamp(0, 2)]);
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
            painter: _MeshPainter(
              shader: _shader!,
              phase: _phase,
              progress: _colorBlend,
              from: _from,
              to: _to,
              options: _options,
            ),
            child: const SizedBox.expand(),
          ),
  );
}

class _MeshPainter extends CustomPainter {
  _MeshPainter({
    required this.shader,
    required this.phase,
    required this.progress,
    required this.from,
    required this.to,
    required this.options,
  }) : super(repaint: Listenable.merge([phase, progress]));
  final ui.FragmentShader shader;
  final ValueListenable<double> phase;
  final Animation<double> progress;
  final List<Color> from;
  final List<Color> to;
  final AnimatedMeshGradientOptions options;

  @override
  void paint(Canvas canvas, Size size) {
    final t = M3SpringCurves.expressiveDecel.transform(progress.value);
    AnimatedMeshGradientPainter(
      shader: shader,
      time: phase.value,
      colors: List.generate(4, (i) => Color.lerp(from[i], to[i], t)!),
      options: options,
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _MeshPainter oldDelegate) =>
      oldDelegate.shader != shader ||
      !listEquals(oldDelegate.from, from) ||
      !listEquals(oldDelegate.to, to);
}
