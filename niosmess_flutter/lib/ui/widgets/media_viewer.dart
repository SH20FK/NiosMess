import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

/// Full-screen media viewer for photos, videos, and audio
/// Supports both network URLs and local file paths
class MediaViewer extends StatefulWidget {
  final String source; // URL or file path
  final MediaViewerType type;
  final String? title;
  final String? subtitle;

  const MediaViewer({
    super.key,
    required this.source,
    required this.type,
    this.title,
    this.subtitle,
  });

  /// Opens the media viewer as a full-screen route
  static void open(
    BuildContext context, {
    required String source,
    required MediaViewerType type,
    String? title,
    String? subtitle,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => MediaViewer(
          source: source,
          type: type,
          title: title,
          subtitle: subtitle,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

enum MediaViewerType { image, video, audio }

class _MediaViewerState extends State<MediaViewer> {
  // Video
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;
  bool _videoError = false;

  // Audio
  final AudioPlayer _audioPlayer = AudioPlayer();
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;
  bool _audioPlaying = false;
  bool _audioError = false;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<Duration?>? _durationSub;

  // UI
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    if (widget.type == MediaViewerType.video) {
      _initVideo();
    } else if (widget.type == MediaViewerType.audio) {
      _initAudio();
    }
  }

  Future<void> _initVideo() async {
    try {
      final isFile = widget.source.startsWith('/') || widget.source.startsWith('file://');
      _videoController = isFile
          ? VideoPlayerController.file(File(widget.source))
          : VideoPlayerController.networkUrl(Uri.parse(widget.source));
      await _videoController!.initialize();
      _videoController!.addListener(() {
        if (mounted) setState(() {});
      });
      if (mounted) {
        setState(() => _videoInitialized = true);
        _videoController!.play();
      }
    } catch (_) {
      if (mounted) setState(() => _videoError = true);
    }
  }

  Future<void> _initAudio() async {
    try {
      final isFile = widget.source.startsWith('/') || widget.source.startsWith('file://');
      if (isFile) {
        await _audioPlayer.setFilePath(widget.source);
      } else {
        await _audioPlayer.setUrl(widget.source);
      }
      _audioDuration = _audioPlayer.duration ?? Duration.zero;
      _positionSub = _audioPlayer.positionStream.listen((pos) {
        if (mounted) setState(() => _audioPosition = pos);
      });
      _playingSub = _audioPlayer.playingStream.listen((playing) {
        if (mounted) setState(() => _audioPlaying = playing);
      });
      _durationSub = _audioPlayer.durationStream.listen((dur) {
        if (dur != null && mounted) setState(() => _audioDuration = dur);
      });
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _audioError = true);
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _playingSub?.cancel();
    _durationSub?.cancel();
    _videoController?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Content
            _buildContent(),

            // Top bar
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              top: _showControls ? 0 : -100,
              left: 0,
              right: 0,
              child: _buildTopBar(),
            ),

            // Bottom controls (video/audio)
            if (widget.type != MediaViewerType.image)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                bottom: _showControls ? 0 : -120,
                left: 0,
                right: 0,
                child: widget.type == MediaViewerType.video
                    ? _buildVideoControls()
                    : _buildAudioControls(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xCC000000),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.title != null)
                      Text(
                        widget.title!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (widget.subtitle != null)
                      Text(
                        widget.subtitle!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (widget.type) {
      case MediaViewerType.image:
        return _buildImageViewer();
      case MediaViewerType.video:
        return _buildVideoViewer();
      case MediaViewerType.audio:
        return _buildAudioViewer();
    }
  }

  // ── Image ──

  Widget _buildImageViewer() {
    final isFile = widget.source.startsWith('/') || widget.source.startsWith('file://');
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: isFile
            ? Image.file(
                File(widget.source),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _errorWidget('Не удалось загрузить изображение'),
              )
            : CachedNetworkImage(
                imageUrl: widget.source,
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (_, __, ___) => _errorWidget('Не удалось загрузить изображение'),
              ),
      ),
    );
  }

  // ── Video ──

  Widget _buildVideoViewer() {
    if (_videoError) {
      return Center(child: _errorWidget('Не удалось воспроизвести видео'));
    }
    if (!_videoInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return Center(
      child: AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: VideoPlayer(_videoController!),
      ),
    );
  }

  Widget _buildVideoControls() {
    if (!_videoInitialized || _videoController == null) return const SizedBox.shrink();
    final position = _videoController!.value.position;
    final duration = _videoController!.value.duration;
    final playing = _videoController!.value.isPlaying;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xCC000000), Colors.transparent],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                  thumbColor: Colors.white,
                  overlayColor: Colors.white.withValues(alpha: 0.1),
                ),
                child: Slider(
                  value: duration.inMilliseconds > 0
                      ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
                      : 0.0,
                  onChanged: (value) {
                    _videoController!.seekTo(
                      Duration(milliseconds: (value * duration.inMilliseconds).round()),
                    );
                  },
                ),
              ),
              Row(
                children: [
                  Text(
                    _formatDuration(position),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      if (playing) {
                        _videoController!.pause();
                      } else {
                        _videoController!.play();
                      }
                    },
                    icon: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDuration(duration),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Audio ──

  Widget _buildAudioViewer() {
    if (_audioError) {
      return Center(child: _errorWidget('Не удалось воспроизвести аудио'));
    }
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated circle
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  scheme.primary.withValues(alpha: 0.3),
                  scheme.tertiary.withValues(alpha: 0.2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Icon(
              _audioPlaying ? Icons.graphic_eq_rounded : Icons.headphones_rounded,
              color: Colors.white,
              size: 64,
            ),
          ),
          const SizedBox(height: 24),
          if (widget.title != null)
            Text(
              widget.title!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  Widget _buildAudioControls() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xCC000000), Colors.transparent],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                  thumbColor: Colors.white,
                  overlayColor: Colors.white.withValues(alpha: 0.1),
                ),
                child: Slider(
                  value: _audioDuration.inMilliseconds > 0
                      ? (_audioPosition.inMilliseconds / _audioDuration.inMilliseconds).clamp(0.0, 1.0)
                      : 0.0,
                  onChanged: (value) {
                    _audioPlayer.seek(
                      Duration(milliseconds: (value * _audioDuration.inMilliseconds).round()),
                    );
                  },
                ),
              ),
              Row(
                children: [
                  Text(
                    _formatDuration(_audioPosition),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                  ),
                  const Spacer(),
                  // Rewind
                  IconButton(
                    onPressed: () {
                      final pos = _audioPosition - const Duration(seconds: 10);
                      _audioPlayer.seek(pos.isNegative ? Duration.zero : pos);
                    },
                    icon: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 8),
                  // Play/Pause
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () {
                        if (_audioPlaying) {
                          _audioPlayer.pause();
                        } else {
                          _audioPlayer.play();
                        }
                      },
                      icon: Icon(
                        _audioPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Forward
                  IconButton(
                    onPressed: () {
                      final pos = _audioPosition + const Duration(seconds: 10);
                      if (pos < _audioDuration) {
                        _audioPlayer.seek(pos);
                      }
                    },
                    icon: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 28),
                  ),
                  const Spacer(),
                  Text(
                    _formatDuration(_audioDuration),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ──

  Widget _errorWidget(String message) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline, color: Colors.white.withValues(alpha: 0.5), size: 48),
        const SizedBox(height: 12),
        Text(
          message,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$m:$s';
    }
    return '$m:$s';
  }
}
