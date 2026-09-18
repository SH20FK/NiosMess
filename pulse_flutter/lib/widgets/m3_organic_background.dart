import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/circular_theme_reveal.dart';

final bool _isTestEnvironment =
    !kReleaseMode && WidgetsBinding.instance.runtimeType.toString().contains('Test');

final bool _isDesktopPlatform = !_isTestEnvironment &&
    (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux);

class M3OrganicBackground extends ConsumerWidget {
  const M3OrganicBackground({
    super.key,
    required this.child,
    this.showBackButton = false,
    this.showThemeToggle = true,
    this.onBack,
  });

  final Widget child;
  final bool showBackButton;
  final bool showThemeToggle;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.paddingOf(context).top;

    final PerformanceTier tier = ref.watch(
      adaptivePerformanceProvider.select((s) => s.tier),
    );
    final bool optimize = ref.watch(
      uiSettingsProvider.select((s) => s.optimizeForWeakDevices),
    );

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          // ── Organic Geometric Blobs Background ───────────────────────
          Positioned.fill(
            child: (tier == PerformanceTier.tierC || optimize)
                ? Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          scheme.surface,
                          Color.alphaBlend(
                            scheme.primary.withValues(alpha: isDark ? 0.08 : 0.04),
                            scheme.surface,
                          ),
                          Color.alphaBlend(
                            scheme.tertiary.withValues(alpha: isDark ? 0.06 : 0.03),
                            scheme.surfaceContainerLowest,
                          ),
                        ],
                      ),
                    ),
                  )
                : RepaintBoundary(
                    child: CustomPaint(
                      painter: _OrganicBlobsPainter(
                        scheme: scheme,
                        isDark: isDark,
                        blurSigma: (tier == PerformanceTier.tierA) ? 54.0 : 16.0,
                        isTierB: tier == PerformanceTier.tierB,
                        devicePixelRatio:
                            MediaQuery.maybeDevicePixelRatioOf(context)?.clamp(1.0, 2.0) ?? 1.0,
                      ),
                    ),
                  ),
          ),

          // ── Child Content ────────────────────────────────────────────
          Positioned.fill(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool isDesktop =
                    _isDesktopPlatform && constraints.maxWidth >= 840;
                if (!isDesktop) {
                  return child;
                }
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Material(
                        color: scheme.surfaceContainerHigh
                            .withValues(alpha: isDark ? 0.92 : 0.98),
                        borderRadius: AppRadii.lgRadius,
                        elevation: 0,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            borderRadius: AppRadii.lgRadius,
                            border: Border.all(
                              color: scheme.outlineVariant
                                  .withValues(alpha: 0.35),
                              width: 1.0,
                            ),
                          ),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Top Header Actions (Back & Theme Toggle) ──────────────────
          if (showBackButton || showThemeToggle)
            Positioned(
              top: topPadding + 8,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (showBackButton)
                    _TopIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: context.l10n.commonBack,
                      scheme: scheme,
                      onTap: () {
                        HapticService.tap();
                        if (onBack != null) {
                          onBack!();
                        } else if (Navigator.canPop(context)) {
                          Navigator.of(context).pop();
                        }
                      },
                    )
                  else
                    const SizedBox(width: 44),

                  if (showThemeToggle)
                    Builder(
                      builder: (BuildContext btnContext) {
                        final ThemeMode currentMode = ref.watch(
                          uiSettingsProvider.select((s) => s.themeMode),
                        );
                        final (IconData modeIcon, ThemeMode nextMode, String tooltip) =
                            switch (currentMode) {
                          ThemeMode.system => (
                              Icons.brightness_auto_rounded,
                              ThemeMode.light,
                              context.l10n.themeModeSystem,
                            ),
                          ThemeMode.light => (
                              Icons.light_mode_rounded,
                              ThemeMode.dark,
                              context.l10n.themeModeLight,
                            ),
                          ThemeMode.dark => (
                              Icons.dark_mode_rounded,
                              ThemeMode.system,
                              context.l10n.themeModeDark,
                            ),
                        };

                        return _TopIconButton(
                          icon: modeIcon,
                          tooltip: tooltip,
                          scheme: scheme,
                          onTap: () {
                            final switcher =
                                CircularThemeSwitcher.maybeOf(btnContext);
                            if (switcher != null) {
                              final RenderBox? box = btnContext
                                  .findRenderObject() as RenderBox?;
                              final Offset? offset =
                                  box != null && box.hasSize
                                      ? box.localToGlobal(
                                          box.size.center(Offset.zero))
                                      : null;
                              switcher.toggleTheme(
                                () => ref
                                    .read(uiSettingsProvider.notifier)
                                    .setThemeMode(nextMode),
                                tapOffset: offset,
                              );
                            } else {
                              HapticService.tap();
                              ref
                                  .read(uiSettingsProvider.notifier)
                                  .setThemeMode(nextMode);
                            }
                          },
                        );
                      },
                    )
                  else
                    const SizedBox(width: 44),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({
    required this.icon,
    required this.scheme,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final ColorScheme scheme;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final radii = AppRadii.of(context);
    final Widget button = Material(
      color: scheme.surfaceContainerHigh.withValues(alpha: 0.8),
      borderRadius: AppRadii.fullRadius,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.fullRadius,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: radii.fullRadius,
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: 20,
            color: scheme.onSurface,
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: Semantics(
          button: true,
          label: tooltip,
          child: button,
        ),
      );
    }

    return Semantics(
      button: true,
      child: button,
    );
  }
}

