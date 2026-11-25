import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

/// ВРЕМЕННЫЙ dev-экран.
///
/// Живое сравнение текущего просмотрщика (`photo_view` + `PageView`,
/// как в `media_viewer_screen.dart`) и `extended_image` 10.x.
///
/// Открыть: `flutter run --dart-define=IMAGE_DEMO=true`
/// либо перейти на `/dev/image-viewer`.
///
/// Строки намеренно не прогнаны через l10n: экран одноразовый и удаляется
/// после решения по пакету.
class ExtendedImageDemoScreen extends StatefulWidget {
  const ExtendedImageDemoScreen({super.key});

  static const String routePath = '/dev/image-viewer';

  @override
  State<ExtendedImageDemoScreen> createState() =>
      _ExtendedImageDemoScreenState();
}

class _ExtendedImageDemoScreenState extends State<ExtendedImageDemoScreen> {
  List<_DemoImage>? _images;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    try {
      final images = await _generateDemoImages();
      if (!mounted) return;
      setState(() => _images = images);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  void _open(int index, {required bool extended}) {
    Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (context, animation, secondaryAnimation) => _DemoViewer(
          images: _images!,
          initialIndex: index,
          extended: extended,
        ),
        transitionsBuilder: (context, animation, secondary, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final images = _images;

    return Scaffold(
      appBar: AppBar(title: const Text('Image viewer demo')),
      body: _error != null
          ? Center(child: Text('Не удалось сгенерировать картинки: $_error'))
          : images == null
          ? const Center(child: AppLoadingIndicator(size: 32))
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _Intro(scheme: scheme)),
                SliverPadding(
                  padding: const EdgeInsets.all(12),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 260,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                        ),
                    itemCount: images.length,
                    itemBuilder: (context, index) {
                      final image = images[index];
                      return _DemoTile(
                        image: image,
                        onTap: () => _open(index, extended: true),
                      );
                    },
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Тапните картинку. В просмотрщике переключатель сверху меняет '
            'движок на ходу.',
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 8),
          Text(
            'pinch · двойной тап · свайп страниц · потянуть вниз чтобы закрыть',
            style: TextStyle(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoTile extends StatelessWidget {
  const _DemoTile({required this.image, required this.onTap});

  final _DemoImage image;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(
              image.bytes,
              fit: BoxFit.cover,
              cacheWidth: 420,
              gaplessPlayback: true,
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${image.width}×${image.height}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoViewer extends StatefulWidget {
  const _DemoViewer({
    required this.images,
    required this.initialIndex,
    required this.extended,
  });

  final List<_DemoImage> images;
  final int initialIndex;
  final bool extended;

  @override
  State<_DemoViewer> createState() => _DemoViewerState();
}

class _DemoViewerState extends State<_DemoViewer> {
  final GlobalKey<ExtendedImageSlidePageState> _slideKey =
      GlobalKey<ExtendedImageSlidePageState>();
  late final PageController _legacyController = PageController(
    initialPage: widget.initialIndex,
  );
  late final ExtendedPageController _extendedController =
      ExtendedPageController(
        initialPage: widget.initialIndex,
        pageSpacing: 24,
        shouldIgnorePointerWhenScrolling: false,
      );
  late int _index = widget.initialIndex;
  late bool _extended = widget.extended;
  bool _chrome = true;

  @override
  Widget build(BuildContext context) {
    final image = widget.images[_index];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: _extended ? _buildExtended(context) : _buildLegacy(),
          ),
          if (_chrome)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(bottom: false, child: _buildTopBar(context)),
            ),
          if (_chrome)
            Positioned(
              left: 16,
              right: 16,
              bottom: 0,
              child: SafeArea(top: false, child: _buildBottomBar(context, image)),
            ),
        ],
      ),
    );
  }

  Widget _buildExtended(BuildContext context) {
    return ExtendedImageSlidePage(
      key: _slideKey,
      slideAxis: SlideAxis.both,
      slideType: SlideType.wholePage,
      child: ExtendedImageGesturePageView.builder(
        controller: _extendedController,
        itemCount: widget.images.length,
        onPageChanged: (int page) => setState(() => _index = page),
        itemBuilder: (BuildContext context, int index) {
          final image = widget.images[index];
          // У ExtendedImage 10.x нет onTap — тап ловим снаружи.
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleChrome,
            child: ExtendedImage.memory(
              image.bytes,
              fit: BoxFit.contain,
              mode: ExtendedImageMode.gesture,
              filterQuality: FilterQuality.medium,
              enableSlideOutPage: true,
              // Обрезать нечего: у полноэкранной картинки нет скруглений.
              clipBehavior: Clip.none,
              // Ровно то, чего сейчас не хватает: ограничиваем декод шириной
              // экрана в физических пикселях вместо полного разрешения.
              cacheWidth: image.decodeWidth(context),
              initGestureConfigHandler: (ExtendedImageState state) =>
                  GestureConfig(
                    // Обязательно для ExtendedImageGesturePageView.
                    inPageView: true,
                    initialScale: 1.0,
                    maxScale: 5.0,
                    animationMaxScale: 6.0,
                    initialAlignment: InitialAlignment.center,
                  ),
              onDoubleTap: _handleDoubleTap,
            ),
          );
        },
      ),
    );
  }

  Widget _buildLegacy() {
    // Ровно текущая схема из media_viewer_screen.dart: PageView + PhotoView
    // и MemoryImage без cacheWidth.
    return PageView.builder(
      controller: _legacyController,
      physics: const BouncingScrollPhysics(),
      itemCount: widget.images.length,
      onPageChanged: (int page) => setState(() => _index = page),
      itemBuilder: (BuildContext context, int index) {
        return PhotoView(
          imageProvider: MemoryImage(widget.images[index].bytes),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 2.5,
          backgroundDecoration: const BoxDecoration(color: Colors.transparent),
          onTapUp: (context, details, controllerValue) => _toggleChrome(),
        );
      },
    );
  }

  void _toggleChrome() {
    setState(() => _chrome = !_chrome);
  }

  void _handleDoubleTap(ExtendedImageGestureState state) {
    final double current = state.gestureDetails?.totalScale ?? 1.0;
    state.handleDoubleTap(
      scale: current < 1.9 ? 2.5 : 1.0,
      doubleTapPosition: state.pointerDownPosition,
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close_rounded),
            color: Colors.white,
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '${_index + 1} / ${widget.images.length}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const Spacer(),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: true,
                label: Text('extended_image'),
              ),
              ButtonSegment<bool>(value: false, label: Text('photo_view')),
            ],
            selected: {_extended},
            showSelectedIcon: false,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                return states.contains(WidgetState.selected)
                    ? Colors.white.withValues(alpha: 0.22)
                    : Colors.black.withValues(alpha: 0.4);
              }),
              foregroundColor: const WidgetStatePropertyAll(Colors.white),
              side: WidgetStatePropertyAll(
                BorderSide(color: Colors.white.withValues(alpha: 0.25)),
              ),
            ),
            onSelectionChanged: (selection) {
              setState(() => _extended = selection.first);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, _DemoImage image) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${image.width}×${image.height} · ${image.megapixels} МП',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _extended
                ? 'extended_image: декод ${image.decodeWidth(context)} px по ширине'
                : 'photo_view: декод в полном разрешении (~${image.fullDecodeMb} МБ RGBA)',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

