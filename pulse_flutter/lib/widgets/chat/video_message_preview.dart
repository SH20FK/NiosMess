import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_io/io.dart';
import 'package:video_player/video_player.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/media/animated_media_controller_pool.dart';
import 'package:pulse_flutter/core/media/media_playback_source.dart';
import 'package:pulse_flutter/core/media/media_playback_visibility.dart';
import 'package:pulse_flutter/core/network/ws_media_fetcher.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';
import 'package:pulse_flutter/core/utils/file_type_detector.dart';
import 'package:pulse_flutter/providers/connectivity_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

/// A muted first frame, with the same viewport/decoder budget as other media.
/// No extracted frames or file keys are written into a shared thumbnail cache.
class VideoMessagePreview extends ConsumerStatefulWidget {
  const VideoMessagePreview({
    required this.url,
    this.fileKey,
    this.mimeType,
    this.duration,
    this.name,
    this.onOpen,
    this.onLongPress,
    super.key,
  });
  final String url;
  final String? fileKey, mimeType, name;
  final int? duration;
  final VoidCallback? onOpen, onLongPress;
  @override
  ConsumerState<VideoMessagePreview> createState() =>
      _VideoMessagePreviewState();
}

class _PreviewLease {
  VideoPlayerController? controller;
  MediaPlaybackSource? source;

  Future<void> close() async {
    final player = controller;
    final media = source;
    controller = null;
    source = null;
    try {
      await player?.dispose();
    } finally {
      await media?.close();
    }
  }
}

class _VideoMessagePreviewState extends ConsumerState<VideoMessagePreview> {
  _PreviewLease? _lease;
  bool _visible = false,
      _attempted = false,
      _loading = false,
      _disposing = false;
  int _generation = 0;

  void _visibility(bool visible) {
    _visible = visible;
    if (!visible) {
      _generation++;
      _attempted = false;
      final lease = _lease;
      if (lease != null) {
        unawaited(AnimatedMediaControllerPool.instance.release(lease));
      }
    } else {
      unawaited(_load());
    }
  }

  Future<void> _release(_PreviewLease lease) async {
    if (identical(_lease, lease)) {
      _lease = null;
      _loading = false;
      if (mounted && !_disposing) setState(() {});
    }
    await lease.close();
  }

  Future<void> _load() async {
    if (!mounted ||
        !_visible ||
        _attempted ||
        !ref.read(autoDownloadAllowedProvider)) {
      return;
    }
    _attempted = true;
    final generation = _generation;
    final lease = _PreviewLease();
    _lease = lease;
    final pool = AnimatedMediaControllerPool.instance;
    final tier = ref.read(adaptivePerformanceProvider).tier;
    var granted = false;
    try {
      granted = await pool.acquireInitialization(
        id: lease,
        tier: tier,
        onRelease: () => _release(lease),
      );
      if (!granted) {
        if (identical(_lease, lease)) _lease = null;
        return;
      }
      if (!mounted ||
          !_visible ||
          generation != _generation ||
          !identical(_lease, lease)) {
        await pool.release(lease);
        return;
      }
      setState(() => _loading = true);
      final source = await WsMediaFetcher.acquirePlaybackSource(
        filePath: widget.url,
        wsClient: ref.read(webSocketClientProvider),
        e2eeFileKey: widget.fileKey == null
            ? null
            : base64Decode(widget.fileKey!),
        mimeType: widget.mimeType,
      );
      if (!mounted ||
          !_visible ||
          generation != _generation ||
          !identical(_lease, lease)) {
        await source.close();
        await pool.release(lease);
        return;
      }
      lease.source = source;
      final controller = source.uri != null
          ? VideoPlayerController.networkUrl(source.uri!)
          : VideoPlayerController.file(File(source.filePath!));
      lease.controller = controller;
      await controller.initialize().timeout(const Duration(seconds: 12));
      if (!mounted ||
          !_visible ||
          generation != _generation ||
          !identical(_lease, lease)) {
        return;
      }
      await controller.setVolume(0);
      if (mounted && generation == _generation && identical(_lease, lease)) {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (granted) await pool.release(lease);
      if (mounted && generation == _generation && identical(_lease, lease)) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void didUpdateWidget(covariant VideoMessagePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.fileKey != widget.fileKey) {
      _generation++;
      _attempted = false;
      final lease = _lease;
      unawaited(() async {
        if (lease != null) {
          await AnimatedMediaControllerPool.instance.release(lease);
        }
        if (mounted && _visible) await _load();
      }());
    }
  }

  @override
  void dispose() {
    _disposing = true;
    _visible = false;
    _generation++;
    final lease = _lease;
    if (lease != null) {
      unawaited(AnimatedMediaControllerPool.instance.release(lease));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final controller = _lease?.controller;
    final ready = controller?.value.isInitialized == true;
    final duration =
        widget.duration ??
        (ready ? controller!.value.duration.inSeconds : null);
    return MediaPlaybackVisibility(
      onChanged: _visibility,
      child: Semantics(
        label: context.l10n.videoPreview,
        button: true,
        child: Tooltip(
          message: widget.name ?? context.l10n.videoPreview,
          child: Material(
            color: scheme.surfaceContainerHighest,
            child: InkWell(
              onTap: widget.onOpen,
              onLongPress: widget.onLongPress,
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (ready)
                      FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: controller!.value.size.width,
                          height: controller.value.size.height,
                          child: VideoPlayer(controller),
                        ),
                      ),
                    Center(
                      child: Material(
                        color: scheme.surfaceContainerHigh.withValues(
                          alpha: .94,
                        ),
                        shape: const CircleBorder(),
                        child: SizedBox.square(
                          dimension: 56,
                          child: _loading
                              ? const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: AppLoadingIndicator(size: 24),
                                )
                              : Icon(
                                  Icons.play_arrow_rounded,
                                  size: 32,
                                  color: scheme.onSurface,
                                ),
                        ),
                      ),
                    ),
                    if (duration != null && duration > 0)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHigh.withValues(
                              alpha: .94,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Text(
                              FileTypeDetector.formatDuration(duration),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: scheme.onSurface),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
