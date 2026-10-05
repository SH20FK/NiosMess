import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:universal_io/io.dart';
import 'package:video_player/video_player.dart';
import 'package:pulse_flutter/core/media/animated_media_controller_pool.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/core/network/ws_media_fetcher.dart';
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
  State<CircleVideoInlinePlayer> createState() => CircleVideoInlinePlayerState();
}

class CircleVideoInlinePlayerState extends State<CircleVideoInlinePlayer> {
  VideoPlayerController? _videoController;
  bool _initialized = false;
  bool _playing = false;
  bool _showThumbnail = true;
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool isTickerActive = TickerMode.valuesOf(context).enabled;
    if (!isTickerActive && _videoController != null && _playing) {
      AnimatedMediaControllerPool.instance.notifyPaused(widget.videoUrl);
      _videoController!.pause();
    }
  }

  void _playWithPool() {
    if (_videoController == null) return;
    final bool allowed = AnimatedMediaControllerPool.instance.requestPlay(
      id: widget.videoUrl,
      tier: PerformanceTier.tierA,
      isUserInitiated: true,
      onPause: () {
        if (mounted && _videoController != null && _playing) {
          _videoController!.pause();
        }
      },
      onResume: () {
        if (mounted && _videoController != null && !_playing && TickerMode.valuesOf(context).enabled) {
          _videoController!.play();
        }
      },
    );
    if (allowed) {
      _videoController!.play();
    }
  }

  Future<void> _initVideo() async {
    if (_isLoading) return;
    _isLoading = true;
    try {
      Uint8List? fileKey;
      if (widget.e2eeFileKey != null && widget.e2eeFileKey!.isNotEmpty) {
        fileKey = base64Decode(widget.e2eeFileKey!);
      }
      final localPath = await WsMediaFetcher.fetchToLocalFile(
        filePath: widget.videoUrl,
        wsClient: widget.wsClient,
        e2eeFileKey: fileKey,
      );
      if (!mounted) return;
      _videoController = VideoPlayerController.file(
        File(localPath),
      );
      await _videoController!.initialize();
      await _videoController!.setLooping(true);
      _videoController!.addListener(_onVideoStateChange);
      if (mounted) {
        setState(() {
          _initialized = true;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _initialized = false;
          _isLoading = false;
        });
      }
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
      AnimatedMediaControllerPool.instance.notifyPaused(widget.videoUrl);
      _videoController!.pause();
    } else {
      _playWithPool();
    }
  }

  @override
  void dispose() {
    AnimatedMediaControllerPool.instance.notifyDisposed(widget.videoUrl);
    _videoController?.removeListener(_onVideoStateChange);
    _videoController?.pause();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double circleSize = 180;

    return GestureDetector(
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
                  _showThumbnail ? Icons.play_arrow_rounded : Icons.pause_rounded,
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
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formatDuration(widget.durationSeconds),
                    style: TextStyle(color: widget.scheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            // Footer overlay
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
      child: const Center(
        child: Icon(Icons.videocam_rounded, size: 32),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

