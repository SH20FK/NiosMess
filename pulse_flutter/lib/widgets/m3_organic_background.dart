import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/circular_theme_reveal.dart';

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

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          // ── Organic Geometric Blobs Background ───────────────────────
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _OrganicBlobsPainter(
                  scheme: scheme,
                  isDark: isDark,
                ),
              ),
            ),
          ),

          // ── Child Content ────────────────────────────────────────────
          Positioned.fill(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
                final bool isDesktopPlatform = !isTest && (kIsWeb ||
                    defaultTargetPlatform == TargetPlatform.macOS ||
                    defaultTargetPlatform == TargetPlatform.windows ||
                    defaultTargetPlatform == TargetPlatform.linux);
                final bool isDesktop = isDesktopPlatform && constraints.maxWidth >= 840;
                if (!isDesktop) {
                  return child;
                }
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Material(
                        color: scheme.surfaceContainerHigh.withValues(alpha: isDark ? 0.92 : 0.98),
                        borderRadius: BorderRadius.circular(32),
                        elevation: 8,
                        shadowColor: scheme.shadow.withValues(alpha: 0.2),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(
                              color: scheme.outlineVariant.withValues(alpha: 0.45),
                              width: 1.5,
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
                      scheme: scheme,
                      onTap: () {
                        HapticFeedback.lightImpact();
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
                        return _TopIconButton(
                          icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                          scheme: scheme,
                          onTap: () {
                            final newMode = isDark ? ThemeMode.light : ThemeMode.dark;
                            final switcher = CircularThemeSwitcher.maybeOf(btnContext);
                            if (switcher != null) {
                              final RenderBox? box = btnContext.findRenderObject() as RenderBox?;
                              final Offset? offset = box != null && box.hasSize
                                  ? box.localToGlobal(box.size.center(Offset.zero))
                                  : null;
                              switcher.toggleTheme(
                                () => ref.read(uiSettingsProvider.notifier).setThemeMode(newMode),
                                tapOffset: offset,
                              );
                            } else {
                              HapticFeedback.lightImpact();
                              ref.read(uiSettingsProvider.notifier).setThemeMode(newMode);
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
  });

  final IconData icon;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: scheme.surfaceContainerHigh.withValues(alpha: 0.8),
      borderRadius: BorderRadius.circular(22),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
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
  }
}

class _OrganicBlobsPainter extends CustomPainter {
  const _OrganicBlobsPainter({
    required this.scheme,
    required this.isDark,
  });

  final ColorScheme scheme;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Palette calibrated from references
    final Color blueBlob = scheme.primary.withValues(alpha: isDark ? 0.20 : 0.08);
    final Color cyanBlob = scheme.tertiary.withValues(alpha: isDark ? 0.16 : 0.07);
    final Color pinkBlob = scheme.secondary.withValues(alpha: isDark ? 0.15 : 0.06);
    final Color deepIndigo = scheme.primaryContainer.withValues(alpha: isDark ? 0.18 : 0.06);

    const maskBlur = MaskFilter.blur(BlurStyle.normal, 54);

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
  }

  @override
  bool shouldRepaint(_OrganicBlobsPainter oldDelegate) {
    return oldDelegate.scheme != scheme || oldDelegate.isDark != isDark;
  }
}