@immutable
class _BlobsCacheKey {
  const _BlobsCacheKey({
    required this.width,
    required this.height,
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.primaryContainer,
    required this.isDark,
    required this.blurSigma,
    required this.isTierB,
    required this.devicePixelRatio,
  });

  final int width;
  final int height;
  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color primaryContainer;
  final bool isDark;
  final double blurSigma;
  final bool isTierB;
  final double devicePixelRatio;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _BlobsCacheKey &&
        other.width == width &&
        other.height == height &&
        other.primary == primary &&
        other.secondary == secondary &&
        other.tertiary == tertiary &&
        other.primaryContainer == primaryContainer &&
        other.isDark == isDark &&
        other.blurSigma == blurSigma &&
        other.isTierB == isTierB &&
        other.devicePixelRatio == devicePixelRatio;
  }

  @override
  int get hashCode => Object.hash(
        width,
        height,
        primary,
        secondary,
        tertiary,
        primaryContainer,
        isDark,
        blurSigma,
        isTierB,
        devicePixelRatio,
      );
}

class _OrganicBlobsPainter extends CustomPainter {
  const _OrganicBlobsPainter({
    required this.scheme,
    required this.isDark,
    this.blurSigma = 54.0,
    this.isTierB = false,
    this.devicePixelRatio = 1.0,
  });

  final ColorScheme scheme;
  final bool isDark;
  final double blurSigma;
  final bool isTierB;
  final double devicePixelRatio;

  static final Map<_BlobsCacheKey, ui.Image> _cache = <_BlobsCacheKey, ui.Image>{};
  static const int _maxCacheSize = 4;
  static ui.Image? _cachedImage(_BlobsCacheKey key) => _cache[key];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final int pixelWidth =
        math.max(64, (((size.width * devicePixelRatio).ceil() + 15) ~/ 16) * 16);
    final int pixelHeight =
        math.max(64, (((size.height * devicePixelRatio).ceil() + 15) ~/ 16) * 16);

    final key = _BlobsCacheKey(
      width: pixelWidth,
      height: pixelHeight,
      primary: scheme.primary,
      secondary: scheme.secondary,
      tertiary: scheme.tertiary,
      primaryContainer: scheme.primaryContainer,
      isDark: isDark,
      blurSigma: blurSigma,
      isTierB: isTierB,
      devicePixelRatio: devicePixelRatio,
    );

    final ui.Image? cached = _cachedImage(key);
    if (cached != null) {
      // Re-insert to keep LRU fresh
      _cache.remove(key);
      _cache[key] = cached;
      canvas.drawImageRect(
        cached,
        Rect.fromLTWH(0, 0, cached.width.toDouble(), cached.height.toDouble()),
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint(),
      );
      return;
    }

    final recorder = ui.PictureRecorder();
    final recordingCanvas =
        Canvas(recorder, Rect.fromLTWH(0, 0, pixelWidth.toDouble(), pixelHeight.toDouble()));
    recordingCanvas.scale(pixelWidth / size.width, pixelHeight / size.height);
    _paintBlobs(recordingCanvas, size);
    final picture = recorder.endRecording();
    final ui.Image newImage = picture.toImageSync(pixelWidth, pixelHeight);
    picture.dispose();

