import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_error_formatter.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/core/network/ws_media_fetcher.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/motion/nios_dismissible.dart';
import 'package:pulse_flutter/widgets/common/touch_container.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:universal_io/io.dart';

enum MediaType { image, video, pdf, other }

class MediaViewerItem {
  const MediaViewerItem({
    required this.url,
    required this.mediaType,
    this.title,
    this.e2eeFileKey,
    this.filePath,
    this.mediaName,
  });

  final String url;
  final MediaType mediaType;
  final String? title;
  final String? e2eeFileKey;
  final String? filePath;
  final String? mediaName;
}

class MediaViewerScreen extends ConsumerStatefulWidget {
  const MediaViewerScreen({
    required this.url,
    this.title,
    this.mediaType = MediaType.other,
    this.filePath,
    this.mediaName,
    this.e2eeFileKey,
    this.playlist,
    this.initialIndex = 0,
    super.key,
  });

  final String url;
  final String? title;
  final MediaType mediaType;
  final String? filePath;

  /// Base64 per-file AES key for E2EE media (secret chats).
  final String? e2eeFileKey;
  final String? mediaName;

  /// Optional playlist for swipeable multi-media gallery
  final List<MediaViewerItem>? playlist;
  final int initialIndex;

  @override
  ConsumerState<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends ConsumerState<MediaViewerScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _initialized = false;

  late final bool _hasPlaylist =
      widget.playlist != null && widget.playlist!.isNotEmpty;
  late final List<MediaViewerItem> _playlistItems = _hasPlaylist
      ? widget.playlist!
      : <MediaViewerItem>[
          MediaViewerItem(
            url: widget.url,
            mediaType: widget.mediaType,
            title: widget.title,
            e2eeFileKey: widget.e2eeFileKey,
            filePath: widget.filePath,
            mediaName: widget.mediaName,
          ),
        ];
  late int _currentIndex = _hasPlaylist
      ? widget.initialIndex.clamp(0, _playlistItems.length - 1)
      : 0;
  late final PageController _pageController =
      PageController(initialPage: _currentIndex);

  double _dragProgress = 0.0;
  bool _showChrome = true;

  void _toggleChrome() {
    setState(() {
      _showChrome = !_showChrome;
    });
  }

