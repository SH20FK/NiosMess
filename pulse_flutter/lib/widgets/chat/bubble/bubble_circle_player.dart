import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:universal_io/io.dart';
import 'package:video_player/video_player.dart';
import 'package:pulse_flutter/core/media/animated_media_controller_pool.dart';
import 'package:pulse_flutter/core/media/media_playback_visibility.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/core/network/ws_media_fetcher.dart';
import 'package:pulse_flutter/core/media/media_playback_source.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';
import 'package:pulse_flutter/widgets/chat/bubble/bubble_footer.dart';

class CircleVideoInlinePlayer extends StatefulWidget {
  const CircleVideoInlinePlayer({
    required this.videoUrl,
    required this.durationSeconds,
    required this.isMine,
    required this.isE2ee,
    required this.isEdited,
    required this.isDeleted,
    required this.isRead,
    this.isSending = false,
    this.isFailed = false,
    required this.formattedTime,
    required this.scheme,
    required this.textTheme,
    required this.chatId,
    required this.wsClient,
    this.e2eeFileKey,
    this.expiresAt,
    this.onLongPress,
    super.key,
  });

  final String videoUrl;
  final int durationSeconds;
  final bool isMine;
  final bool isE2ee;
  final bool isEdited;
  final bool isDeleted;
  final bool isRead;
  final bool isSending;
  final bool isFailed;
  final String formattedTime;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final int chatId;
  final WebSocketClient wsClient;
  final String? e2eeFileKey;
  final DateTime? expiresAt;
  final VoidCallback? onLongPress;

  @override
  State<CircleVideoInlinePlayer> createState() =>
      CircleVideoInlinePlayerState();
}

class CircleVideoInlinePlayerState extends State<CircleVideoInlinePlayer> {
  final Object _mediaToken = Object();
  bool _visible = false;
  int _generation = 0;
  bool _disposing = false;
  VideoPlayerController? _videoController;
  MediaPlaybackSource? _playbackSource;
  bool _initialized = false;
  bool _playing = false;
  bool _showThumbnail = true;
  bool _isLoading = false;

  void _onVisibilityChanged(bool visible) {
    _visible = visible;
    if (!visible) {
      unawaited(AnimatedMediaControllerPool.instance.release(_mediaToken));
    }
  }

  Future<void> _releaseController() async {
    _generation++;
    final controller = _videoController;
    final source = _playbackSource;
    _playbackSource = null;
    _videoController = null;
    controller?.removeListener(_onVideoStateChange);
    if (mounted && !_disposing) {
      setState(() {
        _initialized = false;
        _playing = false;
        _showThumbnail = true;
      });
    }
    await controller?.dispose();
    await source?.close();
  }

  void _playWithPool() {
    if (_videoController == null || !_visible) return;
    final bool allowed = AnimatedMediaControllerPool.instance.requestPlay(
      id: _mediaToken,
      tier: PerformanceTier.tierA,
      isUserInitiated: true,
      onPause: () {
        if (mounted && _videoController != null && _playing) {
          _videoController!.pause();
        }
      },
      onResume: () {
        if (mounted && _visible && _videoController != null && !_playing) {
          _videoController!.play();
        }
      },
    );
    if (allowed) {
      _videoController!.play();
    }
  }

  Future<void> _initVideo() async {
    if (_isLoading || !_visible) return;
    _isLoading = true;
    final generation = _generation;
    try {
      final granted = await AnimatedMediaControllerPool.instance
          .acquireInitialization(
            id: _mediaToken,
            tier: PerformanceTier.tierA,
            isUserInitiated: true,
            onRelease: _releaseController,
          );
      if (!granted || !mounted || !_visible || generation != _generation) {
        if (granted) {
          await AnimatedMediaControllerPool.instance.release(_mediaToken);
        }
        return;
      }
      Uint8List? fileKey;
      if (widget.e2eeFileKey != null && widget.e2eeFileKey!.isNotEmpty) {
        fileKey = base64Decode(widget.e2eeFileKey!);
      }
      final source = await WsMediaFetcher.acquirePlaybackSource(
        filePath: widget.videoUrl,
        wsClient: widget.wsClient,
        e2eeFileKey: fileKey,
      );
      if (!mounted || !_visible || generation != _generation) {
        await source.close();
        return;
      }
      _playbackSource = source;
      _videoController = source.uri != null
          ? VideoPlayerController.networkUrl(source.uri!)
          : VideoPlayerController.file(File(source.filePath!));
      await _videoController!.initialize();
      await _videoController!.setLooping(true);
      _videoController!.addListener(_onVideoStateChange);
      if (mounted && generation == _generation) {
        setState(() {
          _initialized = true;
          _isLoading = false;
        });
      }
    } catch (_) {
      await AnimatedMediaControllerPool.instance.release(_mediaToken);
      if (mounted) {
        setState(() {
          _initialized = false;
          _isLoading = false;
        });
      }
    } finally {
      _isLoading = false;
    }
  }

