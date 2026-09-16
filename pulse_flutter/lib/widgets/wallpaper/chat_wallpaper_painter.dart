import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import 'package:pulse_flutter/models/chat_wallpaper_config.dart';
import 'package:pulse_flutter/widgets/wallpaper/cupertino_icons_data.dart';
import 'package:pulse_flutter/widgets/wallpaper/icon_sources_catalog.dart';
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

  PainterGlyphCache? _cachedGlyphCache;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final double cellSize = config.cellSize.clamp(20.0, 240.0);
    final double iconBaseSize = cellSize * 0.44;
    final List<String> activeRoles = resolveActiveRoles(config);
    final Map<String, Color> resolvedColors = <String, Color>{
      for (final String role in activeRoles)
        role: WallpaperColorResolver.resolveIconColor(
          scheme,
          role,
          config.iconAlpha,
        ),
    };

    _cachedGlyphCache ??= _buildGlyphCache(
      config: config,
      scheme: scheme,
      iconBaseSize: iconBaseSize,
      activeRoles: activeRoles,
      resolvedColors: resolvedColors,
      svgPicture: svgPicture,
      paletteSvgPictures: paletteSvgPictures,
      poolSvgPictures: poolSvgPictures,
    );

    paintToCanvas(
      canvas: canvas,
      size: size,
      config: config,
      scheme: scheme,
      svgPicture: svgPicture,
      paletteSvgPictures: paletteSvgPictures,
      poolSvgPictures: poolSvgPictures,
      precomputedCache: _cachedGlyphCache,
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
    PainterGlyphCache? precomputedCache,
  }) {
    if (size.width <= 0 || size.height <= 0) return;

    // 1. Paint background
    if (config.backgroundStyle == WallpaperBackgroundStyle.linearGradient) {
      final Paint bgPaint = Paint()
        ..shader = WallpaperColorResolver.createLinearGradientShader(
          scheme: scheme,
          role1: config.backgroundRole,
          role2: config.backgroundSecondaryRole,
          angleDeg: config.gradientAngle,
          size: size,
        );
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        bgPaint,
      );
    } else if (config.backgroundStyle == WallpaperBackgroundStyle.radialGlow) {
      final Paint bgPaint = Paint()
        ..shader = WallpaperColorResolver.createRadialGlowShader(
          scheme: scheme,
          centerRole: config.backgroundRole,
          outerRole: config.backgroundSecondaryRole,
          size: size,
        );
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        bgPaint,
      );
    } else {
      final Color bgColor = WallpaperColorResolver.resolveBackground(
        scheme,
        config.backgroundRole,
      );
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = bgColor,
      );
    }

    // 2. Setup seeded random and positioning bounds
    final Random rng = Random(config.seed);
    final double cellSize = config.cellSize.clamp(20.0, 240.0);
    final double iconBaseSize = cellSize * 0.44;

    // 3. Resolve active color roles and colors
    final List<String> activeRoles = resolveActiveRoles(config);
    final Map<String, Color> resolvedColors = <String, Color>{};
    for (final String role in activeRoles) {
      resolvedColors[role] = WallpaperColorResolver.resolveIconColor(
        scheme,
        role,
        config.iconAlpha,
      );
    }

    // 4. PRE-COMPUTED GLYPH CACHE (0 UI Layout Overhead in tight loop)
    final PainterGlyphCache cache = precomputedCache ??
        _buildGlyphCache(
          config: config,
          scheme: scheme,
          iconBaseSize: iconBaseSize,
          activeRoles: activeRoles,
          resolvedColors: resolvedColors,
          svgPicture: svgPicture,
          paletteSvgPictures: paletteSvgPictures,
          poolSvgPictures: poolSvgPictures,
        );

    final double cx = size.width / 2.0;
    final double cy = size.height / 2.0;

    // 5. Render selected layout mode
    if (config.layoutMode == WallpaperLayoutMode.spiral) {
      canvas.save();
      if (config.gridAngle.abs() > 0.01) {
        final double rad = config.gridAngle * pi / 180.0;
        canvas.translate(cx, cy);
        canvas.rotate(rad);
        canvas.translate(-cx, -cy);
      }
      _paintPhyllotaxisSpiral(
        canvas: canvas,
        size: size,
        config: config,
        rng: rng,
        cellSize: cellSize,
        iconBaseSize: iconBaseSize,
        cache: cache,
      );
      canvas.restore();
      return;
    }

    // 2D Lattices (Grid, Stagger, Hex, Scatter) with center-stable rotation & tight bounds
    final double boundWidth;
    final double boundHeight;
    if (config.gridAngle.abs() < 0.01) {
      boundWidth = size.width + cellSize * 2.0;
      boundHeight = size.height + cellSize * 2.0;
    } else {
      final double rad = config.gridAngle.abs() * pi / 180.0;
      final double cosA = cos(rad).abs();
      final double sinA = sin(rad).abs();
      boundWidth = (size.width * cosA + size.height * sinA) + cellSize * 2.0;
      boundHeight = (size.width * sinA + size.height * cosA) + cellSize * 2.0;
    }
    final double diagonal = max(boundWidth, boundHeight);

    canvas.save();
    if (config.gridAngle.abs() > 0.01) {
      final double rad = config.gridAngle * pi / 180.0;
      canvas.translate(cx, cy);
      canvas.rotate(rad);
      canvas.translate(-cx, -cy);
    }

    if (config.layoutMode == WallpaperLayoutMode.hex) {
      _paintHexagonal(
        canvas: canvas,
        cx: cx,
        cy: cy,
        diagonal: diagonal,
        cellSize: cellSize,
        config: config,
        rng: rng,
        iconBaseSize: iconBaseSize,
        cache: cache,
      );
    } else if (config.layoutMode == WallpaperLayoutMode.scatter) {
      _paintScatter(
        canvas: canvas,
        cx: cx,
        cy: cy,
        diagonal: diagonal,
        cellSize: cellSize,
        config: config,
        rng: rng,
        iconBaseSize: iconBaseSize,
        cache: cache,
      );
    } else if (config.layoutMode == WallpaperLayoutMode.stagger) {
      _paintStagger(
        canvas: canvas,
        cx: cx,
        cy: cy,
        diagonal: diagonal,
        cellSize: cellSize,
        config: config,
        rng: rng,
        iconBaseSize: iconBaseSize,
        cache: cache,
      );
    } else {
      _paintGrid(
        canvas: canvas,
        cx: cx,
        cy: cy,
        diagonal: diagonal,
        cellSize: cellSize,
        config: config,
        rng: rng,
        iconBaseSize: iconBaseSize,
        cache: cache,
      );
    }

    canvas.restore();
  }

  // ── 60° Hexagonal Triangular Lattice ──────────────────────────────────────
  static void _paintHexagonal({
    required Canvas canvas,
    required double cx,
    required double cy,
    required double diagonal,
    required double cellSize,
    required ChatWallpaperConfig config,
    required Random rng,
    required double iconBaseSize,
    required PainterGlyphCache cache,
  }) {
    final double D = cellSize;
    final double H = D * 0.8660254037844386; // sqrt(3)/2 = ~0.866

    final int countX = (diagonal / D).ceil() + 2;
    final int countY = (diagonal / H).ceil() + 2;
    final double startX = cx - (countX * D) / 2.0;
    final double startY = cy - (countY * H) / 2.0;
    final double endX = cx + (countX * D) / 2.0;
    final double endY = cy + (countY * H) / 2.0;

    int row = 0;
    for (double y = startY; y <= endY; y += H, row++) {
      final double rowOffset = (row % 2 == 1) ? (D * 0.5) : 0.0;
      for (double x = startX + rowOffset; x <= endX; x += D) {
        if (rng.nextDouble() <= config.density) {
          _drawSingleIcon(
            canvas: canvas,
            x: x,
            y: y,
            config: config,
            rng: rng,
            iconBaseSize: iconBaseSize,
            cache: cache,
          );
        }
      }
    }
  }

  // ── Fermat / Vogel Phyllotaxis Spiral (Sunflower seeds pattern) ───────────
  static void _paintPhyllotaxisSpiral({
    required Canvas canvas,
    required Size size,
    required ChatWallpaperConfig config,
    required Random rng,
    required double cellSize,
    required double iconBaseSize,
    required PainterGlyphCache cache,
  }) {
    final double cx = size.width / 2.0;
    final double cy = size.height / 2.0;
    final double maxRadius = sqrt(cx * cx + cy * cy) + cellSize * 1.5;

    // Golden Angle in radians: 137.507764° = 2.39996323 rad
    const double goldenAngle = 2.399963229728653;
    final double c = cellSize * 0.65;
    final double r0 = cellSize * 0.80; // Clear open center

    int n = 0;
    while (n < 2500) {
      final double r = c * sqrt(n) + r0;
      if (r > maxRadius) break;

      final double theta = n * goldenAngle;
      final double posX = cx + r * cos(theta);
      final double posY = cy + r * sin(theta);

      if (rng.nextDouble() <= config.density) {
        _drawSingleIcon(
          canvas: canvas,
          x: posX,
          y: posY,
          config: config,
          rng: rng,
          iconBaseSize: iconBaseSize,
          cache: cache,
        );
      }
      n++;
    }
  }

  // ── Collision-Protected Organic Scatter ────────────────────────────────────
  static void _paintScatter({
    required Canvas canvas,
    required double cx,
    required double cy,
    required double diagonal,
    required double cellSize,
    required ChatWallpaperConfig config,
    required Random rng,
    required double iconBaseSize,
    required PainterGlyphCache cache,
  }) {
    final double D = cellSize;
    final int countX = (diagonal / D).ceil() + 2;
    final int countY = (diagonal / D).ceil() + 2;
    final double startX = cx - (countX * D) / 2.0;
    final double startY = cy - (countY * D) / 2.0;
    final double endX = cx + (countX * D) / 2.0;
    final double endY = cy + (countY * D) / 2.0;

    // Jitter is strictly bounded by 0.32 D to guarantee minimum distance > 0.36 D
    final double maxJitter = D * 0.32;

    for (double y = startY; y <= endY; y += D) {
      for (double x = startX; x <= endX; x += D) {
        if (rng.nextDouble() <= config.density) {
          final double jx = (rng.nextDouble() * 2.0 - 1.0) * maxJitter;
          final double jy = (rng.nextDouble() * 2.0 - 1.0) * maxJitter;
          _drawSingleIcon(
            canvas: canvas,
            x: x + jx,
            y: y + jy,
            config: config,
            rng: rng,
            iconBaseSize: iconBaseSize,
            cache: cache,
          );
        }
      }
    }
  }

  // ── Stagger (Шахматы) ──────────────────────────────────────────────────────
  static void _paintStagger({
    required Canvas canvas,
    required double cx,
    required double cy,
    required double diagonal,
    required double cellSize,
    required ChatWallpaperConfig config,
    required Random rng,
    required double iconBaseSize,
    required PainterGlyphCache cache,
  }) {
    final double D = cellSize;
    final int countX = (diagonal / D).ceil() + 2;
    final int countY = (diagonal / D).ceil() + 2;
    final double startX = cx - (countX * D) / 2.0;
    final double startY = cy - (countY * D) / 2.0;
    final double endX = cx + (countX * D) / 2.0;
    final double endY = cy + (countY * D) / 2.0;

    if (config.staggerByRow) {
      int row = 0;
      for (double y = startY; y <= endY; y += D, row++) {
        final double rowOffset = (row % 2 == 1) ? (D * 0.5) : 0.0;
        for (double x = startX + rowOffset; x <= endX; x += D) {
          if (rng.nextDouble() <= config.density) {
            _drawSingleIcon(
              canvas: canvas,
              x: x,
              y: y,
              config: config,
              rng: rng,
              iconBaseSize: iconBaseSize,
              cache: cache,
            );
          }
        }
      }
    } else {
      int col = 0;
      for (double x = startX; x <= endX; x += D, col++) {
        final double colOffset = (col % 2 == 1) ? (D * 0.5) : 0.0;
        for (double y = startY + colOffset; y <= endY; y += D) {
          if (rng.nextDouble() <= config.density) {
            _drawSingleIcon(
              canvas: canvas,
              x: x,
              y: y,
              config: config,
              rng: rng,
              iconBaseSize: iconBaseSize,
              cache: cache,
            );
          }
        }
      }
    }
  }

  // ── Regular Cartesian Grid ────────────────────────────────────────────────
  static void _paintGrid({
    required Canvas canvas,
    required double cx,
    required double cy,
    required double diagonal,
    required double cellSize,
    required ChatWallpaperConfig config,
    required Random rng,
    required double iconBaseSize,
    required PainterGlyphCache cache,
  }) {
    final double D = cellSize;
    final int countX = (diagonal / D).ceil() + 2;
    final int countY = (diagonal / D).ceil() + 2;
    final double startX = cx - (countX * D) / 2.0;
    final double startY = cy - (countY * D) / 2.0;
    final double endX = cx + (countX * D) / 2.0;
    final double endY = cy + (countY * D) / 2.0;

    for (double y = startY; y <= endY; y += D) {
      for (double x = startX; x <= endX; x += D) {
        if (rng.nextDouble() <= config.density) {
          _drawSingleIcon(
            canvas: canvas,
            x: x,
            y: y,
            config: config,
            rng: rng,
            iconBaseSize: iconBaseSize,
            cache: cache,
          );
        }
      }
    }
  }

  // ── High-Speed Glyph Draw (Uses pre-rendered Paragraphs & Paths) ───────────
  static void _drawSingleIcon({
    required Canvas canvas,
    required double x,
    required double y,
    required ChatWallpaperConfig config,
    required Random rng,
    required double iconBaseSize,
    required PainterGlyphCache cache,
  }) {
    final double scaleJitter = 1.0 + (rng.nextDouble() * 2.0 - 1.0) * config.randomScaleJitter;
    final double scale = scaleJitter.clamp(0.25, 2.4);

    final double rotationJitterDeg = (rng.nextDouble() * 2.0 - 1.0) * config.randomRotationDeg;
    final double rotationRad = rotationJitterDeg * pi / 180.0;

    final String selectedRole = cache.activeRoles[rng.nextInt(cache.activeRoles.length)];

    canvas.save();
    canvas.translate(x, y);

    if (rotationRad.abs() > 0.001) {
      canvas.rotate(rotationRad);
    }
    if ((scale - 1.0).abs() > 0.001) {
      canvas.scale(scale, scale);
    }

    if (config.iconSource == IconSource.niosMess) {
      final Shapes shape = cache.shapesPool[rng.nextInt(cache.shapesPool.length)];
      final Path? path = cache.shapePaths[shape];
      final Paint? paint = cache.shapePaints[selectedRole];
      if (path != null && paint != null) {
        canvas.drawPath(path, paint);
      }
    } else if (config.iconSource == IconSource.lucide || config.iconSource == IconSource.tabler) {
      ui.Picture? pic;
      if (cache.poolSvgPictures != null && cache.poolSvgPictures!.isNotEmpty) {
        pic = cache.poolSvgPictures![rng.nextInt(cache.poolSvgPictures!.length)];
      } else {
        pic = cache.paletteSvgPictures?[selectedRole] ?? cache.svgPicture;
      }

      if (pic != null) {
        final double svgScale = iconBaseSize / 24.0;
        canvas.scale(svgScale, svgScale);
        canvas.translate(-12.0, -12.0);
        canvas.drawPicture(pic);
      }
    } else {
      // Material Symbols or Cupertino Icons via Pre-Laid-Out ui.Paragraph
      if (cache.activeCodepoints.isNotEmpty) {
        final int code = cache.activeCodepoints[rng.nextInt(cache.activeCodepoints.length)];
        final String key = '${code}_$selectedRole';
        final ui.Paragraph? paragraph = cache.cachedParagraphs[key];
        if (paragraph != null) {
          canvas.drawParagraph(
            paragraph,
            Offset(-paragraph.width / 2.0, -paragraph.height / 2.0),
          );
        }
      }
    }

    canvas.restore();
  }

  // ── Pre-building Glyph Cache ──────────────────────────────────────────────
  static PainterGlyphCache _buildGlyphCache({
    required ChatWallpaperConfig config,
    required ColorScheme scheme,
    required double iconBaseSize,
    required List<String> activeRoles,
    required Map<String, Color> resolvedColors,
    ui.Picture? svgPicture,
    Map<String, ui.Picture>? paletteSvgPictures,
    List<ui.Picture>? poolSvgPictures,
  }) {
    final List<Shapes> shapesPool = <Shapes>[];
    final Map<Shapes, Path> shapePaths = <Shapes, Path>{};
    final Map<String, Paint> shapePaints = <String, Paint>{};

    final List<int> activeCodepoints = <int>[];
    final Map<String, ui.Paragraph> cachedParagraphs = <String, ui.Paragraph>{};

    if (config.iconSource == IconSource.niosMess) {
      if (config.useAllIcons) {
        shapesPool.addAll(_kAllM3Shapes);
      } else if (config.m3ShapeName != null && config.m3ShapeName!.isNotEmpty) {
        shapesPool.add(_resolveM3Shape(config.m3ShapeName!));
      } else {
        shapesPool.add(Shapes.gem);
      }

      for (final Shapes shape in shapesPool) {
        final Path originalPath = M3Clipper(shape).getClip(Size(iconBaseSize, iconBaseSize));
        final Matrix4 m = Matrix4.translationValues(-iconBaseSize / 2.0, -iconBaseSize / 2.0, 0);
        shapePaths[shape] = originalPath.transform(m.storage);
      }

      for (final String role in activeRoles) {
        final Color c = resolvedColors[role] ?? scheme.primary;
        shapePaints[role] = Paint()
          ..color = c
          ..style = config.filled ? PaintingStyle.fill : PaintingStyle.stroke
          ..strokeWidth = max(1.2, iconBaseSize * 0.075);
      }
    } else if (config.iconSource == IconSource.materialSymbols) {
      if (config.themePack != 'all' && config.themePack != 'custom') {
        final List<String> packNames =
            IconSourcesCatalog.getThemePackIcons(config.themePack,
                source: config.iconSource);
        for (final String name in packNames) {
          final int? cp = MaterialSymbolsData.codepoints[name];
          if (cp != null) activeCodepoints.add(cp);
        }
      } else if (config.themePack == 'custom' && config.selectedGlyphs.isNotEmpty) {
        for (final String name in config.selectedGlyphs) {
          final int? cp = MaterialSymbolsData.codepoints[name];
          if (cp != null) activeCodepoints.add(cp);
        }
      } else if (!config.useAllIcons) {
        activeCodepoints.add(config.glyphCodepoint);
      }

      if (activeCodepoints.isEmpty) {
        if (config.useAllIcons && MaterialSymbolsData.allCodepoints.isNotEmpty) {
          final Random sampleRng = Random(config.seed);
          final int count = min(28, MaterialSymbolsData.allCodepoints.length);
          for (int i = 0; i < count; i++) {
            activeCodepoints.add(MaterialSymbolsData.allCodepoints[sampleRng.nextInt(MaterialSymbolsData.allCodepoints.length)]);
          }
        } else {
          activeCodepoints.add(config.glyphCodepoint);
        }
      }

      // 2. Pre-layout ui.Paragraph for each unique (codepoint, colorRole) combination ONCE
      final String fontFamily = _resolveFontFamily(config.symbolsStyle);
      final double fontSize = iconBaseSize;

      for (final int code in activeCodepoints) {
        for (final String role in activeRoles) {
          final Color color = resolvedColors[role] ?? scheme.primary;
          final String key = '${code}_$role';

          final ui.ParagraphBuilder pb = ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: TextAlign.center,
              fontSize: fontSize,
            ),
          );
          pb.pushStyle(
            ui.TextStyle(
              color: color,
              fontSize: fontSize,
              fontFamily: fontFamily,
              fontVariations: <ui.FontVariation>[
                ui.FontVariation('FILL', config.filled ? 1.0 : 0.0),
                ui.FontVariation('wght', config.weight.clamp(100.0, 700.0)),
                const ui.FontVariation('GRAD', 0.0),
                const ui.FontVariation('opsz', 24.0),
              ],
            ),
          );
          pb.addText(String.fromCharCode(code));
          final ui.Paragraph paragraph = pb.build();
          paragraph.layout(ui.ParagraphConstraints(width: fontSize * 1.4));
          cachedParagraphs[key] = paragraph;
        }
      }
    } else if (config.iconSource == IconSource.cupertino) {
      if (config.themePack != 'all' && config.themePack != 'custom') {
        final List<String> packNames = IconSourcesCatalog.getThemePackIcons(
          config.themePack,
          source: IconSource.cupertino,
        );
        for (final String name in packNames) {
          activeCodepoints.add(
            CupertinoIconsData.resolveCodepoint(name, filled: config.filled),
          );
        }
      } else if (config.themePack == 'custom' &&
          config.selectedGlyphs.isNotEmpty) {
        for (final String name in config.selectedGlyphs) {
          activeCodepoints.add(
            CupertinoIconsData.resolveCodepoint(name, filled: config.filled),
          );
        }
      } else if (!config.useAllIcons) {
        activeCodepoints.add(
          CupertinoIconsData.resolveCodepoint(config.glyphName,
              filled: config.filled),
        );
      }

      if (activeCodepoints.isEmpty) {
        final Random sampleRng = Random(config.seed);
        final int count = min(28, CupertinoIconsData.allNames.length);
        for (int i = 0; i < count; i++) {
          final String name = CupertinoIconsData
              .allNames[sampleRng.nextInt(CupertinoIconsData.allNames.length)];
          activeCodepoints.add(
            CupertinoIconsData.resolveCodepoint(name, filled: config.filled),
          );
        }
      }

      const String fontFamily = 'packages/cupertino_icons/CupertinoIcons';
      final double fontSize = iconBaseSize;

      for (final int code in activeCodepoints) {
        for (final String role in activeRoles) {
          final Color color = resolvedColors[role] ?? scheme.primary;
          final String key = '${code}_$role';

          final ui.ParagraphBuilder pb = ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: TextAlign.center,
              fontSize: fontSize,
            ),
          );
          pb.pushStyle(
            ui.TextStyle(
              color: color,
              fontSize: fontSize,
              fontFamily: fontFamily,
            ),
          );
          pb.addText(String.fromCharCode(code));
          final ui.Paragraph paragraph = pb.build();
          paragraph.layout(ui.ParagraphConstraints(width: fontSize * 1.4));
          cachedParagraphs[key] = paragraph;
        }
      }
    }

    return PainterGlyphCache(
      activeRoles: activeRoles,
      resolvedColors: resolvedColors,
      shapesPool: shapesPool,
      shapePaths: shapePaths,
      shapePaints: shapePaints,
      activeCodepoints: activeCodepoints,
      cachedParagraphs: cachedParagraphs,
      svgPicture: svgPicture,
      paletteSvgPictures: paletteSvgPictures,
      poolSvgPictures: poolSvgPictures,
    );
  }

  static List<String> resolveActiveRoles(ChatWallpaperConfig config) {
    if (config.colorMode == WallpaperColorMode.singleTone) {
      return <String>[config.iconColorRole];
    } else if (config.colorMode == WallpaperColorMode.tonalAccent) {
      return const <String>['primary', 'tertiary'];
    } else {
      return config.paletteRoles.isNotEmpty
          ? config.paletteRoles
          : const <String>['primary', 'secondary', 'tertiary', 'outline'];
    }
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
      case 'c9_sided_cookie':
        return Shapes.c9_sided_cookie;
      case 'm3_clover':
      case 'clover':
      case 'l4_leaf_clover':
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
      case 'm3_sunny':
      case 'sunny':
        return Shapes.sunny;
      case 'm3_very_sunny':
      case 'very_sunny':
        return Shapes.very_sunny;
      case 'm3_flower':
      case 'flower':
        return Shapes.flower;
      case 'm3_puffy':
      case 'puffy':
        return Shapes.puffy;
      default:
        return Shapes.gem;
    }
  }

  @override
  bool shouldRepaint(ChatWallpaperPainter oldDelegate) {
    return oldDelegate.config != config ||
        oldDelegate.scheme != scheme ||
        oldDelegate.svgPicture != svgPicture ||
        oldDelegate.paletteSvgPictures != paletteSvgPictures ||
        oldDelegate.poolSvgPictures != poolSvgPictures;
  }
}

class PainterGlyphCache {
  PainterGlyphCache({
    required this.activeRoles,
    required this.resolvedColors,
    required this.shapesPool,
    required this.shapePaths,
    required this.shapePaints,
    required this.activeCodepoints,
    required this.cachedParagraphs,
    this.svgPicture,
    this.paletteSvgPictures,
    this.poolSvgPictures,
  });

  final List<String> activeRoles;
  final Map<String, Color> resolvedColors;
  final List<Shapes> shapesPool;
  final Map<Shapes, Path> shapePaths;
  final Map<String, Paint> shapePaints;
  final List<int> activeCodepoints;
  final Map<String, ui.Paragraph> cachedParagraphs;
  final ui.Picture? svgPicture;
  final Map<String, ui.Picture>? paletteSvgPictures;
  final List<ui.Picture>? poolSvgPictures;
}