    if (_cache.length >= _maxCacheSize) {
      final oldestKey = _cache.keys.first;
      final oldImage = _cache.remove(oldestKey);
      oldImage?.dispose();
    }
    _cache[key] = newImage;

    canvas.drawImageRect(
      newImage,
      Rect.fromLTWH(0, 0, newImage.width.toDouble(), newImage.height.toDouble()),
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint(),
    );
  }

  void _paintBlobs(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Palette calibrated from references
    final Color blueBlob = scheme.primary.withValues(alpha: isDark ? 0.20 : 0.08);
    final Color cyanBlob = scheme.tertiary.withValues(alpha: isDark ? 0.16 : 0.07);
    final Color pinkBlob = scheme.secondary.withValues(alpha: isDark ? 0.15 : 0.06);
    final Color deepIndigo = scheme.primaryContainer.withValues(alpha: isDark ? 0.18 : 0.06);

    final maskBlur = MaskFilter.blur(BlurStyle.normal, blurSigma);

    // Top-left organic shape
    final path1 = Path()
      ..moveTo(0, 0)
      ..lineTo(w * 0.42, 0)
      ..cubicTo(w * 0.42, h * 0.12, w * 0.32, h * 0.22, w * 0.18, h * 0.22)
      ..cubicTo(w * 0.08, h * 0.22, 0, h * 0.18, 0, h * 0.14)
      ..close();
    final paint1 = Paint()
      ..color = blueBlob
      ..maskFilter = maskBlur
      ..style = PaintingStyle.fill;
    canvas.drawPath(path1, paint1);

    // Top-right soft shape
    final path2 = Path()
      ..moveTo(w * 0.65, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h * 0.28)
      ..cubicTo(w * 0.88, h * 0.28, w * 0.74, h * 0.22, w * 0.72, h * 0.12)
      ..cubicTo(w * 0.70, h * 0.04, w * 0.65, 0, w * 0.65, 0)
      ..close();
    final paint2 = Paint()
      ..color = deepIndigo
      ..maskFilter = maskBlur
      ..style = PaintingStyle.fill;
    canvas.drawPath(path2, paint2);

    // Bottom-center cyan wave
    final path5 = Path()
      ..moveTo(w * 0.22, h)
      ..cubicTo(w * 0.26, h * 0.88, w * 0.45, h * 0.86, w * 0.65, h * 0.90)
      ..cubicTo(w * 0.72, h * 0.92, w * 0.75, h, w * 0.78, h)
      ..close();
    final paint5 = Paint()
      ..color = cyanBlob
      ..maskFilter = maskBlur
      ..style = PaintingStyle.fill;
    canvas.drawPath(path5, paint5);

    if (!isTierB) {
      // Middle-right organic shape (blob)
      final path3 = Path()
        ..moveTo(w, h * 0.45)
        ..cubicTo(w * 0.78, h * 0.48, w * 0.58, h * 0.58, w * 0.62, h * 0.72)
        ..cubicTo(w * 0.65, h * 0.82, w * 0.85, h * 0.84, w, h * 0.86)
        ..close();
      final paint3 = Paint()
        ..color = blueBlob
        ..maskFilter = maskBlur
        ..style = PaintingStyle.fill;
      canvas.drawPath(path3, paint3);

      // Bottom-left pinkish shape
      final path4 = Path()
        ..moveTo(0, h * 0.62)
        ..cubicTo(w * 0.24, h * 0.62, w * 0.30, h * 0.75, w * 0.22, h * 0.86)
        ..cubicTo(w * 0.14, h * 0.94, 0, h * 0.96, 0, h * 0.96)
        ..close();
      final paint4 = Paint()
        ..color = pinkBlob
        ..maskFilter = maskBlur
        ..style = PaintingStyle.fill;
      canvas.drawPath(path4, paint4);
    }
  }

  @override
  bool shouldRepaint(_OrganicBlobsPainter oldDelegate) {
    return oldDelegate.scheme != scheme ||
        oldDelegate.isDark != isDark ||
        oldDelegate.blurSigma != blurSigma ||
        oldDelegate.isTierB != isTierB ||
        oldDelegate.devicePixelRatio != devicePixelRatio;
  }
}