  void _onVideoStateChange() {
    if (!mounted) return;
    final bool wasPlaying = _playing;
    final bool nowPlaying = _videoController?.value.isPlaying ?? false;
    if (wasPlaying != nowPlaying) setState(() => _playing = nowPlaying);
  }

  Future<void> _togglePlay() async {
    if (_videoController == null && !_isLoading) {
      await _initVideo();
      if (!mounted || _videoController == null) return;
      setState(() => _showThumbnail = false);
      _playWithPool();
      return;
    }
    if (!_initialized || _videoController == null) return;
    if (_showThumbnail) {
      setState(() => _showThumbnail = false);
      _playWithPool();
    } else if (_playing) {
      AnimatedMediaControllerPool.instance.notifyPaused(_mediaToken);
      _videoController!.pause();
    } else {
      _playWithPool();
    }
  }

  @override
  void didUpdateWidget(covariant CircleVideoInlinePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl ||
        oldWidget.e2eeFileKey != widget.e2eeFileKey) {
      unawaited(AnimatedMediaControllerPool.instance.release(_mediaToken));
    }
  }

  @override
  void dispose() {
    _disposing = true;
    _visible = false;
    AnimatedMediaControllerPool.instance.notifyDisposed(_mediaToken);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double circleSize = 180;

    return MediaPlaybackVisibility(
      onChanged: _onVisibilityChanged,
      child: GestureDetector(
        onTap: _togglePlay,
        onLongPress: widget.onLongPress,
        child: SizedBox(
          width: circleSize,
          height: circleSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Thumbnail or video
              if (_showThumbnail || !_initialized)
                _circleThumbnail(circleSize)
              else
                ClipOval(
                  child: SizedBox(
                    width: circleSize,
                    height: circleSize,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _videoController!.value.size.width > 0
                            ? _videoController!.value.size.width
                            : circleSize,
                        height: _videoController!.value.size.height > 0
                            ? _videoController!.value.size.height
                            : circleSize,
                        child: VideoPlayer(_videoController!),
                      ),
                    ),
                  ),
                ),
              // Play/pause overlay
              if (_showThumbnail || !_playing)
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _showThumbnail
                        ? widget.scheme.surface.withValues(alpha: 0.3)
                        : widget.scheme.surface.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _showThumbnail
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    color: widget.scheme.onSurface,
                    size: 28,
                  ),
                ),
              // Duration badge
              if (_showThumbnail && widget.durationSeconds > 0)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: widget.scheme.surfaceContainerHighest.withValues(
                        alpha: 0.6,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formatDuration(widget.durationSeconds),
                      style: TextStyle(
                        color: widget.scheme.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              // Footer overlay
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: widget.scheme.surface.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: MessageBubbleFooter(
                    isMine: widget.isMine,
                    isE2ee: widget.isE2ee,
                    isEdited: widget.isEdited,
                    isDeleted: widget.isDeleted,
                    isRead: widget.isRead,
                    isSending: widget.isSending,
                    isFailed: widget.isFailed,
                    formattedTime: widget.formattedTime,
                    scheme: widget.scheme,
                    textTheme: widget.textTheme,
                    expiresAt: widget.expiresAt,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circleThumbnail(double circleSize) {
    return Container(
      width: circleSize,
      height: circleSize,
      decoration: BoxDecoration(
        color: widget.isMine
            ? widget.scheme.onPrimary.withValues(alpha: 0.12)
            : widget.scheme.surfaceContainerHigh,
        shape: BoxShape.circle,
      ),
      child: const Center(child: Icon(Icons.videocam_rounded, size: 32)),
    );
  }

  String _formatDuration(int seconds) {
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
