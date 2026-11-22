import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pulse_flutter/core/motion/m3_motion.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';

/// Optimized Animated Theme Toggler wrapper.
/// Smoothly reveals the new theme via an expanding circular cutout from tap coordinates
/// using a snapshot capped at a 2.0 pixel ratio with hardware-accelerated rendering.
class CircularThemeSwitcher extends StatefulWidget {
  const CircularThemeSwitcher({super.key, required this.child});

  final Widget child;

  /// True while a reveal covers the screen. The snapshot of the old theme
  /// carries the transition, so anything that animates theme changes should
  /// switch at once while this is set.
  static final ValueNotifier<bool> revealing = ValueNotifier<bool>(false);

  static CircularThemeSwitcherState of(BuildContext context) {
    final state = context.findAncestorStateOfType<CircularThemeSwitcherState>();
    assert(
      state != null,
      'No CircularThemeSwitcher found in widget tree context',
    );
    return state!;
  }

  static CircularThemeSwitcherState? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<CircularThemeSwitcherState>();
  }

  @override
  State<CircularThemeSwitcher> createState() => CircularThemeSwitcherState();
}

class CircularThemeSwitcherState extends State<CircularThemeSwitcher>
    with SingleTickerProviderStateMixin {
  final GlobalKey _repaintKey = GlobalKey();
  late AnimationController _animController;
  ui.Image? _oldImage;
  Offset _tapOffset = Offset.zero;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: M3Durations.long1,
    );
    _animController.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        CircularThemeSwitcher.revealing.value = false;
        if (mounted) {
          setState(() {
            _isAnimating = false;
            _oldImage?.dispose();
            _oldImage = null;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    if (_isAnimating) {
      // Listeners rebuild, which is not allowed while the tree is locked.
      scheduleMicrotask(() => CircularThemeSwitcher.revealing.value = false);
    }
    _animController.dispose();
    _oldImage?.dispose();
    super.dispose();
  }

  /// Triggers theme toggle with circular reveal animation from tap position or button key.
  Future<void> toggleTheme(
    VoidCallback changeThemeCallback, {
    Offset? tapOffset,
    GlobalKey? buttonKey,
    bool haptic = true,
  }) async {
    if (_isAnimating) return;
    if (context.reduceMotion) {
      changeThemeCallback();
      return;
    }

    Offset offset = tapOffset ?? Offset.zero;
    if (buttonKey != null && buttonKey.currentContext != null) {
      final RenderBox? box =
          buttonKey.currentContext!.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        offset = box.localToGlobal(box.size.center(Offset.zero));
      }
    }

    final Size size = MediaQuery.of(context).size;
    if (offset == Offset.zero) {
      offset = Offset(size.width / 2, size.height / 2);
    }

    // 1. Capture a snapshot of the OLD theme before the change. The pixel
    // ratio is capped at 2.0: at 1.0 the old theme visibly blurs for the
    // length of the reveal, above 2.0 the texture only costs memory.
    ui.Image? snapshotImage;
    try {
      final RenderRepaintBoundary? boundary =
          _repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary != null && boundary.attached && boundary.hasSize) {
        // Synchronous GPU texture capture to prevent pipeline stalls and per-frame CPU rasterization (ЛАГ-12)
        snapshotImage = boundary.toImageSync(
          pixelRatio: MediaQuery.devicePixelRatioOf(
            context,
          ).clamp(1.0, 2.0).toDouble(),
        );
      }
    } catch (_) {
      snapshotImage = null;
    }

    _oldImage = snapshotImage;
    _tapOffset = offset;
    // Without a snapshot there is no reveal and the theme animates as usual.
    if (snapshotImage != null) CircularThemeSwitcher.revealing.value = true;

    // A control that already answered the touch itself asks for silence.
    if (haptic) {
      try {
        HapticService.lightImpact();
      } catch (_) {}
    }

    // 2. Change theme state
    changeThemeCallback();

    // 3. Run circular expansion reveal
    if (_oldImage != null && mounted) {
      setState(() {
        _isAnimating = true;
      });
      _animController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _repaintKey,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (_isAnimating && _oldImage != null)
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _animController,
                    builder: (BuildContext context, Widget? child) {
                      final double progress = M3SpringCurves.expressiveDecel
                          .transform(_animController.value);

                      return CustomPaint(
                        size: Size.infinite,
                        painter: _CircularRevealPainter(
                          image: _oldImage!,
                          center: _tapOffset,
                          progress: progress,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CircularRevealPainter extends CustomPainter {
  _CircularRevealPainter({
    required this.image,
    required this.center,
    required this.progress,
  });

  final ui.Image image;
  final Offset center;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final double clampedProgress = progress.clamp(0.0, 1.0);
    if (clampedProgress >= 1.0) return;

    final double maxRadius = _calcMaxRadius(center, size);
    final double holeRadius = maxRadius * clampedProgress;

    canvas.save();

    final Path path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    if (holeRadius > 0) {
      path.addOval(Rect.fromCircle(center: center, radius: holeRadius));
    }
    path.fillType = PathFillType.evenOdd;

    canvas.clipPath(path);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..filterQuality = ui.FilterQuality.medium,
    );
    canvas.restore();
  }

  double _calcMaxRadius(Offset center, Size size) {
    final double w = size.width;
    final double h = size.height;

    final double d1 = (const Offset(0, 0) - center).distance;
    final double d2 = (Offset(w, 0) - center).distance;
    final double d3 = (Offset(0, h) - center).distance;
    final double d4 = (Offset(w, h) - center).distance;

    double maxD = d1;
    if (d2 > maxD) maxD = d2;
    if (d3 > maxD) maxD = d3;
    if (d4 > maxD) maxD = d4;
    return maxD;
  }

  @override
  bool shouldRepaint(_CircularRevealPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.center != center;
  }
}