  void _dismiss() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/main/chats');
    }
  }

  String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  Future<void> _shareCurrentMedia(BuildContext context, WidgetRef ref) async {
    final MediaViewerItem current = _playlistItems[_currentIndex];
    if (kIsWeb) {
      if (!context.mounted) return;
      AppToast.showInfo(context, context.l10n.mediaViewerDownloadWeb);
      return;
    }
    try {
      final String fileName = _sanitizeFileName(current.mediaName ?? current.title ?? 'shared_media');
      final List<int> bytes;
      if (current.filePath != null && current.filePath!.isNotEmpty) {
        bytes = await ref.read(chatRepositoryProvider).downloadMedia(current.filePath!);
      } else {
        bytes = await ref.read(chatRepositoryProvider).downloadMedia(current.url);
      }
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(tempFile.path)],
          text: current.title,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        AppToast.showError(context, e);
      }
    }
  }

  Uint8List? _fileKey([String? rawKey]) {
    final String? b64 = rawKey ?? widget.e2eeFileKey;
    if (b64 == null || b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    if (!_hasPlaylist) {
      _initMedia();
    }
  }

  Future<void> _initMedia() async {
    if (widget.mediaType == MediaType.video) {
      try {
        final String localPath = await WsMediaFetcher.fetchToLocalFile(
          filePath: widget.url,
          wsClient: ref.read(webSocketClientProvider),
          e2eeFileKey: _fileKey(),
        );
        _videoController = VideoPlayerController.file(File(localPath));
        await _videoController!.initialize();
        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          autoPlay: true,
          looping: false,
          placeholder: const AppLoadingIndicator(size: 32),
          allowedScreenSleep: false,
          deviceOrientationsAfterFullScreen: [
            DeviceOrientation.portraitUp,
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ],
        );
      } catch (_) {}
    }
    if (mounted) setState(() => _initialized = true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MediaViewerItem currentItem = _playlistItems[_currentIndex];
    final String displayTitle = _hasPlaylist
        ? '${_currentIndex + 1} из ${_playlistItems.length}'
        : ((currentItem.title ?? '').trim().isEmpty
            ? context.l10n.mediaViewerTitle
            : currentItem.title!.trim());

    final bool canRoutePop = ModalRoute.of(context)?.canPop ?? false;
    return PopScope(
      canPop: canRoutePop,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _dismiss();
      },
      child: NiosDismissible(
        onDismissed: _dismiss,
        onProgress: (double progress) {
          if ((_dragProgress - progress).abs() > 0.01) {
            setState(() => _dragProgress = progress);
          }
        },
        builder: (BuildContext ctx, Widget transformedBody, double progress) {
          final double scrimAlpha = (1.0 - progress.abs()).clamp(0.0, 1.0);
          final bool isInteractingWithDrag = progress.abs() > 0.001;

          return Scaffold(
            backgroundColor: scheme.scrim.withValues(alpha: 0.95 * scrimAlpha),
            extendBodyBehindAppBar: true,
            body: Stack(
              children: <Widget>[
                // ── Interactive Swipe-Down Body ──────────────────────────
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _toggleChrome,
                    child: transformedBody,
                  ),
                ),

            // ── Top Animated App Bar ─────────────────────────────────
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: M3SpringCurves.spatial,
              top: (_showChrome && !isInteractingWithDrag) ? 0 : -110,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      scheme.surface.withValues(alpha: 0.85),
                      scheme.surface.withValues(alpha: 0.0),
                    ],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    foregroundColor: scheme.onSurface,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: _dismiss,
                    ),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(displayTitle,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (_hasPlaylist && (currentItem.mediaName ?? '').isNotEmpty)
                          Text(
                            currentItem.mediaName!,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                    actions: <Widget>[
                      IconButton(
                        icon: const Icon(Icons.download_rounded),
                        tooltip: context.l10n.mediaViewerDownload,
                        onPressed: () => _downloadCurrentMedia(context, ref),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Bottom Animated Action Pill ──────────────────────────
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: M3SpringCurves.spatial,
              bottom: (_showChrome && !isInteractingWithDrag)
                  ? (MediaQuery.paddingOf(context).bottom + 20)
                  : -90,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh.withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.25),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TouchContainer(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _shareCurrentMedia(context, ref),
                        padding: const EdgeInsets.all(8),
                        child: Icon(Icons.share_rounded, size: 22, color: scheme.onSurface),
                      ),
                      const SizedBox(width: 16),
                      TouchContainer(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _downloadCurrentMedia(context, ref),
                        padding: const EdgeInsets.all(8),
                        child: Icon(Icons.file_download_outlined, size: 22, color: scheme.onSurface),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
    child: _buildBody(scheme),
  ),
);
  }

  Widget _buildBody(ColorScheme scheme) {
    if (_hasPlaylist) {
      return PageView.builder(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        itemCount: _playlistItems.length,
        onPageChanged: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (BuildContext context, int index) {
          final MediaViewerItem item = _playlistItems[index];
          final Uint8List? key = _fileKey(item.e2eeFileKey);

          if (item.mediaType == MediaType.image) {
            return _FullScreenImage(
              key: ValueKey('page_${item.url}'),
              url: item.url,
              e2eeFileKey: key,
              scheme: scheme,
              onTap: _toggleChrome,
            );
          } else if (item.mediaType == MediaType.video) {
            return _InlineVideoPlayer(
              key: ValueKey('video_${item.url}'),
              url: item.url,
              e2eeFileKey: key,
              isActive: _currentIndex == index,
            );
          } else {
            return _buildFallback(scheme, item);
          }
        },
      );
    }

    switch (widget.mediaType) {
      case MediaType.image:
        return _buildImageViewer(scheme);
      case MediaType.video:
        return _buildVideoPlayer(scheme);
      case MediaType.pdf:
      case MediaType.other:
        return _buildFallback(scheme, _playlistItems.first);
    }
  }

  Widget _buildImageViewer(ColorScheme scheme) {
    return _FullScreenImage(
      url: widget.url,
      e2eeFileKey: _fileKey(),
      scheme: scheme,
      onTap: _toggleChrome,
    );
  }

  Widget _buildVideoPlayer(ColorScheme scheme) {
    if (!_initialized || _chewieController == null) {
      return const Center(child: AppLoadingIndicator(size: 32));
    }

    return Center(
      child: Chewie(controller: _chewieController!),
    );
  }

  Widget _buildFallback(ColorScheme scheme, MediaViewerItem item) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.open_in_new_rounded,
              size: 48, color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
          const SizedBox(height: 16),
          Text(
            context.l10n.mediaViewerCannotPreview,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _downloadCurrentMedia(context, ref),
            icon: const Icon(Icons.download_rounded),
            label: Text(context.l10n.mediaDownloadAndOpen),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => launchUrl(Uri.parse(item.url),
                mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_browser_rounded),
            label: Text(context.l10n.mediaViewerOpenExternal),
            style: TextButton.styleFrom(foregroundColor: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadCurrentMedia(BuildContext context, WidgetRef ref) async {
    final MediaViewerItem current = _playlistItems[_currentIndex];
    if (kIsWeb) {
      if (!context.mounted) return;
      AppToast.showInfo(context, context.l10n.mediaViewerDownloadWeb);
      return;
    }
    try {
      final String fileName = _sanitizeFileName(current.mediaName ?? current.title ?? 'download');
      final List<int> bytes;
      if (current.filePath != null && current.filePath!.isNotEmpty) {
        bytes = await ref
            .read(chatRepositoryProvider)
            .downloadMedia(current.filePath!);
      } else {
        bytes = await ref
            .read(chatRepositoryProvider)
            .downloadMedia(current.url);
      }

      if (Platform.isAndroid || Platform.isIOS) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/$fileName');
        await tempFile.writeAsBytes(bytes);
        final params = SaveFileDialogParams(sourceFilePath: tempFile.path);
        final filePath = await FlutterFileDialog.saveFile(params: params);
        if (filePath != null && context.mounted) {
          AppToast.showSuccess(context, context.l10n.mediaSavedTo(fileName));
        }
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);
        if (context.mounted) {
          AppToast.showSuccess(context, context.l10n.mediaSavedTo(file.path));
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      AppToast.showError(context, e);
    }
  }
}

class _InlineVideoPlayer extends ConsumerStatefulWidget {
  const _InlineVideoPlayer({
    required this.url,
    this.e2eeFileKey,
    this.isActive = false,
    super.key,
  });

  final String url;
  final Uint8List? e2eeFileKey;
  final bool isActive;

  @override
  ConsumerState<_InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends ConsumerState<_InlineVideoPlayer> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant _InlineVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      if (!widget.isActive) {
        _videoController?.pause();
      } else {
        _videoController?.play();
      }
    }
  }

  Future<void> _init() async {
    try {
      final String localPath = await WsMediaFetcher.fetchToLocalFile(
        filePath: widget.url,
        wsClient: ref.read(webSocketClientProvider),
        e2eeFileKey: widget.e2eeFileKey,
      );
      _videoController = VideoPlayerController.file(File(localPath));
      await _videoController!.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: widget.isActive,
        looping: false,
        placeholder: const AppLoadingIndicator(size: 32),
        allowedScreenSleep: false,
      );
    } catch (_) {}
    if (mounted) setState(() => _initialized = true);
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized || _chewieController == null) {
      return const Center(child: AppLoadingIndicator(size: 32));
    }
    return Center(child: Chewie(controller: _chewieController!));
  }
}

/// Fetches fullscreen media through the authenticated `/api/files/download`
/// endpoint (with optional E2EE decryption) instead of hitting the raw
/// `/api/media/...` URL, which is not served publicly.
class _FullScreenImage extends ConsumerStatefulWidget {
  const _FullScreenImage({
    required this.url,
    required this.scheme,
    this.e2eeFileKey,
    this.onTap,
    super.key,
  });

  final String url;
  final ColorScheme scheme;
  final Uint8List? e2eeFileKey;
  final VoidCallback? onTap;

  @override
  ConsumerState<_FullScreenImage> createState() => _FullScreenImageState();
}

class _FullScreenImageState extends ConsumerState<_FullScreenImage> {
  Uint8List? _bytes;
  Object? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final Uint8List? cached = WsMediaFetcher.getMemoryCachedBytes(
      filePath: widget.url,
      e2eeFileKey: widget.e2eeFileKey,
    );
    if (cached != null) {
      _bytes = cached;
      _isLoading = false;
    } else {
      _load();
    }
  }

  @override
  void didUpdateWidget(covariant _FullScreenImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.e2eeFileKey != widget.e2eeFileKey) {
      final Uint8List? cached = WsMediaFetcher.getMemoryCachedBytes(
        filePath: widget.url,
        e2eeFileKey: widget.e2eeFileKey,
      );
      if (cached != null) {
        setState(() {
          _bytes = cached;
          _isLoading = false;
          _error = null;
        });
      } else {
        _load();
      }
    }
  }

  Future<void> _load() async {
    setState(() {
      _bytes = null;
      _isLoading = true;
      _error = null;
    });
    try {
      final Uint8List bytes = await WsMediaFetcher.fetchAndDecryptMedia(
        filePath: widget.url,
        wsClient: ref.read(webSocketClientProvider),
        e2eeFileKey: widget.e2eeFileKey,
      );
      if (mounted) {
        setState(() {
          _bytes = bytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: AppLoadingIndicator(size: 32));
    }

    if (_error != null || _bytes == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.broken_image_rounded,
                size: 48,
                color: widget.scheme.onSurfaceVariant.withValues(alpha: 0.54),
              ),
              const SizedBox(height: 16),
              Text(
                AppErrorFormatter.format(_error).toString(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: widget.scheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Hero(
      tag: 'media_${widget.url}',
      child: PhotoView(
        imageProvider: MemoryImage(_bytes!),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 2.5,
        backgroundDecoration: const BoxDecoration(color: Colors.transparent),
        onTapUp: (context, details, controllerValue) => widget.onTap?.call(),
        loadingBuilder: (context, event) => const Center(
          child: AppLoadingIndicator(size: 32),
        ),
        errorBuilder: (context, error, stackTrace) => Center(
          child: Icon(
            Icons.broken_image_rounded,
            color: widget.scheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}
