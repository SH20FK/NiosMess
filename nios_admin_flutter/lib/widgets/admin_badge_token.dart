import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nios_admin_flutter/models/admin_badge.dart';

class AdminBadgeToken extends StatelessWidget {
  const AdminBadgeToken({
    required this.badge,
    this.showName = false,
    super.key,
  });

  final AdminBadge badge;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color tokenColor = _parseColor(badge.color, scheme.primary);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: showName ? 10 : 6,
        vertical: showName ? 6 : 4,
      ),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          tokenColor.withValues(alpha: 0.12),
          scheme.surfaceContainerHigh,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tokenColor.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: showName ? 18 : 16,
            height: showName ? 18 : 16,
            child: CustomPaint(
              painter: _HexPainter(tokenColor),
              child: Center(
                child: Text(
                  _badgeGlyph(),
                  style: textTheme.labelSmall?.copyWith(
                    color: tokenColor,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
          if (showName) ...<Widget>[
            const SizedBox(width: 8),
            Text(
              badge.name,
              style: textTheme.labelMedium?.copyWith(
                color: tokenColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _parseColor(String raw, Color fallback) {
    try {
      final String clean = raw.replaceAll('#', '');
      return Color(int.parse('0xFF$clean'));
    } catch (_) {
      return fallback;
    }
  }

  String _badgeGlyph() {
    final String source = '${badge.name} ${badge.icon}'.toLowerCase();
    if (source.contains('verified') || source.contains('check')) return 'V';
    if (source.contains('crown') || source.contains('premium')) return 'P';
    if (source.contains('tool') || source.contains('build')) return 'T';
    if (source.contains('shield') || source.contains('admin')) return 'S';
    if (badge.icon.trim().isNotEmpty) {
      return String.fromCharCode(badge.icon.trim().runes.first).toUpperCase();
    }
    if (badge.name.trim().isNotEmpty) {
      return String.fromCharCode(badge.name.trim().runes.first).toUpperCase();
    }
    return '•';
  }
}

class _HexPainter extends CustomPainter {
  _HexPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path();
    for (int i = 0; i < 6; i++) {
      final double angle = -math.pi / 2 + (2 * math.pi * i / 6);
      final Offset point = Offset(
        size.width / 2 + size.width * 0.45 * math.cos(angle),
        size.height / 2 + size.height * 0.45 * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.14)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.84)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _HexPainter oldDelegate) =>
      oldDelegate.color != color;
}
