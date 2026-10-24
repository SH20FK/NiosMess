import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:pulse_flutter/core/media/animated_media_controller_pool.dart';
import 'package:pulse_flutter/core/media/media_playback_visibility.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

class StickerVideoPlayer extends ConsumerStatefulWidget {
  const StickerVideoPlayer({
    required this.url,
    this.placeholder,
    this.fit = BoxFit.contain,
    super.key,
  });
  final String url;
  final Widget? placeholder;
  final BoxFit fit;

  @override
  ConsumerState<StickerVideoPlayer> createState() => StickerVideoPlayerState();
}

class StickerVideoPlayerState extends ConsumerState<StickerVideoPlayer> {
  final Object _mediaToken = Object();
  final _pool = AnimatedMediaControllerPool.instance;
  VideoPlayerController? _controller;
  ProviderSubscription<AdaptivePerformanceState>? _performanceSubscription;
  ProviderSubscription<bool>? _autoplaySubscription;
  bool _isInit = false;
  bool _failed = false;
  bool _visible = false;
  bool _starting = false;
  bool _disposing = false;
  bool _retryRequested = false;
  final GlobalKey _posterBoundary = GlobalKey();
  ui.Image? _posterImage;
  bool _posterCapturePending = false;
  ScrollPosition? _scrollPosition;
  bool _imageFallback = false;
  bool _imagePlaying = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _pool.addListener(_syncPlayback);
    _autoplaySubscription = ref.listenManual(
      uiSettingsProvider.select((s) => s.animateStickers),
      (_, _) => _syncPlayback(),
    );
    _performanceSubscription = ref.listenManual(adaptivePerformanceProvider, (
      previous,
      next,
    ) {
      if (previous?.tier != next.tier) {
        _pool.enforceBudget(next.tier);
        _syncPlayback();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _scrollPosition) {
      _scrollPosition?.isScrollingNotifier.removeListener(_onScrollingChanged);
      _scrollPosition = position;
      position?.isScrollingNotifier.addListener(_onScrollingChanged);
    }
  }

  void _onScrollingChanged() {
    final controller = _controller;
    if (_scrollPosition?.isScrollingNotifier.value == false &&
        controller != null &&
        _isInit) {
      _capturePoster(controller, _generation);
    }
  }

  void _onVisibilityChanged(bool visible) {
    _visible = visible;
    _syncPlayback();
  }

  void _syncPlayback() {
    if (!mounted || _failed) return;
    final tier = ref.read(adaptivePerformanceProvider).tier;
    if (!_visible || !_pool.canAutoplay(tier)) {
      unawaited(_pool.release(_mediaToken));
    } else if (_isInit) {
      _requestPlay();
    } else if (!_starting) {
      unawaited(_initVideo(tier));
    } else {
      _retryRequested = true;
    }
  }

  void _requestPlay() {
    final controller = _controller;
    if ((controller == null && !_imageFallback) || !_visible) return;
    if (!ref.read(uiSettingsProvider).animateStickers) {
      _pool.notifyPaused(_mediaToken);
      if (controller != null) unawaited(controller.pause());
      if (_imagePlaying) setState(() => _imagePlaying = false);
      return;
    }
    final allowed = _pool.requestPlay(
      id: _mediaToken,
      tier: ref.read(adaptivePerformanceProvider).tier,
      onPause: () {
        if (controller != null && _controller == controller) {
          unawaited(controller.pause());
        } else if (_imagePlaying && mounted && !_disposing) {
          setState(() => _imagePlaying = false);
        }
      },
      onResume: _syncPlayback,
    );
    if (allowed) {
      if (controller != null) {
        unawaited(controller.play());
      } else if (!_imagePlaying) {
        setState(() => _imagePlaying = true);
      }
    }
  }

  Future<void> _releaseController() async {
    _generation++;
    final controller = _controller;
    _controller = null;
    _isInit = false;
    _imageFallback = false;
    _imagePlaying = false;
    if (mounted && !_disposing) setState(() {});
    await controller?.dispose();
  }

  Future<void> _initVideo(PerformanceTier tier) async {
    _starting = true;
    final generation = _generation;
    try {
      final granted = await _pool.acquireInitialization(
        id: _mediaToken,
        tier: tier,
        onRelease: _releaseController,
      );
      if (!granted) return;
      if (!mounted ||
          !_visible ||
          generation != _generation ||
          !_pool.canAutoplay(ref.read(adaptivePerformanceProvider).tier)) {
        await _pool.release(_mediaToken);
        return;
      }
      final path = Uri.parse(widget.url).path.toLowerCase();
      if (path.endsWith('.gif') ||
          path.endsWith('.webp') ||
          path.endsWith('.apng')) {
        // Flutter image codecs must obey the same visibility/play budget.
        setState(() {
          _isInit = true;
          _imageFallback = true;
        });
        _requestPlay();
        return;
      }
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
      );
      _controller = controller;
      await controller.initialize();
      if (!mounted || generation != _generation || !_visible) return;
      await controller.setLooping(true);
      await controller.setVolume(0);
      if (!mounted || generation != _generation || !_visible) return;
      setState(() => _isInit = true);
      _requestPlay();
      _capturePoster(controller, generation);
    } catch (error) {
      _failed = true;
      debugPrint(
        'StickerVideoPlayer: DECODER_INIT_FAILED ${error.runtimeType}',
      );
      await _pool.release(_mediaToken);
    } finally {
      _starting = false;
      if (_retryRequested) {
        _retryRequested = false;
        _syncPlayback();
      }
    }
  }