/// Одна сгенерированная картинка. Размеры храним сами, чтобы показать
/// реальную стоимость декода и посчитать `cacheWidth`.
class _DemoImage {
  const _DemoImage({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;

  String get megapixels => ((width * height) / 1000000).toStringAsFixed(1);

  int get fullDecodeMb => ((width * height * 4) / (1024 * 1024)).round();

  int decodeWidth(BuildContext context) {
    final double raw =
        MediaQuery.sizeOf(context).width *
        MediaQuery.devicePixelRatioOf(context);
    final int target = raw.round();
    return target < width ? target : width;
  }
}

class _DemoSpec {
  const _DemoSpec({
    required this.width,
    required this.height,
    required this.from,
    required this.to,
    required this.title,
  });

  final int width;
  final int height;
  final Color from;
  final Color to;
  final String title;
}

const List<_DemoSpec> _demoSpecs = <_DemoSpec>[
  _DemoSpec(
    width: 1400,
    height: 1800,
    from: Color(0xFF1F6FEB),
    to: Color(0xFF0B2545),
    title: '1',
  ),
  _DemoSpec(
    width: 2400,
    height: 1400,
    from: Color(0xFFE8590C),
    to: Color(0xFF3B0A02),
    title: '2',
  ),
  _DemoSpec(
    width: 1600,
    height: 1600,
    from: Color(0xFF2F9E44),
    to: Color(0xFF08240F),
    title: '3',
  ),
  _DemoSpec(
    width: 1080,
    height: 1920,
    from: Color(0xFF7048E8),
    to: Color(0xFF1A0B3B),
    title: '4',
  ),
  // Нарочно огромная: 4000×3000 = 12 МП = ~46 МБ RGBA при декоде.
  _DemoSpec(
    width: 4000,
    height: 3000,
    from: Color(0xFFE03131),
    to: Color(0xFF2B0505),
    title: '5',
  ),
  _DemoSpec(
    width: 2600,
    height: 1000,
    from: Color(0xFF0CA678),
    to: Color(0xFF04231A),
    title: '6',
  ),
];

Future<List<_DemoImage>> _generateDemoImages() async {
  final out = <_DemoImage>[];
  for (final spec in _demoSpecs) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final double w = spec.width.toDouble();
    final double h = spec.height.toDouble();
    final Rect rect = Rect.fromLTWH(0, 0, w, h);

    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(rect.topLeft, rect.bottomRight, <Color>[
          spec.from,
          spec.to,
        ]),
    );

    // Мелкая сетка и кольца — чтобы зум было видно, а не «размытый градиент».
    final Paint grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    for (double x = 0; x <= w; x += w / 48) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), grid);
    }
    for (double y = 0; y <= h; y += h / 48) {
      canvas.drawLine(Offset(0, y), Offset(w, y), grid);
    }

    final Paint ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.008
      ..color = Colors.white.withValues(alpha: 0.16);
    for (double r = 0.12; r < 0.62; r += 0.08) {
      canvas.drawCircle(Offset(w / 2, h / 2), w * r, ring);
    }

    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: spec.title,
        style: TextStyle(
          fontSize: w * 0.3,
          fontWeight: FontWeight.w800,
          letterSpacing: -w * 0.01,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset((w - painter.width) / 2, (h - painter.height) / 2),
    );

    final ui.Image image = await recorder.endRecording().toImage(
      spec.width,
      spec.height,
    );
    final ByteData? data = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    image.dispose();
    if (data == null) {
      throw StateError('PNG encode failed for ${spec.width}x${spec.height}');
    }
    out.add(
      _DemoImage(
        bytes: data.buffer.asUint8List(),
        width: spec.width,
        height: spec.height,
      ),
    );
  }
  return out;
}
