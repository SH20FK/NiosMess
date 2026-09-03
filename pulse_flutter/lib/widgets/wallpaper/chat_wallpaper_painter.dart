import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import 'package:pulse_flutter/models/chat_wallpaper_config.dart';
import 'package:pulse_flutter/widgets/wallpaper/material_symbols_data.dart';
import 'package:pulse_flutter/widgets/wallpaper/wallpaper_color_resolver.dart';

const List<Shapes> _kAllM3Shapes = <Shapes>[
  Shapes.gem,
  Shapes.c9_sided_cookie,
  Shapes.l4_leaf_clover,
  Shapes.burst,
  Shapes.pentagon,
  Shapes.slanted,
  Shapes.very_sunny,
  Shapes.sunny,
  Shapes.flower,
  Shapes.puffy,
];

class ChatWallpaperPainter extends CustomPainter {
  ChatWallpaperPainter({
    required this.config,
    required this.scheme,
    this.svgPicture,
    this.paletteSvgPictures,
    this.poolSvgPictures,
  });

  final ChatWallpaperConfig config;
  final ColorScheme scheme;
  final ui.Picture? svgPicture;
  final Map<String, ui.Picture>? paletteSvgPictures;
  final List<ui.Picture>? poolSvgPictures;

  @override
  void paint(Canvas canvas, Size size) {
    paintToCanvas(
      canvas: canvas,
      size: size,
      config: config,
      scheme: scheme,
      svgPicture: svgPicture,
      paletteSvgPictures: paletteSvgPictures,
      poolSvgPictures: poolSvgPictures,
    );
  }

  static void paintToCanvas({
    required Canvas canvas,
    required Size size,
    required ChatWallpaperConfig config,
    required ColorScheme scheme,
    ui.Picture? svgPicture,
    Map<String, ui.Picture>? paletteSvgPictures,
    List<ui.Picture>? poolSvgPictures,
  }) {
    if (size.width <= 0 || size.height <= 0) return;

    // 1. Paint background
    final Color bgColor = WallpaperColorResolver.resolveBackground(
      scheme,
      config.backgroundRole,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = bgColor,
    );

    // 2. Setup seeded random and positioning bounds
    final Random rng = Random(config.seed);
    final double cellSize = config.cellSize.clamp(20.0, 240.0);
    final double iconBaseSize = cellSize * 0.44;

    // Cache shapes if M3Shape is selected
    Shapes? m3Shape;
    if (config.iconSource == IconSource.niosMess && config.m3ShapeName != null && !config.useAllIcons) {
      m3Shape = _resolveM3Shape(config.m3ShapeName!);
    }

    // Material Symbols Font Family
    final String fontFamily = _resolveFontFamily(config.symbolsStyle);

    // Resolve base colors
    final Color singleColor = WallpaperColorResolver.resolveIconColor(
      scheme,
      config.iconColorRole,
      config.iconAlpha,
    );

    // Spiral layout
    if (config.layoutMode == WallpaperLayoutMode.spiral) {
      _paintSpiral(
        canvas: canvas,
        size: size,
        config: config,
        scheme: scheme,
        rng: rng,
        cellSize: cellSize,
        iconBaseSize: iconBaseSize,
        singleColor: singleColor,
        fontFamily: fontFamily,
        m3Shape: m3Shape,
        svgPicture: svgPicture,
        paletteSvgPictures: paletteSvgPictures,
        poolSvgPictures: poolSvgPictures,
      );
      return;
    }

    // Grid, Stagger, Scatter, Hex using rotated/expanded bounds
    final double rad = config.gridAngle * pi / 180.0;
    final bool hasRotation = config.gridAngle.abs() > 0.01;

    final double diagonal = sqrt(size.width * size.width + size.height * size.height);
    final double cx = size.width / 2.0;
    final double cy = size.height / 2.0;

    canvas.save();
    if (hasRotation) {
      canvas.translate(cx, cy);
      canvas.rotate(rad);
      canvas.translate(-cx, -cy);
    }

    final double startX = (size.width - diagonal) / 2.0 - cellSize;
    final double endX = startX + diagonal + cellSize * 2;
    final double startY = (size.height - diagonal) / 2.0 - cellSize;
    final double endY = startY + diagonal + cellSize * 2;

    int rowIndex = 0;
    double currentY = startY;

    final double rowHeight = config.layoutMode == WallpaperLayoutMode.hex
        ? cellSize * 0.8660254 // sqrt(3)/2
        : cellSize;

    while (currentY <= endY) {
      double currentX = startX;

      // Stagger offset calculation
      double xOffset = 0.0;
      if (config.layoutMode == WallpaperLayoutMode.stagger ||
          config.layoutMode == WallpaperLayoutMode.hex) {
        if (config.staggerByRow && (rowIndex % 2 == 1)) {
          xOffset = cellSize * 0.5;
        }
      }

      while (currentX <= endX) {
        double posX = currentX + xOffset;
        double posY = currentY;

        // Apply scatter jitter
        if (config.layoutMode == WallpaperLayoutMode.scatter) {
          final double jitterX = (rng.nextDouble() - 0.5) * cellSize * 0.55;
          final double jitterY = (rng.nextDouble() - 0.5) * cellSize * 0.55;
          posX += jitterX;
          posY += jitterY;
        }

        // Density check
        if (rng.nextDouble() <= config.density) {
          _drawSingleIcon(
            canvas: canvas,
            x: posX,
            y: posY,
            config: config,
            scheme: scheme,
            rng: rng,
            iconBaseSize: iconBaseSize,
            singleColor: singleColor,
            fontFamily: fontFamily,
            m3Shape: m3Shape,
            svgPicture: svgPicture,
            paletteSvgPictures: paletteSvgPictures,
            poolSvgPictures: poolSvgPictures,
          );
        }

        currentX += cellSize;
      }

      currentY += rowHeight;
      rowIndex++;
    }

    canvas.restore();
  }

