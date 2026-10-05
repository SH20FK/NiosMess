import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';
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

class _PulseBackdrop extends ConsumerWidget {
  const _PulseBackdrop({required this.animated});

  final bool animated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
            return const SizedBox.shrink();
          }

          return CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _BackdropPainter(
              t: 0.5,
              scheme: scheme,
              brightness: brightness,
              isWeakDevice: isWeak,
            ),
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
    canvas.drawRect(Offset.zero & size, Paint()..color = scheme.surface);
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter oldDelegate) {
    return scheme.surface != oldDelegate.scheme.surface;
  }
}
