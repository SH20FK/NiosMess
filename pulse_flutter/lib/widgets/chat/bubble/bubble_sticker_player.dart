import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:pulse_flutter/core/media/animated_media_controller_pool.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class StickerVideoPlayer extends ConsumerStatefulWidget {
  const StickerVideoPlayer({required this.url, super.key});
  final String url;

  @override
  ConsumerState<StickerVideoPlayer> createState() => StickerVideoPlayerState();
}

class StickerVideoPlayerState extends ConsumerState<StickerVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInit = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool isTickerActive = TickerMode.valuesOf(context).enabled;
    if (!isTickerActive && _controller != null && _controller!.value.isPlaying) {
      AnimatedMediaControllerPool.instance.notifyPaused(widget.url);
      _controller!.pause();
    } else if (isTickerActive && _controller != null && _isInit && !_controller!.value.isPlaying) {
      _requestPlay();
    }
  }

  void _requestPlay() {
    if (_controller == null) return;
    final PerformanceTier tier = ref.read(adaptivePerformanceProvider).tier;
    final bool allowed = AnimatedMediaControllerPool.instance.requestPlay(
      id: widget.url,
      tier: tier,
      onPause: () {
        if (mounted && _controller != null && _controller!.value.isPlaying) {
          _controller!.pause();
        }
      },
      onResume: () {
        if (mounted && _controller != null && !_controller!.value.isPlaying && TickerMode.valuesOf(context).enabled) {
          _controller!.play();
        }
      },
    );
    if (allowed && mounted && TickerMode.valuesOf(context).enabled) {
      _controller!.play();
    }
  }

  Future<void> _initVideo() async {
    try {
      final Uri uri = Uri.parse(widget.url);
      _controller = VideoPlayerController.networkUrl(uri);
      await _controller!.initialize();
      await _controller!.setLooping(true);
      await _controller!.setVolume(0.0);
      if (mounted && TickerMode.valuesOf(context).enabled) {
        _requestPlay();
      }
      if (mounted) setState(() => _isInit = true);
    } catch (_) {
      // Graceful fallback to static thumbnail
    }
  }

  @override
  void dispose() {
    AnimatedMediaControllerPool.instance.notifyDisposed(widget.url);
    _controller?.pause();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller != null && _isInit && _controller!.value.isInitialized) {
      return FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: _controller!.value.size.width,
          height: _controller!.value.size.height,
          child: VideoPlayer(_controller!),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: widget.url,
      fit: BoxFit.contain,
      memCacheWidth: 400,
      memCacheHeight: 400,
      placeholder: (_, _) => const AppLoadingIndicator(size: 24),
      errorWidget: (_, _, _) => const Icon(Icons.sticky_note_2_outlined),
    );
  }
}