  static void _paintSpiral({
    required Canvas canvas,
    required Size size,
    required ChatWallpaperConfig config,
    required ColorScheme scheme,
    required Random rng,
    required double cellSize,
    required double iconBaseSize,
    required Color singleColor,
    required String fontFamily,
    Shapes? m3Shape,
    ui.Picture? svgPicture,
    Map<String, ui.Picture>? paletteSvgPictures,
    List<ui.Picture>? poolSvgPictures,
  }) {
    final double cx = size.width / 2.0;
    final double cy = size.height / 2.0;
    final double maxRadius = sqrt(cx * cx + cy * cy) + cellSize;

    double theta = 0.0;
    double r = cellSize * 0.5;
    final double b = cellSize / (2 * pi);

    while (r <= maxRadius) {
      final double posX = cx + r * cos(theta);
      final double posY = cy + r * sin(theta);

      if (rng.nextDouble() <= config.density) {
        _drawSingleIcon(
          canvas: canvas,
          x: posX,
          y: posY,
          config: config,
          scheme: scheme,
          rng: rng,
          iconBaseSize: iconBaseSize,
          singleColor: singleColor,
          fontFamily: fontFamily,
          m3Shape: m3Shape,
          svgPicture: svgPicture,
          paletteSvgPictures: paletteSvgPictures,
          poolSvgPictures: poolSvgPictures,
        );
      }

      final double step = cellSize / max(r, cellSize * 0.5);
      theta += step;
      r = b * theta + cellSize * 0.5;
    }
  }

