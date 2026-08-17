import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/core/network/ws_media_fetcher.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:universal_io/io.dart';

enum MediaType { image, video, pdf, other }

class MediaViewerScreen extends ConsumerStatefulWidget {
  const MediaViewerScreen({
    required this.url,
    this.title,
    this.mediaType = MediaType.other,
    this.filePath,
    this.mediaName,
    this.e2eeFileKey,
    super.key,
  });

  final String url;
  final String? title;
  final MediaType mediaType;
  final String? filePath;

  /// Base64 per-file AES key for E2EE media (secret chats).
  final String? e2eeFileKey;
  final String? mediaName;

  @override
  ConsumerState<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends ConsumerState<MediaViewerScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _initialized = false;

  Uint8List? _fileKey() {
    final String? b64 = widget.e2eeFileKey;
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
    _initMedia();
  }

  Future<void> _initMedia() async {
    if (widget.mediaType == MediaType.video) {
      try {
        // Download through the authenticated fetcher (also handles E2EE
        // blobs) and play from the local file.
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
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String displayTitle = (widget.title ?? '').trim().isEmpty
        ? context.l10n.mediaViewerTitle
        : widget.title!.trim();

    return Scaffold(
      backgroundColor: scheme.scrim,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        title: Text(displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: context.l10n.mediaViewerDownload,
            onPressed: () => _downloadMedia(context, ref),
          ),
        ],
      ),
      body: _buildBody(scheme),
    );
  }

  Widget _buildBody(ColorScheme scheme) {
    switch (widget.mediaType) {
      case MediaType.image:
        return _buildImageViewer(scheme);
      case MediaType.video:
        return _buildVideoPlayer(scheme);
      case MediaType.pdf:
      case MediaType.other:
        return _buildFallback(scheme);
    }
  }

  Widget _buildImageViewer(ColorScheme scheme) {
    return _FullScreenImage(
      url: widget.url,
      e2eeFileKey: _fileKey(),
      scheme: scheme,
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

  Widget _buildFallback(ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.open_in_new_rounded,
              size: 48, color: Colors.white54),
          const SizedBox(height: 16),
          Text(
            context.l10n.mediaViewerCannotPreview,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _downloadMedia(context, ref),
            icon: const Icon(Icons.download_rounded),
            label: Text(context.l10n.mediaDownloadAndOpen),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => launchUrl(Uri.parse(widget.url),
                mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_browser_rounded),
            label: Text(context.l10n.mediaViewerOpenExternal),
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadMedia(BuildContext context, WidgetRef ref) async {
    if (kIsWeb) {
      if (!context.mounted) return;
      AppToast.showInfo(context, context.l10n.mediaViewerDownloadWeb);
      return;
    }
    try {
      final fileName = widget.mediaName ?? widget.title ?? 'download';
      final dir = await getApplicationDocumentsDirectory();
      final savePath = '${dir.path}/$fileName';

      if (widget.filePath != null && widget.filePath!.isNotEmpty) {
        final bytes = await ref
            .read(chatRepositoryProvider)
            .downloadMedia(widget.filePath!);
        final file = File(savePath);
        await file.writeAsBytes(bytes);
        if (!context.mounted) return;
        AppToast.showSuccess(context, context.l10n.mediaSavedTo(savePath));
      } else {
        try {
          final bytes = await ref
              .read(chatRepositoryProvider)
              .downloadMedia(widget.url);
          final file = File(savePath);
          await file.writeAsBytes(bytes);
          if (!context.mounted) return;
          AppToast.showSuccess(context, context.l10n.mediaSavedTo(savePath));
        } catch (_) {
          if (!context.mounted) return;
          AppToast.showError(context, context.l10n.mediaViewerDownloadFailedExt);
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      AppToast.showError(context, context.l10n.mediaDownloadFailed('$e'));
    }
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
  });

  final String url;
  final ColorScheme scheme;
  final Uint8List? e2eeFileKey;

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
    _load();
  }

  @override
  void didUpdateWidget(covariant _FullScreenImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
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
                color: Colors.white54,
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.mediaViewerImageLoadFailed('$_error'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    return PhotoView(
      imageProvider: MemoryImage(_bytes!),
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 2.5,
      backgroundDecoration: BoxDecoration(color: widget.scheme.scrim),
      loadingBuilder: (context, event) => const Center(
        child: AppLoadingIndicator(size: 32),
      ),
      errorBuilder: (context, error, stackTrace) => const Center(
        child: Icon(Icons.broken_image_rounded, color: Colors.white70),
      ),
    );
  }
}
