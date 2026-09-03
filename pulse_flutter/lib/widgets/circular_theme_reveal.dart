import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Telegram / MagicUI Animated Theme Toggler wrapper.
/// Captures the current theme as a bitmap snapshot and smoothly reveals the new theme
/// via an expanding circular cutout originating from the tap gesture coordinates.
class CircularThemeSwitcher extends StatefulWidget {
  const CircularThemeSwitcher({
    super.key,
    required this.child,
  });

  final Widget child;

  static CircularThemeSwitcherState of(BuildContext context) {
    final state = context.findAncestorStateOfType<CircularThemeSwitcherState>();
    assert(state != null, 'No CircularThemeSwitcher found in widget tree context');
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
      duration: const Duration(milliseconds: 480),
    );
    _animController.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isAnimating = false;
          _oldImage?.dispose();
          _oldImage = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _oldImage?.dispose();
    super.dispose();
  }

  /// Triggers theme toggle with circular reveal animation from tap position or key.
  Future<void> toggleTheme(
    VoidCallback changeThemeCallback, {
    Offset? tapOffset,
    GlobalKey? buttonKey,
  }) async {
    if (_isAnimating) return;

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

    // 1. Capture snapshot of OLD theme BEFORE state change
    ui.Image? snapshotImage;
    try {
      final RenderRepaintBoundary? boundary =
          _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null && boundary.attached && boundary.hasSize) {
        final double pixelRatio = MediaQuery.of(context).devicePixelRatio;
        snapshotImage = await boundary.toImage(pixelRatio: pixelRatio);
      }
    } catch (_) {
      snapshotImage = null;
    }

    // 2. Save snapshot & tap position
    _oldImage = snapshotImage;
    _tapOffset = offset;

    // 3. NOW update theme state (rebuilds underlying widget tree in new theme)
    HapticFeedback.mediumImpact();
    changeThemeCallback();

    // 4. Start expanding circular reveal animation
    if (_oldImage != null) {
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
            AnimatedBuilder(
              animation: _animController,
              builder: (BuildContext context, Widget? child) {
                final double progress = CurvedAnimation(
                  parent: _animController,
                  curve: Curves.fastOutSlowIn,
                ).value;

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
    if (progress >= 1.0) return;

    final double maxRadius = _calcMaxRadius(center, size);
    final double holeRadius = maxRadius * progress;

    canvas.save();

    // Path fillType evenOdd: Entire screen rectangle minus expanding circle hole at tap center
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