  static void _drawSingleIcon({
    required Canvas canvas,
    required double x,
    required double y,
    required ChatWallpaperConfig config,
    required ColorScheme scheme,
    required Random rng,
    required double iconBaseSize,
    required Color singleColor,
    required String fontFamily,
    Shapes? m3Shape,
    ui.Picture? svgPicture,
    Map<String, ui.Picture>? paletteSvgPictures,
    List<ui.Picture>? poolSvgPictures,
  }) {
    // Scale and rotation jitter
    final double scaleJitter = 1.0 + (rng.nextDouble() * 2.0 - 1.0) * config.randomScaleJitter;
    final double scale = (scaleJitter).clamp(0.3, 2.2);
    final double currentSize = iconBaseSize * scale;

    final double rotationJitterDeg = (rng.nextDouble() * 2.0 - 1.0) * config.randomRotationDeg;
    final double rotationRad = rotationJitterDeg * pi / 180.0;

    // Resolve color based on colorMode
    Color iconColor = singleColor;
    String selectedRole = config.iconColorRole;
    if (config.colorMode == WallpaperColorMode.palette && config.paletteRoles.isNotEmpty) {
      selectedRole = config.paletteRoles[rng.nextInt(config.paletteRoles.length)];
      iconColor = WallpaperColorResolver.resolveIconColor(
        scheme,
        selectedRole,
        config.iconAlpha,
      );
    } else if (config.colorMode == WallpaperColorMode.tonalAccent) {
      final bool pickPrimary = rng.nextBool();
      selectedRole = pickPrimary ? 'primary' : 'tertiary';
      iconColor = WallpaperColorResolver.resolveIconColor(
        scheme,
        selectedRole,
        config.iconAlpha,
      );
    }

    canvas.save();
    canvas.translate(x, y);
    if (rotationRad.abs() > 0.001) {
      canvas.rotate(rotationRad);
    }

    // Determine shape/icon to draw
    if (config.iconSource == IconSource.niosMess) {
      Shapes shapeToDraw = m3Shape ?? Shapes.gem;
      if (config.useAllIcons) {
        shapeToDraw = _kAllM3Shapes[rng.nextInt(_kAllM3Shapes.length)];
      }

      final Path path = M3Clipper(shapeToDraw).getClip(Size(currentSize, currentSize));
      final Paint paint = Paint()
        ..color = iconColor
        ..style = config.filled ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = max(1.2, currentSize * 0.075);

      canvas.save();
      canvas.translate(-currentSize / 2.0, -currentSize / 2.0);
      canvas.drawPath(path, paint);
      canvas.restore();
    } else if (config.iconSource == IconSource.lucide || config.iconSource == IconSource.tabler) {
      ui.Picture? picToDraw;
      if (config.useAllIcons && poolSvgPictures != null && poolSvgPictures.isNotEmpty) {
        picToDraw = poolSvgPictures[rng.nextInt(poolSvgPictures.length)];
      } else {
        picToDraw = paletteSvgPictures?[selectedRole] ?? svgPicture;
      }

      if (picToDraw != null) {
        canvas.save();
        final double svgScale = currentSize / 24.0;
        canvas.scale(svgScale, svgScale);
        canvas.translate(-12.0, -12.0);
        canvas.drawPicture(picToDraw);
        canvas.restore();
      }
    } else {
      // Material Symbols (all icons mode vs single icon)
      int code = config.glyphCodepoint;
      if (config.useAllIcons && MaterialSymbolsData.allCodepoints.isNotEmpty) {
        code = MaterialSymbolsData.allCodepoints[rng.nextInt(MaterialSymbolsData.allCodepoints.length)];
      }

      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(code),
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: currentSize,
            color: iconColor,
            fontVariations: <ui.FontVariation>[
              ui.FontVariation('FILL', config.filled ? 1.0 : 0.0),
              ui.FontVariation('wght', config.weight.clamp(100.0, 700.0)),
              const ui.FontVariation('GRAD', 0.0),
              const ui.FontVariation('opsz', 24.0),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2.0, -textPainter.height / 2.0),
      );
    }

    canvas.restore();
  }

  static String _resolveFontFamily(MaterialSymbolsStyle style) {
    switch (style) {
      case MaterialSymbolsStyle.outlined:
        return 'MaterialSymbolsOutlined';
      case MaterialSymbolsStyle.rounded:
        return 'MaterialSymbolsRounded';
      case MaterialSymbolsStyle.sharp:
        return 'MaterialSymbolsSharp';
    }
  }

  static Shapes _resolveM3Shape(String shapeName) {
    switch (shapeName.toLowerCase()) {
      case 'm3_gem':
      case 'gem':
        return Shapes.gem;
      case 'm3_cookie':
      case 'cookie':
        return Shapes.c9_sided_cookie;
      case 'm3_clover':
      case 'clover':
        return Shapes.l4_leaf_clover;
      case 'm3_burst':
      case 'burst':
        return Shapes.burst;
      case 'm3_pentagon':
      case 'pentagon':
        return Shapes.pentagon;
      case 'm3_slanted':
      case 'slanted':
        return Shapes.slanted;
      default:
        return Shapes.gem;
    }
  }

  @override
  bool shouldRepaint(ChatWallpaperPainter oldDelegate) {
    return oldDelegate.config != config ||
        oldDelegate.scheme != scheme ||
        oldDelegate.svgPicture != svgPicture;
  }
}
