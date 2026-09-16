import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

/// The 10 canonical Material 3 Expressive shapes used for Nios Mark identity.
const List<Shapes> kCanonicalM3Shapes = <Shapes>[
  Shapes.c9_sided_cookie,
  Shapes.l4_leaf_clover,
  Shapes.gem,
  Shapes.burst,
  Shapes.pentagon,
  Shapes.flower,
  Shapes.sunny,
  Shapes.very_sunny,
  Shapes.slanted,
  Shapes.puffy,
];

/// Immutable value object representing a user's generative Nios Mark.
@immutable
class NiosMarkData {
  const NiosMarkData({
    required this.id,
    required this.seed,
    required this.hue,
    required this.color,
    required this.accentColor,
    required this.shape,
    required this.tiltDegrees,
    required this.monogram,
  });

  final String id;
  final int seed;
  final double hue;
  final Color color;
  final Color accentColor;
  final Shapes shape;
  final double tiltDegrees;
  final String monogram;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NiosMarkData &&
          other.id == id &&
          other.seed == seed &&
          other.color == color &&
          other.shape == shape;

  @override
  int get hashCode => Object.hash(id, seed, color, shape);
}

/// Nios Mark — Generative Brand & User Identity Engine.
///
/// Converts any user ID, chat ID, or name into a deterministic, accessible
/// identity mark with an M3 Expressive shape, HCT tonal color, monogram, and tilt.
abstract final class NiosMark {
  /// Bounded LRU cache of resolved [NiosMarkData] instances.
  static final Map<String, NiosMarkData> _markCache = <String, NiosMarkData>{};
  static const int _maxCacheSize = 256;

  /// Bounded LRU cache of avatar colors.
  static final Map<String, Color> _colorCache = <String, Color>{};

  /// Stable 32-bit FNV-1a hash algorithm across all platforms and Dart runtimes.
  static int hashString(String input) {
    var hash = 0x811c9dc5;
    for (var i = 0; i < input.length; i++) {
      hash ^= input.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    return hash;
  }

  /// Extracts clean monogram initials (1-2 characters) from a name or ID.
  static String extractMonogram(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return 'N';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      final firstChar = parts[0].characters.first;
      final secondChar = parts[1].characters.first;
      return '$firstChar$secondChar'.toUpperCase();
    }
    return trimmed.characters.take(2).toString().toUpperCase();
  }

  /// Resolves deterministic, accessible avatar color for any ID and [ColorScheme].
  ///
  /// Single source of truth across the entire app replacing fragmented legacy algorithms.
  static Color resolveColor(String id, ColorScheme scheme) {
    final bool isDark = scheme.brightness == Brightness.dark;
    final String cacheKey = '${id}_${isDark ? 1 : 0}';

    final existing = _colorCache[cacheKey];
    if (existing != null) return existing;

    final int seed = hashString(id);
    final double hue = (seed % 360).toDouble();
    // High-fidelity accessible HCT color:
    final Color color = Color(
      Hct.from(hue, 44.0, isDark ? 68.0 : 44.0).toInt(),
    );

    if (_colorCache.length >= _maxCacheSize) {
      _colorCache.remove(_colorCache.keys.first);
    }
    _colorCache[cacheKey] = color;
    return color;
  }

  /// Generates the full [NiosMarkData] identity for a user.
  static NiosMarkData generate(
    String id, {
    required Brightness brightness,
    String? name,
  }) {
    final bool isDark = brightness == Brightness.dark;
    final String cacheKey = '${id}_${isDark ? 1 : 0}_${name ?? ''}';

    final existing = _markCache[cacheKey];
    if (existing != null) return existing;

    final int seed = hashString(id);
    final double hue = (seed % 360).toDouble();

    // Primary mark color in accessible tonal range
    final Color primaryColor = Color(
      Hct.from(hue, 50.0, isDark ? 70.0 : 42.0).toInt(),
    );

    // Complementary accent color for gradients or inner badges
    final double accentHue = (hue + 45.0) % 360.0;
    final Color accentColor = Color(
      Hct.from(accentHue, 45.0, isDark ? 60.0 : 52.0).toInt(),
    );

    // Deterministic shape selection
    final int shapeIndex = ((seed >> 8) & 0xFF) % kCanonicalM3Shapes.length;
    final Shapes shape = kCanonicalM3Shapes[shapeIndex];

    // Subtle signature tilt: -10 to +10 degrees
    final int tiltRaw = (seed >> 16) & 0x1F; // 0..31
    final double tiltDegrees = ((tiltRaw - 15) / 15.0) * 10.0;

    final String monogram = extractMonogram(name ?? id);

    final mark = NiosMarkData(
      id: id,
      seed: seed,
      hue: hue,
      color: primaryColor,
      accentColor: accentColor,
      shape: shape,
      tiltDegrees: tiltDegrees,
      monogram: monogram,
    );

    if (_markCache.length >= _maxCacheSize) {
      _markCache.remove(_markCache.keys.first);
    }
    _markCache[cacheKey] = mark;
    return mark;
  }

  /// Renders a NiosMark into a high-performance [ui.Image] snapshot without UI pipeline stalls.
  static Future<ui.Image> renderToImage({
    required NiosMarkData mark,
    required double size,
    double pixelRatio = 2.0,
  }) async {
    final recorder = ui.PictureRecorder();
    final double canvasSize = size * pixelRatio;
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, canvasSize, canvasSize),
    );

    canvas.scale(pixelRatio, pixelRatio);

    // Save layer with rotation
    canvas.save();
    canvas.translate(size / 2, size / 2);
    canvas.rotate(mark.tiltDegrees * math.pi / 180);
    canvas.translate(-size / 2, -size / 2);

    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(size, size),
        [mark.color, mark.accentColor],
      )
      ..style = PaintingStyle.fill;

    // Draw background shape
    final rect = Rect.fromLTWH(0, 0, size, size);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size * 0.32));
    canvas.drawRRect(rrect, paint);

    // Draw Monogram
    final textPainter = TextPainter(
      text: TextSpan(
        text: mark.monogram,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
          fontFamily: 'Onest',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2),
    );

    canvas.restore();

    final picture = recorder.endRecording();
    final image = await picture.toImage(canvasSize.toInt(), canvasSize.toInt());
    picture.dispose();
    return image;
  }
}
