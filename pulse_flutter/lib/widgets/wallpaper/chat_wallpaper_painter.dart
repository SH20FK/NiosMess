import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import 'package:pulse_flutter/core/identity/nios_weave.dart';
import 'package:pulse_flutter/models/chat_wallpaper_config.dart';
import 'package:pulse_flutter/widgets/wallpaper/cupertino_icons_data.dart';
import 'package:pulse_flutter/widgets/wallpaper/icon_sources_catalog.dart';
import 'package:pulse_flutter/widgets/wallpaper/curated_wallpaper_catalog.dart';
import 'package:pulse_flutter/widgets/wallpaper/material_symbols_data.dart';
import 'package:pulse_flutter/widgets/wallpaper/wallpaper_color_resolver.dart';

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

    // 2. Setup positioning bounds
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
    required double iconBaseSize,
    required PainterGlyphCache cache,
  }) {
    final double D = cellSize;
    final double H = D * 0.8660254037844386; // sqrt(3)/2 = ~0.866

    final int halfCountX = (diagonal / (2.0 * D)).ceil() + 1;
    final int halfCountY = (diagonal / (2.0 * H)).ceil() + 1;

    for (int r = -halfCountY; r <= halfCountY; r++) {
      final double rowOffset = r.isOdd ? (D * 0.5) : 0.0;
      final double y = cy + r * H;
      for (int c = -halfCountX; c <= halfCountX; c++) {
        final double x = cx + c * D + rowOffset;
        final int h = NiosWeave.posHash(config.seed, c, r);
        if ((h % 10000) / 10000.0 <= config.density) {
          _drawSingleIcon(
            canvas: canvas,
            x: x,
            y: y,
            col: c,
            row: r,
            config: config,
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

      final int h = NiosWeave.posHash(config.seed, n, 0);
      if ((h % 10000) / 10000.0 <= config.density) {
        _drawSingleIcon(
          canvas: canvas,
          x: posX,
          y: posY,
          col: n,
          row: 0,
          config: config,
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
    required double iconBaseSize,
    required PainterGlyphCache cache,
  }) {
    final double D = cellSize;
    final int halfCount = (diagonal / (2.0 * D)).ceil() + 1;
    final double maxJitter = D * 0.32;

    for (int r = -halfCount; r <= halfCount; r++) {
      final double yBase = cy + r * D;
      for (int c = -halfCount; c <= halfCount; c++) {
        final double xBase = cx + c * D;
        final int h = NiosWeave.posHash(config.seed, c, r);
        if ((h % 10000) / 10000.0 <= config.density) {
          final int hx = NiosWeave.posHash(config.seed ^ 0x4B0D3A2C, c, r);
          final int hy = NiosWeave.posHash(config.seed ^ 0x7F21A3C4, c, r);
          final double jx = (((hx % 10000) / 10000.0) * 2.0 - 1.0) * maxJitter;
          final double jy = (((hy % 10000) / 10000.0) * 2.0 - 1.0) * maxJitter;
          _drawSingleIcon(
            canvas: canvas,
            x: xBase + jx,
            y: yBase + jy,
            col: c,
            row: r,
            config: config,
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
    required double iconBaseSize,
    required PainterGlyphCache cache,
  }) {
    final double D = cellSize;
    final int halfCount = (diagonal / (2.0 * D)).ceil() + 1;

    if (config.staggerByRow) {
      for (int r = -halfCount; r <= halfCount; r++) {
        final double rowOffset = r.isOdd ? (D * 0.5) : 0.0;
        final double y = cy + r * D;
        for (int c = -halfCount; c <= halfCount; c++) {
          final double x = cx + c * D + rowOffset;
          final int h = NiosWeave.posHash(config.seed, c, r);
          if ((h % 10000) / 10000.0 <= config.density) {
            _drawSingleIcon(
              canvas: canvas,
              x: x,
              y: y,
              col: c,
              row: r,
              config: config,
              iconBaseSize: iconBaseSize,
              cache: cache,
            );
          }
        }
      }
    } else {
      for (int c = -halfCount; c <= halfCount; c++) {
        final double colOffset = c.isOdd ? (D * 0.5) : 0.0;
        final double x = cx + c * D;
        for (int r = -halfCount; r <= halfCount; r++) {
          final double y = cy + r * D + colOffset;
          final int h = NiosWeave.posHash(config.seed, c, r);
          if ((h % 10000) / 10000.0 <= config.density) {
            _drawSingleIcon(
              canvas: canvas,
              x: x,
              y: y,
              col: c,
              row: r,
              config: config,
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
    required double iconBaseSize,
    required PainterGlyphCache cache,
  }) {
    final double D = cellSize;
    final int halfCount = (diagonal / (2.0 * D)).ceil() + 1;

    for (int r = -halfCount; r <= halfCount; r++) {
      final double y = cy + r * D;
      for (int c = -halfCount; c <= halfCount; c++) {
        final double x = cx + c * D;
        final int h = NiosWeave.posHash(config.seed, c, r);
        if ((h % 10000) / 10000.0 <= config.density) {
          _drawSingleIcon(
            canvas: canvas,
            x: x,
            y: y,
            col: c,
            row: r,
            config: config,
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
    required int col,
    required int row,
    required ChatWallpaperConfig config,
    required double iconBaseSize,
    required PainterGlyphCache cache,
  }) {
    final int hScale = NiosWeave.posHash(config.seed ^ 0x243F6A88, col, row);
    final double scaleJitter = 1.0 + (((hScale % 10000) / 10000.0) * 2.0 - 1.0) * config.randomScaleJitter;
    final double scale = scaleJitter.clamp(0.25, 2.4);

    final int hRot = NiosWeave.posHash(config.seed ^ 0x85A308D3, col, row);
    final double rotationJitterDeg = (((hRot % 10000) / 10000.0) * 2.0 - 1.0) * config.randomRotationDeg;
    final double rotationRad = rotationJitterDeg * pi / 180.0;

    final int hRole = NiosWeave.posHash(config.seed ^ 0x13198A2E, col, row);
    final String selectedRole = cache.activeRoles[hRole % cache.activeRoles.length];

    canvas.save();
    canvas.translate(x, y);

    if (rotationRad.abs() > 0.001) {
      canvas.rotate(rotationRad);
    }
    if ((scale - 1.0).abs() > 0.001) {
      canvas.scale(scale, scale);
    }

    final int hGlyph = NiosWeave.posHash(config.seed ^ 0x03707344, col, row);

    if (config.iconSource == IconSource.niosMess) {
      final Shapes shape = cache.shapesPool[hGlyph % cache.shapesPool.length];
      final Path? path = cache.shapePaths[shape];
      final Paint? paint = cache.shapePaints[selectedRole];
      if (path != null && paint != null) {
        canvas.drawPath(path, paint);
      }
    } else if (config.iconSource == IconSource.lucide || config.iconSource == IconSource.tabler) {
      ui.Picture? pic;
      if (cache.poolSvgPictures != null && cache.poolSvgPictures!.isNotEmpty) {
        pic = cache.poolSvgPictures![hGlyph % cache.poolSvgPictures!.length];
      } else {
        pic = cache.paletteSvgPictures?[selectedRole] ?? cache.svgPicture;
      }

      if (pic != null) {
        final double svgScale = iconBaseSize / 24.0;
        canvas.scale(svgScale, svgScale);
        canvas.translate(-12.0, -12.0);

        final Color roleColor = cache.resolvedColors[selectedRole] ??
            (cache.resolvedColors.isNotEmpty
                ? cache.resolvedColors.values.first
                : const Color(0xFFFFFFFF));
        final Paint tintPaint = Paint()
          ..colorFilter = ColorFilter.mode(roleColor, BlendMode.srcIn);
        canvas.saveLayer(const Rect.fromLTWH(0, 0, 24.0, 24.0), tintPaint);
        canvas.drawPicture(pic);
        canvas.restore();
      }
    } else {
      // Material Symbols or Cupertino Icons via Pre-Laid-Out ui.Paragraph
      if (cache.activeCodepoints.isNotEmpty) {
        final int code = cache.activeCodepoints[hGlyph % cache.activeCodepoints.length];
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
      if (config.selectedGlyphs.isNotEmpty) {
        for (final String name in config.selectedGlyphs) {
          shapesPool.add(CuratedWallpaperCatalog.resolveShape(name));
        }
      } else if (config.useAllIcons || config.themePack == 'all') {
        shapesPool.addAll(CuratedWallpaperCatalog.allM3Shapes);
      } else if (config.themePack.startsWith('m3_')) {
        shapesPool.addAll(CuratedWallpaperCatalog.getShapesForPack(config.themePack));
      } else if (config.m3ShapeName != null && config.m3ShapeName!.isNotEmpty) {
        shapesPool.add(CuratedWallpaperCatalog.resolveShape(config.m3ShapeName!));
      } else {
        shapesPool.addAll(CuratedWallpaperCatalog.organicShapes);
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
          ..strokeWidth = max(1.5, iconBaseSize * 0.08);
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