  void _capturePoster(VideoPlayerController controller, int generation) {
    if (_posterImage != null || _posterCapturePending) return;
    _posterCapturePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted ||
            !_visible ||
            _pool.isFastScrolling ||
            (_scrollPosition?.isScrollingNotifier.value ?? false) ||
            _controller != controller ||
            generation != _generation) {
          return;
        }
        final boundary = _posterBoundary.currentContext?.findRenderObject();
        if (boundary is! RenderRepaintBoundary || boundary.debugNeedsPaint) {
          return;
        }
        final image = await boundary.toImage(pixelRatio: 1);
        if (!mounted ||
            !_visible ||
            generation != _generation ||
            _posterImage != null ||
            !_pool.retainPoster(
              id: _mediaToken,
              bytes: image.width * image.height * 4,
              onEvict: _evictPoster,
            )) {
          image.dispose();
          return;
        }
        _posterImage = image;
      } catch (_) {
        // A platform texture can disappear while the snapshot is in flight.
      } finally {
        _posterCapturePending = false;
      }
    });
  }

  void _evictPoster() {
    _posterImage?.dispose();
    _posterImage = null;
    if (mounted && !_disposing) setState(() {});
  }

  @override
  void didUpdateWidget(covariant StickerVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _generation++;
      _failed = false;
      _retryRequested = true;
      _pool.releasePoster(_mediaToken);
      _posterImage?.dispose();
      _posterImage = null;
      unawaited(_pool.release(_mediaToken).then((_) => _syncPlayback()));
    }
  }

  @override
  void dispose() {
    _disposing = true;
    _visible = false;
    _pool.removeListener(_syncPlayback);
    _performanceSubscription?.close();
    _autoplaySubscription?.close();
    _scrollPosition?.isScrollingNotifier.removeListener(_onScrollingChanged);
    _pool.releasePoster(_mediaToken);
    _posterImage?.dispose();
    _pool.notifyDisposed(_mediaToken);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MediaPlaybackVisibility(
    onChanged: _onVisibilityChanged,
    child: RepaintBoundary(
      key: _posterBoundary,
      child: _controller != null && _isInit && _controller!.value.isInitialized
          ? FittedBox(
              fit: widget.fit,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            )
          : _imagePlaying
          ? CachedNetworkImage(
              imageUrl: widget.url,
              fit: widget.fit,
              memCacheWidth: 400,
              memCacheHeight: 400,
              placeholder: (_, _) =>
                  widget.placeholder ??
                  const Icon(Icons.sticky_note_2_outlined),
              errorWidget: (_, _, _) =>
                  widget.placeholder ??
                  const Icon(Icons.sticky_note_2_outlined),
            )
          : _posterImage != null
          ? RawImage(image: _posterImage, fit: widget.fit)
          : widget.placeholder ?? const Icon(Icons.sticky_note_2_outlined),
    ),
  );
}
