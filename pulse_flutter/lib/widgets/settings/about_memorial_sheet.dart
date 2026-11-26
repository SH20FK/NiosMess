import 'package:material_ui/material_ui.dart';
import 'package:pulse_flutter/core/modal/app_modal.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/widgets/common/touch_container.dart';

/// Easter-egg memorial sheet styled after [AppUpdateDialog], shown after
/// tapping the copyright footer six times on the About screen.
class AboutMemorialSheet extends StatelessWidget {
  const AboutMemorialSheet({super.key});

  static Future<void> show(BuildContext context) {
    return AppModal.showSheet<void>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      showDragHandle: true,
      builder: (_) => const AboutMemorialSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.nights_stay_rounded,
                    color: scheme.primary,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '???',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'R.I.P',
                            style: textTheme.labelSmall?.copyWith(
                              color: scheme.onPrimary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '???? — 2026 · 26.11',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
            child: Column(
              children: <Widget>[
                SizedBox(
                  height: 196,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _GravestonePainter(scheme: scheme),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '26.11.2026',
                  style: textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TouchContainer(
            onTap: () {
              HapticService.lightImpact();
              Navigator.of(context).pop();
            },
            borderRadius: BorderRadius.circular(14),
            color: scheme.primary,
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: Text(
                'F',
                style: textTheme.labelLarge?.copyWith(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GravestonePainter extends CustomPainter {
  const _GravestonePainter({required this.scheme});

  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double groundY = size.height - 20;

    // Soft halo behind the stone
    final Paint glowPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          scheme.primary.withValues(alpha: 0.14),
          scheme.primary.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(center: Offset(cx, groundY - 82), radius: 95),
      );
    canvas.drawCircle(Offset(cx, groundY - 82), 95, glowPaint);

    // Little stars
    final Paint starPaint = Paint()
      ..color = scheme.onSurfaceVariant.withValues(alpha: 0.35);
    for (final Offset p in <Offset>[
      Offset(cx - 88, 22),
      Offset(cx + 82, 30),
      Offset(cx - 64, 54),
      Offset(cx + 68, 66),
    ]) {
      canvas.drawCircle(p, 1.6, starPaint);
    }

    // Pedestal / base
    final RRect baseTop = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, groundY - 6), width: 138, height: 14),
      const Radius.circular(5),
    );
    final Paint basePaint = Paint()
      ..color = Color.lerp(scheme.surfaceContainerHighest, scheme.outline, 0.28)!;
    canvas.drawRRect(baseTop, basePaint);

    // Main arched gravestone body
    final double stoneW = 112;
    final double stoneLeft = cx - stoneW / 2;
    final double stoneRight = cx + stoneW / 2;
    final double archCenterY = groundY - 104;
    final double stoneBottom = groundY - 12;

    final Path stonePath = Path()
      ..moveTo(stoneLeft, stoneBottom)
      ..lineTo(stoneLeft, archCenterY)
      ..arcToPoint(
        Offset(stoneRight, archCenterY),
        radius: Radius.circular(stoneW / 2),
        clockwise: true,
      )
      ..lineTo(stoneRight, stoneBottom)
      ..close();

    final Paint stoneFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color.lerp(scheme.surfaceContainerHighest, scheme.onSurface, 0.06)!,
          Color.lerp(scheme.surfaceContainerHighest, scheme.outline, 0.22)!,
        ],
      ).createShader(Rect.fromLTRB(stoneLeft, archCenterY - stoneW / 2, stoneRight, stoneBottom));

    canvas.drawPath(stonePath, stoneFill);

    final Paint stoneBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = scheme.outline.withValues(alpha: 0.5);
    canvas.drawPath(stonePath, stoneBorder);

    // Inner engraved frame
    final Path innerPath = Path()
      ..moveTo(stoneLeft + 9, stoneBottom - 8)
      ..lineTo(stoneLeft + 9, archCenterY + 2)
      ..arcToPoint(
        Offset(stoneRight - 9, archCenterY + 2),
        radius: Radius.circular((stoneW - 18) / 2),
        clockwise: true,
      )
      ..lineTo(stoneRight - 9, stoneBottom - 8)
      ..close();
    final Paint innerStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = scheme.outline.withValues(alpha: 0.28);
    canvas.drawPath(innerPath, innerStroke);

    // Subtle stone crack
    final Path crack = Path()
      ..moveTo(stoneRight - 14, archCenterY + 14)
      ..lineTo(stoneRight - 24, archCenterY + 25)
      ..lineTo(stoneRight - 20, archCenterY + 34);
    canvas.drawPath(
      crack,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = scheme.outline.withValues(alpha: 0.4),
    );

    // Engraved text on gravestone
    _drawCenteredText(
      canvas,
      '???',
      Offset(cx, archCenterY - 22),
      TextStyle(
        color: scheme.onSurfaceVariant,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.0,
      ),
    );
    _drawCenteredText(
      canvas,
      'R.I.P',
      Offset(cx, archCenterY + 4),
      TextStyle(
        color: scheme.onSurface,
        fontSize: 22,
        fontWeight: FontWeight.w900,
        letterSpacing: 2.2,
      ),
    );
    _drawCenteredText(
      canvas,
      '???? – 2026',
      Offset(cx, archCenterY + 36),
      TextStyle(
        color: scheme.onSurfaceVariant,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
    );
    _drawCenteredText(
      canvas,
      '26.11',
      Offset(cx, archCenterY + 56),
      TextStyle(
        color: scheme.primary,
        fontSize: 12.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
      ),
    );

    // Mound / grass line
    final Paint moundPaint = Paint()
      ..color = scheme.primary.withValues(alpha: 0.18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, groundY + 4), width: 174, height: 10),
        const Radius.circular(5),
      ),
      moundPaint,
    );

    // Small candle on the left of the stone
    final double candleX = cx - 64;
    final Paint candleBody = Paint()..color = scheme.surface;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(candleX - 4, groundY - 14, 8, 14),
        const Radius.circular(2),
      ),
      candleBody,
    );
    final Paint flamePaint = Paint()..color = scheme.primary;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(candleX, groundY - 19), width: 5, height: 8),
      flamePaint,
    );
  }

  void _drawCenteredText(
    Canvas canvas,
    String text,
    Offset center,
    TextStyle style,
  ) {
    final TextPainter tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _GravestonePainter oldDelegate) =>
      oldDelegate.scheme != scheme;
}
